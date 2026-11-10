import { resolveTxt } from 'node:dns/promises';

/**
 * The single-machine rule, enforced. The ledger is a SQLite file on this
 * machine's volume, so a second machine would keep a second, empty ledger and
 * a paid package could be spent again from it. While any other machine of the
 * app is running, this one neither burns nor sells: both machines refuse, and
 * the owner has to remove the extra one.
 *
 * A lookup that fails says nothing about other machines, so the last answer
 * stands.
 */
export class MachineGuard {
  private others: string[] = [];
  private timer: NodeJS.Timeout | null = null;
  private lookupFailing = false;

  constructor(
    /** The IDs of the app's running machines. */
    private readonly lookup: () => Promise<string[]>,
    private readonly self: string,
    private readonly intervalMs = 60_000
  ) {}

  /** True while no other machine of the app is running. */
  get alone(): boolean {
    return this.others.length === 0;
  }

  async check(): Promise<void> {
    let ids: string[];
    try {
      ids = await this.lookup();
      this.lookupFailing = false;
    } catch (e: any) {
      if (!this.lookupFailing) console.error(`[machines] Could not list the app's machines (${e.message}); keeping the last answer.`);
      this.lookupFailing = true;
      return;
    }
    const others = ids.filter((id) => id !== this.self);
    if (others.length > 0 && this.alone) {
      console.error(
        `[machines] ${others.length} other machine(s) running (${others.join(', ')}): rites and checkout are off until this is the only one.`
      );
    } else if (others.length === 0 && !this.alone) {
      console.log('[machines] This is the only machine again: rites and checkout are back on.');
    }
    this.others = others;
  }

  start(): void {
    if (this.timer) return;
    this.timer = setInterval(() => void this.check(), this.intervalMs);
    this.timer.unref();
  }

  stop(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }
}

/** Machine IDs from a `vms.<app>.internal` TXT answer: `"<id> <region>,<id> <region>"`. */
export function parseFlyMachines(records: string[][]): string[] {
  return records
    .map((chunks) => chunks.join(''))
    .join(',')
    .split(',')
    .map((entry) => entry.trim().split(/\s+/)[0])
    .filter(Boolean);
}

/**
 * The guard for a Fly machine, or null anywhere else (Fly sets FLY_APP_NAME
 * and FLY_MACHINE_ID in every machine). Fly's private DNS lists the app's
 * started machines.
 */
export function machineGuardFromEnv(env: NodeJS.ProcessEnv = process.env): MachineGuard | null {
  const app = env.FLY_APP_NAME;
  const self = env.FLY_MACHINE_ID;
  if (!app || !self) return null;
  return new MachineGuard(async () => parseFlyMachines(await resolveTxt(`vms.${app}.internal`)), self);
}
