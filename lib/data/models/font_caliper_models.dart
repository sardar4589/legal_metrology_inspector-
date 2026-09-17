/// Package shape type for Rule 24 Principal Display Panel area calculation.
enum PdpShape {
  rectangular('Rectangular', 'Height × Width of face'),
  cylindrical('Cylindrical', '40% of Height × Circumference'),
  irregular('Irregular', 'Total surface area computation');

  final String label;
  final String description;

  const PdpShape(this.label, this.description);
}

/// Principal Display Panel (PDP) dimensions and computed area under Rule 24 of PCR 2011.
class PdpDimensions {
  final double widthCm;
  final double heightCm;
  final PdpShape shape;
  final double areaCm2;
  final double minimumRequiredFontMm;

  const PdpDimensions({
    required this.widthCm,
    required this.heightCm,
    required this.shape,
    required this.areaCm2,
    required this.minimumRequiredFontMm,
  });

  factory PdpDimensions.calculate({
    required double widthCm,
    required double heightCm,
    required PdpShape shape,
    required double netQuantityGrams,
  }) {
    double area;
    switch (shape) {
      case PdpShape.rectangular:
        area = widthCm * heightCm;
        break;
      case PdpShape.cylindrical:
        // Rule 24(2): 40% of the product of height and circumference
        area = 0.40 * heightCm * (widthCm * 3.14159);
        break;
      case PdpShape.irregular:
        area = widthCm * heightCm * 0.70;
        break;
    }

    final minFont = getTableIMinimumFontHeight(
      netQuantityGrams: netQuantityGrams,
      pdpAreaCm2: area,
    );

    return PdpDimensions(
      widthCm: widthCm,
      heightCm: heightCm,
      shape: shape,
      areaCm2: double.parse(area.toStringAsFixed(1)),
      minimumRequiredFontMm: minFont,
    );
  }

  /// Evaluates statutory minimum font height under Rule 9(1) Table-I of PCR 2011.
  static double getTableIMinimumFontHeight({
    required double netQuantityGrams,
    required double pdpAreaCm2,
  }) {
    if (netQuantityGrams <= 50) {
      if (pdpAreaCm2 <= 100) return 1.0;
      if (pdpAreaCm2 <= 500) return 1.5;
      return 2.0;
    } else if (netQuantityGrams <= 200) {
      if (pdpAreaCm2 <= 100) return 2.0;
      if (pdpAreaCm2 <= 500) return 3.0;
      return 4.0;
    } else if (netQuantityGrams <= 1000) {
      if (pdpAreaCm2 <= 500) return 4.0;
      return 6.0;
    } else {
      return 6.0;
    }
  }
}

/// Status of local Edge AI processing on camera frames.
enum EdgeAiState {
  standby('STANDBY', 'Scanning frame for package'),
  detectingPdp('DETECTING PDP', 'Aligning Principal Display Panel'),
  pdpLocked('PDP LOCKED', 'Bounding box confirmed'),
  measuring('MEASURING OCR', 'Running optical font caliper'),
  completed('AUDIT COMPLETE', 'Compliance evaluated');

  final String label;
  final String description;

  const EdgeAiState(this.label, this.description);
}

/// Optical Caliper measurement data for declared numerals on the package label.
class FontCaliperMeasurement {
  final double measuredHeightMm;
  final double requiredHeightMm;
  final String targetField;
  final double ocrConfidence; // 0.0 to 1.0 (e.g. 0.68)
  final String ruleReference;

  const FontCaliperMeasurement({
    required this.measuredHeightMm,
    required this.requiredHeightMm,
    this.targetField = 'Net Quantity "1 L"',
    required this.ocrConfidence,
    this.ruleReference = 'Rule 9(1) Table-I, PCR 2011',
  });

  bool get isCompliant => measuredHeightMm >= requiredHeightMm;
  bool get isLowConfidence => ocrConfidence < 0.75; // Warning threshold at 75%

  FontCaliperMeasurement copyWith({
    double? measuredHeightMm,
    double? requiredHeightMm,
    String? targetField,
    double? ocrConfidence,
    String? ruleReference,
  }) {
    return FontCaliperMeasurement(
      measuredHeightMm: measuredHeightMm ?? this.measuredHeightMm,
      requiredHeightMm: requiredHeightMm ?? this.requiredHeightMm,
      targetField: targetField ?? this.targetField,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      ruleReference: ruleReference ?? this.ruleReference,
    );
  }
}
