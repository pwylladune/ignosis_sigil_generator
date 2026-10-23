use anchor_lang::prelude::*;
use anchor_spl::token::{self, Burn, Mint, Token, TokenAccount};

declare_id!("Ignos1s111111111111111111111111111111111111");

#[program]
pub mod ignosis_incinerator {
    use super::*;

    /// Consecrates and permanently incinerates $IGNOSIS tokens as energetic sacrifice
    pub fn consecrate_burn(
        ctx: Context<ConsecrateBurn>,
        amount: u64,
        intent_hash: [u8; 32],
    ) -> Result<()> {
        require!(amount > 0, IgnosisError::ZeroBurnAmount);

        // Execute SPL token burn from user account
        let cpi_accounts = Burn {
            mint: ctx.accounts.mint.to_account_info(),
            from: ctx.accounts.user_token_account.to_account_info(),
            authority: ctx.accounts.authority.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

        token::burn(cpi_ctx, amount)?;

        // Update the Global Pyre state tracker
        let global_pyre = &mut ctx.accounts.global_pyre;
        global_pyre.total_burned = global_pyre.total_burned.checked_add(amount).unwrap();
        global_pyre.total_burn_events = global_pyre.total_burn_events.checked_add(1).unwrap();
        global_pyre.last_burn_timestamp = Clock::get()?.unix_timestamp;

        emit!(SigilConsecratedEvent {
            practitioner: ctx.accounts.authority.key(),
            amount_burned: amount,
            intent_hash,
            total_burned_cumulative: global_pyre.total_burned,
            timestamp: Clock::get()?.unix_timestamp,
        });

        Ok(())
    }
}

#[derive(Accounts)]
pub struct ConsecrateBurn<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        mut,
        constraint = mint.key() == global_pyre.mint @ IgnosisError::InvalidMint
    )]
    pub mint: Account<'info, Mint>,

    #[account(
        mut,
        constraint = user_token_account.owner == authority.key() @ IgnosisError::UnauthorizedTokenAccount
    )]
    pub user_token_account: Account<'info, TokenAccount>,

    #[account(
        mut,
        seeds = [b"global_pyre"],
        bump
    )]
    pub global_pyre: Account<'info, GlobalPyre>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[account]
pub struct GlobalPyre {
    pub mint: Pubkey,
    pub total_burned: u64,
    pub total_burn_events: u64,
    pub last_burn_timestamp: i64,
    pub bump: u8,
}

#[event]
pub struct SigilConsecratedEvent {
    pub practitioner: Pubkey,
    pub amount_burned: u64,
    pub intent_hash: [u8; 32],
    pub total_burned_cumulative: u64,
    pub timestamp: i64,
}

#[error_code]
pub enum IgnosisError {
    #[msg("Burn quantity must be greater than zero.")]
    ZeroBurnAmount,
    #[msg("Provided mint does not match the $IGNOSIS global mint.")]
    InvalidMint,
    #[msg("Token account authority mismatch.")]
    UnauthorizedTokenAccount,
}
