import { Connection, ParsedInstruction, PartiallyDecodedInstruction, PublicKey } from '@solana/web3.js';
import { JOULE_PROGRAM_ID, MEMO_PROGRAM_ID, commitmentFromMemo } from './joule.js';

export type RiteCheck =
  | { valid: true; joules: number; commitment: string; slot: number; blockTime: number | null }
  | { valid: false; reason: string };

/**
 * Checks on-chain that [signature] is a rite: a confirmed transaction that
 * burns Joules of [mint] on the [treasury]'s authority and carries an
 * IGNOSIS memo. It reads only the public chain, so the app (or anyone) can
 * run the same check without trusting this server.
 */
export async function verifyRite(
  connection: Connection,
  signature: string,
  mint: PublicKey,
  treasury: PublicKey
): Promise<RiteCheck> {
  const tx = await connection.getParsedTransaction(signature, {
    commitment: 'confirmed',
    maxSupportedTransactionVersion: 0,
  });
  if (!tx) return { valid: false, reason: 'Transaction not found' };
  if (tx.meta?.err) return { valid: false, reason: 'Transaction failed' };

  let joules = 0;
  let commitment: string | null = null;
  for (const ix of tx.transaction.message.instructions as (ParsedInstruction | PartiallyDecodedInstruction)[]) {
    if (!('parsed' in ix)) continue;
    if (ix.programId.equals(JOULE_PROGRAM_ID) && (ix.parsed?.type === 'burnChecked' || ix.parsed?.type === 'burn')) {
      const info = ix.parsed.info;
      if (info.mint !== mint.toBase58() || info.authority !== treasury.toBase58()) continue;
      joules += Number(info.tokenAmount?.amount ?? info.amount);
    } else if (ix.programId.equals(MEMO_PROGRAM_ID) && typeof ix.parsed === 'string') {
      commitment = commitmentFromMemo(ix.parsed) ?? commitment;
    }
  }
  if (joules === 0) return { valid: false, reason: 'No Joule burn from the treasury' };
  if (!commitment) return { valid: false, reason: 'No IGNOSIS memo' };
  return { valid: true, joules, commitment, slot: tx.slot, blockTime: tx.blockTime ?? null };
}

/** Explorer link for a transaction on [cluster]. */
export function explorerUrl(signature: string, cluster: string): string {
  const base = `https://explorer.solana.com/tx/${signature}`;
  return cluster === 'mainnet-beta' ? base : `${base}?cluster=${cluster === 'localnet' ? 'custom' : cluster}`;
}
