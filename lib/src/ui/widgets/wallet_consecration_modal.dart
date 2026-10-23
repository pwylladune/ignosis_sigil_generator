import 'package:flutter/material.dart';
import '../../services/solana_wallet_service.dart';
import '../theme/ignosis_theme.dart';

/// Modal for connecting, funding, and inspecting the Solana $IGNOSIS bank
class WalletConsecrationModal extends StatefulWidget {
  final String rawIntent;
  final Function(String txSignature, double tokensBurned) onBurnSuccess;

  const WalletConsecrationModal({
    super.key,
    required this.rawIntent,
    required this.onBurnSuccess,
  });

  @override
  State<WalletConsecrationModal> createState() => _WalletConsecrationModalState();
}

class _WalletConsecrationModalState extends State<WalletConsecrationModal> {
  final _walletService = SolanaWalletService();
  final _addressController = TextEditingController(text: '7xKy...IgnosisPractitioner42');

  bool _isTransacting = false;
  final double _solBalance = 3.42;
  double _ignosisBalance = 777.0; // Practitioner token bank

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _executeOnChainBurn() async {
    setState(() => _isTransacting = true);

    try {
      final txSig = await _walletService.submitBurnConsecration(
        walletAddress: _addressController.text,
        rawIntent: widget.rawIntent,
        amount: 93.0,
      );

      setState(() {
        _ignosisBalance = (_ignosisBalance - 93.0).clamp(0.0, double.infinity);
        _isTransacting = false;
      });

      if (mounted) {
        widget.onBurnSuccess(txSig, 93.0);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isTransacting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: IgnosisTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: IgnosisTheme.parchmentSubtle),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: IgnosisTheme.bone,
                      border: Border.all(color: IgnosisTheme.parchmentSubtle),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: IgnosisTheme.sumiInk),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r'SOLANA $IGNOSIS VAULT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: IgnosisTheme.sumiInk,
                        ),
                      ),
                      Text(
                        'Decentralized Energetic Burn Bank',
                        style: TextStyle(fontSize: 11, color: IgnosisTheme.pencilGraphite),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: IgnosisTheme.pencilGraphite),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Wallet State & Balances Board
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: IgnosisTheme.bone,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: IgnosisTheme.parchmentSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CONNECTED WALLET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: IgnosisTheme.pencilGraphite)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('SOLANA DEVNET', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _addressController.text,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600, color: IgnosisTheme.sumiInk),
                    ),
                    const Divider(height: 20, color: IgnosisTheme.parchmentSubtle),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildBalanceTile('SOL BALANCE', '${_solBalance.toStringAsFixed(2)} SOL', Icons.toll),
                        Container(width: 1, height: 36, color: IgnosisTheme.parchmentSubtle),
                        _buildBalanceTile(r'$IGNOSIS BANK', '${_ignosisBalance.toStringAsFixed(0)} \$IGNOSIS', Icons.local_fire_department, isAccent: true),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Burn Transaction Requirement
              const Text(
                'CONSECRATION SACRIFICE REQUIREMENT',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: IgnosisTheme.pencilGraphite),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: IgnosisTheme.paperWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: IgnosisTheme.parchmentSubtle),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Standard Rite Combustion:', style: TextStyle(fontSize: 12, color: IgnosisTheme.charcoal)),
                    Text('93 \$IGNOSIS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: IgnosisTheme.vermilion)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tokens are permanently transmitted to the Solana Incinerator address (1111...1111). '
                'Proof of heat will be anchored on-chain while your intent is wiped from local memory.',
                style: TextStyle(fontSize: 11, color: IgnosisTheme.pencilGraphite, height: 1.4),
              ),

              const SizedBox(height: 24),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IgnosisTheme.sumiInk,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isTransacting ? null : _executeOnChainBurn,
                  icon: _isTransacting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.whatshot, size: 18, color: IgnosisTheme.vermilion),
                  label: Text(
                    _isTransacting ? 'TRANSMITTING SACRIFICE TO SOLANA...' : 'INCINERATE 93 \$IGNOSIS ON-CHAIN',
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceTile(String title, String value, IconData icon, {bool isAccent = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: isAccent ? IgnosisTheme.vermilion : IgnosisTheme.pencilGraphite),
              const SizedBox(width: 4),
              Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: IgnosisTheme.pencilGraphite)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isAccent ? IgnosisTheme.vermilion : IgnosisTheme.sumiInk,
            ),
          ),
        ],
      ),
    );
  }
}
