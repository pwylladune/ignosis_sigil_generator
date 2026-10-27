/**
 * Shared by the treasury tools, which the owner runs on their own machine
 * with the cold key (ADR 2026-10-27-ignosis-treasury-cold-owner-hot-delegate).
 * The server never runs them and never holds the cold key.
 */
import * as fs from 'fs';
import * as path from 'path';
import { Connection, Keypair } from '@solana/web3.js';

export type Cluster = 'mainnet-beta' | 'devnet' | 'local';

const GENESIS: Record<string, Cluster> = {
  '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d': 'mainnet-beta',
  EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG: 'devnet',
};

/**
 * The cluster [connection] reaches, by its genesis hash. Mainnet is refused
 * unless the command line says `--mainnet`, so real Joules are never touched
 * by accident; an unknown cluster is refused unless it is local.
 */
export async function checkedCluster(connection: Connection, rpcUrl: string): Promise<Cluster> {
  const cluster = GENESIS[await connection.getGenesisHash()] ?? (/localhost|127\.0\.0\.1/.test(rpcUrl) ? 'local' : null);
  if (!cluster) throw new Error(`Refusing an RPC that is neither mainnet-beta, devnet nor local: ${rpcUrl}`);
  if (cluster === 'mainnet-beta' && !process.argv.includes('--mainnet')) {
    throw new Error('This RPC is mainnet-beta. Run again with --mainnet to act on real Joules.');
  }
  return cluster;
}

/** A keypair file (a JSON byte array, as `solana-keygen` writes it). Never created here. */
export function readKeypair(file: string): Keypair {
  const resolved = path.resolve(file);
  if (!fs.existsSync(resolved)) throw new Error(`No keypair at ${resolved}`);
  return Keypair.fromSecretKey(Uint8Array.from(JSON.parse(fs.readFileSync(resolved, 'utf8'))));
}
