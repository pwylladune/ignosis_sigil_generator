import 'package:flutter/material.dart';

enum SigilSkinId {
  vellumDraft('vellumDraft', 'Vellum & Ink (Default)', 'Archival drafting paper, sumi ink, subtle vermilion bind-point', false),
  techOccult('techOccult', 'Tech-Occult', 'Phosphor green on terminal void, matrix wireframe telemetry', true),
  darkAcademia('darkAcademia', 'Dark Academia', 'Aged parchment, sepia manuscript ink, oxidized iron gall borders', false),
  cosmic('cosmic', 'Cosmic', 'Deep stellar void, astral nebular violet, ultraviolet starlight', true),
  surrealist('surrealist', 'Surrealist', 'Bone canvas, dreamscape cobalt ink, incandescent dream embers', false),
  alchemical('alchemical', 'Alchemical', 'Nigredo slate, mercury silver hairlines, aurum gold seal', true),
  wiccan('wiccan', 'Wiccan', 'Lichen parchment, forest root ink, waxing moon silver glow', false),
  chaos('chaos', 'Chaos (Liber Null)', 'Abyssal matte black, pure stark white vector, 8-fold chaosphere vermilion', true);

  final String key;
  final String label;
  final String description;
  final bool isDark;

  const SigilSkinId(this.key, this.label, this.description, this.isDark);
}

class SigilSkinTheme {
  final SigilSkinId id;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color hairline;
  final Color hairlineStrong;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkMuted;
  final Color accent;
  final Color accentOn;
  final Color burn;
  final Color canvasBackground;
  final Color guideColor;
  final double strokeWidth;
  final double inkWashOpacity;
  final String fontFamily;

  const SigilSkinTheme({
    required this.id,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.hairline,
    required this.hairlineStrong,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkMuted,
    required this.accent,
    required this.accentOn,
    required this.burn,
    required this.canvasBackground,
    required this.guideColor,
    this.strokeWidth = 2.0,
    this.inkWashOpacity = 0.08,
    this.fontFamily = '-apple-system',
  });

