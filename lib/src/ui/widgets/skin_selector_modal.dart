import 'package:flutter/material.dart';
import '../theme/sigil_skins.dart';

/// Clean minimalist modal to select from the 8 aesthetic magic genre skins
class SkinSelectorModal extends StatelessWidget {
  final SigilSkinId currentSkinId;
  final ValueChanged<SigilSkinId> onSkinSelected;
  final SigilSkinTheme theme;

  const SkinSelectorModal({
    super.key,
    required this.currentSkinId,
    required this.onSkinSelected,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.hairline),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.hairline),
                    ),
                    child: const Center(
                      child: Text('🎨', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESOTERIC AESTHETIC SKINS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: theme.inkPrimary,
                        ),
                      ),
                      Text(
                        'Select visual paradigm for studio and canvas',
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
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.hairline),
              const SizedBox(height: 12),

              // Skin Grid List
              Expanded(
                child: ListView.separated(
                  itemCount: SigilSkinId.values.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final skinId = SigilSkinId.values[index];
                    final skin = SigilSkinTheme.getSkin(skinId);
                    final isSelected = skinId == currentSkinId;

                    return InkWell(
                      onTap: () {
                        onSkinSelected(skinId);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.surfaceElevated : theme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? theme.accent : theme.hairline,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Palette swatches preview
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: skin.background,
                                shape: BoxShape.circle,
                                border: Border.all(color: skin.hairlineStrong),
                              ),
                              child: Center(
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: skin.inkPrimary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        skin.id.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.inkPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: theme.hairline,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          skin.id.isDark ? 'DARK' : 'LIGHT',
                                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: theme.inkMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    skin.id.description,
                                    style: TextStyle(fontSize: 10, color: theme.inkSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle, size: 18, color: theme.accent),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
