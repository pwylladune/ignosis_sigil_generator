import 'package:flutter/material.dart';
import '../engines/kamea_engine.dart';

enum SigilSystem {
  spare('Austin Osman Spare', 'Letter reduction monogram with rotational symmetry'),
  kamea('Planetary Kamea', 'Planetary magic square ciphers (Saturn to Luna)'),
  roseCross('Rose Cross Dial', 'Hermetic 26-node Rosicrucian dial wheel'),
  chladni('Cymatic Resonance', '2D acoustic Chladni plate vibration nodal field'),
  cyberChaos('Cyber Chaos', 'Cryptographic SHA-256 entropy polar lattice');

  final String title;
  final String description;
  const SigilSystem(this.title, this.description);
}

class SigilState {
  final String rawIntent;
  final SigilSystem system;
  final PlanetaryKameaType kameaType;
  final int symmetryFolds;
  final Color primaryColor;
  final double strokeWidth;
  final bool isGnosisMode;
  final double burnProgress; // 0.0 (unburned) to 1.0 (incinerated)
  final bool isIncinerated;
  final String? lastBurnTxSignature;

  const SigilState({
    this.rawIntent = 'I COMMAND RADIANT CLARITY',
    this.system = SigilSystem.spare,
    this.kameaType = PlanetaryKameaType.sol,
    this.symmetryFolds = 4,
    this.primaryColor = const Color(0xFF00E5FF), // Cyan radiance
    this.strokeWidth = 2.5,
    this.isGnosisMode = false,
    this.burnProgress = 0.0,
    this.isIncinerated = false,
    this.lastBurnTxSignature,
  });

  SigilState copyWith({
    String? rawIntent,
    SigilSystem? system,
    PlanetaryKameaType? kameaType,
    int? symmetryFolds,
    Color? primaryColor,
    double? strokeWidth,
    bool? isGnosisMode,
    double? burnProgress,
    bool? isIncinerated,
    String? lastBurnTxSignature,
  }) {
    return SigilState(
      rawIntent: rawIntent ?? this.rawIntent,
      system: system ?? this.system,
      kameaType: kameaType ?? this.kameaType,
      symmetryFolds: symmetryFolds ?? this.symmetryFolds,
      primaryColor: primaryColor ?? this.primaryColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isGnosisMode: isGnosisMode ?? this.isGnosisMode,
      burnProgress: burnProgress ?? this.burnProgress,
      isIncinerated: isIncinerated ?? this.isIncinerated,
      lastBurnTxSignature: lastBurnTxSignature ?? this.lastBurnTxSignature,
    );
  }
}
