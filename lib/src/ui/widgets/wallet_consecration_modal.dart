import 'package:flutter/material.dart';
import '../../models/revenue_schema.dart';
import '../../services/iap_service.dart';
import '../../services/secure_key_storage_service.dart';
import '../../services/solana_wallet_service.dart';
import '../theme/sigil_skins.dart';
import 'seed_phrase_export_modal.dart';

/// Modal for connecting, inspecting, adjusting burn amount, and burning $IGNOSIS
class WalletConsecrationModal extends StatefulWidget {
  final String rawIntent;
  final SigilSkinTheme theme;
  final Function(String txSignature, double tokensBurned) onBurnSuccess;

  const WalletConsecrationModal({
    super.key,
    required this.rawIntent,
    required this.theme,
    required this.onBurnSuccess,
  });

  @override
  State<WalletConsecrationModal> createState() => _WalletConsecrationModalState();
}

class _WalletConsecrationModalState extends State<WalletConsecrationModal> {
  final _walletService = SolanaWalletService();
  final _keyStorage = SecureKeyStorageService();
  late final TextEditingController _addressController;
  late final TextEditingController _burnAmountController;

  bool _isTransacting = false;
  bool _hasInAppWallet = false;
  final double _solBalance = 3.42;
  double _ignosisBalance = 777.0; // Externally acquired or starter pack balance
  double _burnAmount = RevenueSchemaConfig.defaultBurnAmount.toDouble();

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: '7xKy...IgnosisPractitioner42');
    _burnAmountController = TextEditingController(text: RevenueSchemaConfig.defaultBurnAmount.toString());
    _loadInAppWallet();
  }

  Future<void> _loadInAppWallet() async {
    final hasWallet = await _keyStorage.hasInAppWallet();
    if (hasWallet) {
      final addr = await _keyStorage.getPublicAddress();
      if (addr != null && mounted) {
        setState(() {
          _hasInAppWallet = true;
          _addressController.text = addr;
        });
      }
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _burnAmountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final parsed = double.tryParse(val.trim());
    if (parsed != null && parsed > 0) {
      setState(() => _burnAmount = parsed);
    }
  }

  Future<void> _executeOnChainBurn() async {
    if (_burnAmount > _ignosisBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: widget.theme.burn,
          content: Text('Insufficient \$IGNOSIS balance (${_ignosisBalance.toStringAsFixed(0)} available). Acquire more or purchase the \$1.99 starter pack.'),
        ),
      );
      return;
    }

    setState(() => _isTransacting = true);

    try {
      final txSig = await _walletService.submitBurnConsecration(
        walletAddress: _addressController.text,
        rawIntent: widget.rawIntent,
        amount: _burnAmount,
      );

      setState(() {
        _ignosisBalance = (_ignosisBalance - _burnAmount).clamp(0.0, double.infinity);
        _isTransacting = false;
      });

      if (mounted) {
        widget.onBurnSuccess(txSig, _burnAmount);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isTransacting = false);
      }
    }
  }

  Future<void> _buyStarterPack() async {
    setState(() => _isTransacting = true);

    try {
      await IapService.instance.buyIgnitionStarterPack();
      final userAddress = await _keyStorage.getPublicAddress();

      setState(() {
        if (userAddress != null) {
          _addressController.text = userAddress;
          _hasInAppWallet = true;
        }
        _ignosisBalance += RevenueSchemaConfig.starterPackTokensDeposited;
        _isTransacting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: widget.theme.inkPrimary,
            content: const Text('Ignition Pack Activated! 279 \$IGNOSIS deposited into your vault.'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isTransacting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: widget.theme.burn,
            content: Text('Failed to complete starter pack: $e'),
          ),
        );
      }
    }
  }

  Future<void> _showSeedPhraseModal() async {
    final mnemonic = await _keyStorage.getRecoveryMnemonic();
    final address = await _keyStorage.getPublicAddress() ?? _addressController.text;

    if (mnemonic != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => SeedPhraseExportModal(
          mnemonic: mnemonic,
          publicAddress: address,
          theme: widget.theme,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Dialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.hairline),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                      color: theme.background,
                      border: Border.all(color: theme.hairline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.account_balance_wallet_outlined, size: 18, color: theme.inkPrimary),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r'SOLANA $IGNOSIS VAULT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: theme.inkPrimary,
                        ),
                      ),
                      Text(
                        'Connect Any Solana Wallet · Free to Burn Externally Acquired Tokens',
                        style: TextStyle(fontSize: 10, color: theme.inkMuted),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: theme.inkMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Wallet State & Balances Board
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.hairline),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ACTIVE SOLANA ADDRESS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: theme.inkMuted)),
                        Row(
                          children: [
                            if (_hasInAppWallet)
                              InkWell(
                                onTap: _showSeedPhraseModal,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.key, size: 11, color: theme.accent),
                                      const SizedBox(width: 3),
                                      Text('VIEW 12 WORDS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: theme.accent)),
                                    ],
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _hasInAppWallet ? theme.surfaceElevated : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _hasInAppWallet ? 'ENCLAVE VAULT' : 'EXTERNAL LINKED',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: _hasInAppWallet ? theme.inkPrimary : const Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _addressController.text,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600, color: theme.inkPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Divider(height: 18, color: theme.hairline),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildBalanceTile('SOL BALANCE', '${_solBalance.toStringAsFixed(2)} SOL', Icons.toll),
                        Container(width: 1, height: 32, color: theme.hairline),
                        _buildBalanceTile(r'$IGNOSIS BALANCE', '${_ignosisBalance.toStringAsFixed(0)} \$IGNOSIS', Icons.local_fire_department, isAccent: true),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Starter Pack Promotion Tile
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.hairline),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text('🜂', style: TextStyle(fontSize: 12, color: theme.accent)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Need \$IGNOSIS? Get 279 Tokens', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.inkPrimary)),
                          Text('Set up wallet & deposit 279 \$IGNOSIS (3 full rites)', style: TextStyle(fontSize: 10, color: theme.inkMuted)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.inkPrimary,
                        foregroundColor: theme.surface,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _isTransacting ? null : _buyStarterPack,
                      child: const Text('\$1.99', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Modifiable Burn Quantity Control
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CONSECRATION HEAT SACRIFICE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: theme.inkMuted),
                  ),
                  Text(
                    'Default: 93 \$IGNOSIS',
                    style: TextStyle(fontSize: 10, color: theme.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _burnAmountController,
                      keyboardType: TextInputType.number,
                      onChanged: _onAmountChanged,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.inkPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.background,
                        suffixText: r'$IGNOSIS',
                        suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: theme.accent, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.hairline)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.hairline)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.inkPrimary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Preset Quick Chips
                  Wrap(
                    spacing: 6,
                    children: [33, 93, 279].map((amt) {
                      final isSelected = _burnAmount == amt;
                      return ChoiceChip(
                        label: Text('$amt'),
                        selected: isSelected,
                        selectedColor: theme.surfaceElevated,
                        backgroundColor: theme.background,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? theme.accent : theme.inkSecondary,
                        ),
                        side: BorderSide(color: isSelected ? theme.accent : theme.hairline),
                        onSelected: (_) {
                          _burnAmountController.text = amt.toString();
                          _onAmountChanged(amt.toString());
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Burn Action
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.inkPrimary,
                    foregroundColor: theme.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isTransacting ? null : _executeOnChainBurn,
                  icon: _isTransacting
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.surface))
                      : Icon(Icons.whatshot, size: 18, color: theme.accent),
                  label: Text(
                    _isTransacting ? 'TRANSMITTING SACRIFICE TO SOLANA...' : 'INCINERATE ${_burnAmount.toInt()} \$IGNOSIS ON-CHAIN',
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 11),
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
    final theme = widget.theme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: isAccent ? theme.accent : theme.inkMuted),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.inkMuted)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isAccent ? theme.accent : theme.inkPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
