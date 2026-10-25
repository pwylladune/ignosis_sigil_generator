import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  sendAndConfirmTransaction,
} from '@solana/web3.js';
import {
  getAssociatedTokenAddressSync,
  createAssociatedTokenAccountInstruction,
  createTransferInstruction,
  getAccount,
  TokenAccountNotFoundError,
  TokenInvalidAccountOwnerError,
} from '@solana/spl-token';
import { config } from '../config.js';

export interface DispenseResult {
  success: boolean;
  txSignature: string;
  tokensDispatched: number;
  destinationAddress: string;
  cluster: string;
  isSimulated: boolean;
  message: string;
}

export class SolanaTreasuryService {
  private connection: Connection;
  private treasuryKeypair: Keypair | null = null;
  private mintPubkey: PublicKey | null = null;

  constructor() {
    this.connection = new Connection(config.solanaRpcUrl, 'confirmed');
    if (config.ignosisMintAddress) {
      try {
        this.mintPubkey = new PublicKey(config.ignosisMintAddress);
      } catch {
        console.error('[Treasury] IGNOSIS_MINT_ADDRESS is not a valid public key: treasury disabled.');
      }
    }
    this.initTreasuryKeypair();
  }

  /**
   * Loads the treasury key from TREASURY_PRIVATE_KEY (JSON byte array only).
   * Never substitutes a generated keypair: a missing or unparseable key leaves
   * the treasury disabled, and every dispense fails.
   */
  private initTreasuryKeypair() {
    if (!config.treasuryPrivateKey) {
      console.warn('[Treasury] No TREASURY_PRIVATE_KEY: treasury disabled.');
      return;
    }
    try {
      if (!config.treasuryPrivateKey.trim().startsWith('[')) {
        throw new Error('expected a JSON byte array');
      }
      const secret = Uint8Array.from(JSON.parse(config.treasuryPrivateKey));
      this.treasuryKeypair = Keypair.fromSecretKey(secret);
      console.log(`[Treasury] Initialized with public key: ${this.treasuryKeypair.publicKey.toBase58()}`);
    } catch (err: any) {
      console.error(`[Treasury] Invalid TREASURY_PRIVATE_KEY (${err.message}): treasury disabled.`);
      this.treasuryKeypair = null;
    }
  }

  public getTreasuryPublicKey(): string {
    return this.treasuryKeypair ? this.treasuryKeypair.publicKey.toBase58() : 'Uninitialized';
  }

  /**
   * Dispenses 279 $IGNOSIS tokens to the user's Solana wallet upon verified $1.99 IAP
   */
  public async dispenseTokens(
    destinationWallet: string,
    amount: number = config.starterPackTokenAmount
  ): Promise<DispenseResult> {
    let destPubkey: PublicKey;
    try {
      destPubkey = new PublicKey(destinationWallet);
    } catch {
      throw new Error(`Invalid destination Solana address: ${destinationWallet}`);
    }

    if (!this.treasuryKeypair) {
      throw new Error('Treasury keypair is uninitialized');
    }
    if (!this.mintPubkey) {
      throw new Error('IGNOSIS_MINT_ADDRESS is not configured');
    }
    const mint = this.mintPubkey;

    try {
      // Check if we are on a real active cluster with funded treasury
      const treasuryAta = getAssociatedTokenAddressSync(mint, this.treasuryKeypair.publicKey);
      const destinationAta = getAssociatedTokenAddressSync(mint, destPubkey);

      const transaction = new Transaction();

      // Check if destination ATA exists
      let needsAtaCreation = false;
      try {
        await getAccount(this.connection, destinationAta);
      } catch (e) {
        if (e instanceof TokenAccountNotFoundError || e instanceof TokenInvalidAccountOwnerError) {
          needsAtaCreation = true;
        } else {
          // If network / RPC error or unminted test token, flag for simulated fallback
          throw e;
        }
      }

      if (needsAtaCreation) {
        transaction.add(
          createAssociatedTokenAccountInstruction(
            this.treasuryKeypair.publicKey, // payer
            destinationAta,                 // ata to create
            destPubkey,                     // owner
            mint                            // mint
          )
        );
      }

      // Convert amount to atomic units (decimals = 9)
      const atomicUnits = BigInt(amount) * BigInt(10 ** config.ignosisDecimals);

      transaction.add(
        createTransferInstruction(
          treasuryAta,
          destinationAta,
          this.treasuryKeypair.publicKey,
          atomicUnits
        )
      );

      const signature = await sendAndConfirmTransaction(this.connection, transaction, [this.treasuryKeypair]);

      return {
        success: true,
        txSignature: signature,
        tokensDispatched: amount,
        destinationAddress: destinationWallet,
        cluster: config.solanaCluster,
        isSimulated: false,
        message: `Successfully transferred ${amount} $IGNOSIS on-chain.`,
      };
    } catch (err: any) {
      // Report the failure. Never fabricate a signature or claim success.
      console.error(`[Treasury] On-chain transfer failed: ${err.message}`);
      return {
        success: false,
        txSignature: '',
        tokensDispatched: 0,
        destinationAddress: destinationWallet,
        cluster: config.solanaCluster,
        isSimulated: false,
        message: 'Transfer failed.',
      };
    }
  }
}
