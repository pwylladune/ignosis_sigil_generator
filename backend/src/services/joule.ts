import { PublicKey, TransactionInstruction } from '@solana/web3.js';
import { TOKEN_2022_PROGRAM_ID, getNonTransferable, type Mint } from '@solana/spl-token';

/** SPL Memo program (v2). */
export const MEMO_PROGRAM_ID = new PublicKey('MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr');

export const JOULE_PROGRAM_ID = TOKEN_2022_PROGRAM_ID;
export const JOULE_DECIMALS = 0;

/** Memo prefix; the version changes if the commitment scheme ever does. */
export const RITE_MEMO_PREFIX = 'IGNOSIS:v1:';

const COMMITMENT = /^[0-9a-f]{64}$/;

/**
 * True for a rite commitment: 64 lowercase hex characters, the SHA-256 of
 * "IGNOSIS:v1" ‖ salt ‖ UTF-8(intent), computed on the device. The server
 * never sees the intent or the salt.
 */
export function isCommitment(value: string): boolean {
  return COMMITMENT.test(value);
}

export function riteMemo(commitment: string): string {
  if (!isCommitment(commitment)) throw new Error('Commitment must be 64 lowercase hex characters');
  return RITE_MEMO_PREFIX + commitment;
}

/** The commitment in a rite memo, or null if [memo] is not one. */
export function commitmentFromMemo(memo: string): string | null {
  if (!memo.startsWith(RITE_MEMO_PREFIX)) return null;
  const c = memo.slice(RITE_MEMO_PREFIX.length);
  return isCommitment(c) ? c : null;
}

/** A memo instruction signed by [signer], so the record's author is on-chain too. */
export function createMemoInstruction(memo: string, signer: PublicKey): TransactionInstruction {
  return new TransactionInstruction({
    programId: MEMO_PROGRAM_ID,
    keys: [{ pubkey: signer, isSigner: true, isWritable: false }],
    data: Buffer.from(memo, 'utf8'),
  });
}

/**
 * Why [mint] must not be burnt from, or null if it is a proper Joule mint:
 * non-transferable, no further minting, no freeze, whole joules.
 */
export function jouleMintProblem(mint: Mint): string | null {
  if (!getNonTransferable(mint)) return 'mint is transferable';
  if (mint.mintAuthority !== null) return 'mint authority is not revoked';
  if (mint.freezeAuthority !== null) return 'mint has a freeze authority';
  if (mint.decimals !== JOULE_DECIMALS) return `mint has ${mint.decimals} decimals, expected ${JOULE_DECIMALS}`;
  return null;
}

const BASE58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

/** Base58 (Bitcoin alphabet), as Solana writes signatures. */
export function base58(bytes: Uint8Array): string {
  const digits: number[] = [];
  for (const byte of bytes) {
    let carry = byte;
    for (let i = 0; i < digits.length; i++) {
      carry += digits[i] << 8;
      digits[i] = carry % 58;
      carry = (carry / 58) | 0;
    }
    while (carry > 0) {
      digits.push(carry % 58);
      carry = (carry / 58) | 0;
    }
  }
  let out = '';
  for (const byte of bytes) {
    if (byte !== 0) break;
    out += '1';
  }
  for (let i = digits.length - 1; i >= 0; i--) out += BASE58[digits[i]];
  return out;
}