  static SigilSkinTheme getSkin(SigilSkinId id) {
    switch (id) {
      case SigilSkinId.vellumDraft:
        return const SigilSkinTheme(
          id: SigilSkinId.vellumDraft,
          background: Color(0xFFF4F4F0),
          surface: Color(0xFFFFFFFF),
          surfaceElevated: Color(0xFFFFFFFF),
          hairline: Color(0xFFE5E5DF),
          hairlineStrong: Color(0xFFD4D4CA),
          inkPrimary: Color(0xFF141416),
          inkSecondary: Color(0xFF52525B),
          inkMuted: Color(0xFFA1A1AA),
          accent: Color(0xFFC0392B),
          accentOn: Color(0xFFFFFFFF),
          burn: Color(0xFFD97706),
          canvasBackground: Color(0xFFF9F9F6),
          guideColor: Color(0xFFE5E5DF),
          strokeWidth: 2.0,
          inkWashOpacity: 0.07,
        );

      case SigilSkinId.techOccult:
        return const SigilSkinTheme(
          id: SigilSkinId.techOccult,
          background: Color(0xFF070B08),
          surface: Color(0xFF0D140F),
          surfaceElevated: Color(0xFF141F17),
          hairline: Color(0xFF1B2E21),
          hairlineStrong: Color(0xFF2E4E37),
          inkPrimary: Color(0xFF00FF66),
          inkSecondary: Color(0xFF4ADE80),
          inkMuted: Color(0xFF1E3A24),
          accent: Color(0xFF00FF66),
          accentOn: Color(0xFF070B08),
          burn: Color(0xFFFF3366),
          canvasBackground: Color(0xFF0A0F0B),
          guideColor: Color(0xFF132217),
          strokeWidth: 1.8,
          inkWashOpacity: 0.15,
        );

      case SigilSkinId.darkAcademia:
        return const SigilSkinTheme(
          id: SigilSkinId.darkAcademia,
          background: Color(0xFFEDE8DD),
          surface: Color(0xFFF6F3EB),
          surfaceElevated: Color(0xFFFAF8F3),
          hairline: Color(0xFFD9D2C3),
          hairlineStrong: Color(0xFFBFAF9B),
          inkPrimary: Color(0xFF2C221E),
          inkSecondary: Color(0xFF5C4E44),
          inkMuted: Color(0xFF968779),
          accent: Color(0xFF8B2500),
          accentOn: Color(0xFFFFFFFF),
          burn: Color(0xFFC85A17),
          canvasBackground: Color(0xFFF5F0E6),
          guideColor: Color(0xFFDFD7C7),
          strokeWidth: 2.2,
          inkWashOpacity: 0.10,
        );

      case SigilSkinId.cosmic:
        return const SigilSkinTheme(
          id: SigilSkinId.cosmic,
          background: Color(0xFF06060E),
          surface: Color(0xFF0E0E1C),
          surfaceElevated: Color(0xFF16162A),
          hairline: Color(0xFF242442),
          hairlineStrong: Color(0xFF383866),
          inkPrimary: Color(0xFFE2E8F0),
          inkSecondary: Color(0xFFA5B4FC),
          inkMuted: Color(0xFF4338CA),
          accent: Color(0xFF818CF8),
          accentOn: Color(0xFF06060E),
          burn: Color(0xFFF43F5E),
          canvasBackground: Color(0xFF0A0A16),
          guideColor: Color(0xFF1A1A35),
          strokeWidth: 2.0,
          inkWashOpacity: 0.20,
        );

      case SigilSkinId.surrealist:
        return const SigilSkinTheme(
          id: SigilSkinId.surrealist,
          background: Color(0xFFF1EFEA),
          surface: Color(0xFFFAF9F6),
          surfaceElevated: Color(0xFFFFFFFF),
          hairline: Color(0xFFDDD9D0),
          hairlineStrong: Color(0xFFBEB8AA),
          inkPrimary: Color(0xFF0F2B5C),
          inkSecondary: Color(0xFF2563EB),
          inkMuted: Color(0xFF94A3B8),
          accent: Color(0xFFE11D48),
          accentOn: Color(0xFFFFFFFF),
          burn: Color(0xFFEA580C),
          canvasBackground: Color(0xFFF8F6F1),
          guideColor: Color(0xFFE2DDD3),
          strokeWidth: 2.1,
          inkWashOpacity: 0.08,
        );

      case SigilSkinId.alchemical:
        return const SigilSkinTheme(
          id: SigilSkinId.alchemical,
          background: Color(0xFF0B0D11),
          surface: Color(0xFF13171F),
          surfaceElevated: Color(0xFF1C222E),
          hairline: Color(0xFF2A3445),
          hairlineStrong: Color(0xFF455570),
          inkPrimary: Color(0xFFF59E0B),
          inkSecondary: Color(0xFFD4D4D8),
          inkMuted: Color(0xFF52525B),
          accent: Color(0xFFF59E0B),
          accentOn: Color(0xFF0B0D11),
          burn: Color(0xFFDC2626),
          canvasBackground: Color(0xFF0E1117),
          guideColor: Color(0xFF1E2633),
          strokeWidth: 2.0,
          inkWashOpacity: 0.14,
        );

      case SigilSkinId.wiccan:
        return const SigilSkinTheme(
          id: SigilSkinId.wiccan,
          background: Color(0xFFEFEFE9),
          surface: Color(0xFFF8F8F5),
          surfaceElevated: Color(0xFFFFFFFF),
          hairline: Color(0xFFDBDBCF),
          hairlineStrong: Color(0xFFBEBEAD),
          inkPrimary: Color(0xFF1E3A2F),
          inkSecondary: Color(0xFF3F6254),
          inkMuted: Color(0xFF839E92),
          accent: Color(0xFF9A3412),
          accentOn: Color(0xFFFFFFFF),
          burn: Color(0xFFC2410C),
          canvasBackground: Color(0xFFF4F4EE),
          guideColor: Color(0xFFE1E1D7),
          strokeWidth: 2.2,
          inkWashOpacity: 0.09,
        );

      case SigilSkinId.chaos:
        return const SigilSkinTheme(
          id: SigilSkinId.chaos,
          background: Color(0xFF050505),
          surface: Color(0xFF0F0F0F),
          surfaceElevated: Color(0xFF1A1A1A),
          hairline: Color(0xFF2B2B2B),
          hairlineStrong: Color(0xFF4A4A4A),
          inkPrimary: Color(0xFFFAFAFA),
          inkSecondary: Color(0xFFA3A3A3),
          inkMuted: Color(0xFF525252),
          accent: Color(0xFFE11D48),
          accentOn: Color(0xFFFFFFFF),
          burn: Color(0xFFF97316),
          canvasBackground: Color(0xFF0A0A0A),
          guideColor: Color(0xFF222222),
          strokeWidth: 2.4,
          inkWashOpacity: 0.25,
        );
    }
  }
}
