/// Supported unit of measurement for Fifth Schedule package testing.
enum WeightUnit {
  grams('g', 'Grams'),
  kilograms('kg', 'Kilograms'),
  milliliters('ml', 'Milliliters'),
  liters('L', 'Liters');

  final String symbol;
  final String label;

  const WeightUnit(this.symbol, this.label);
}

/// Statutory classification of a sample package's error under Fifth Schedule.
enum SampleErrorClassification {
  compliant('COMPLIANT', 'Within permissible limits'),
  t1Defective('T1 DEFECTIVE', 'Deficiency exceeds Maximum Permissible Error (MPE)'),
  t2SevereDefective('T2 SEVERE DEFECTIVE', 'Deficiency exceeds 2x MPE (Unlawful)');

  final String label;
  final String description;

  const SampleErrorClassification(this.label, this.description);
}

/// Configuration parameters for a Fifth Schedule lot inspection.
class FifthScheduleConfig {
  final String commodityName;
  final double declaredQuantity; // Qn
  final WeightUnit unit;
  final int lotSize; // N (total packages in lot/batch)
  final int sampleSize; // n (samples drawn, e.g. 32)
  final double tareWeight; // T (average weight of empty container/wrapper)
  final double mpeValue; // Computed statutory MPE in same unit as declaredQuantity
  final double mpePercent; // Computed MPE as percentage if applicable
  final int maxPermissibleT1Defectives; // Allowed T1 defective packages for sample size n

  const FifthScheduleConfig({
    required this.commodityName,
    required this.declaredQuantity,
    required this.unit,
    required this.lotSize,
    required this.sampleSize,
    required this.tareWeight,
    required this.mpeValue,
    required this.mpePercent,
    required this.maxPermissibleT1Defectives,
  });

  FifthScheduleConfig copyWith({
    String? commodityName,
    double? declaredQuantity,
    WeightUnit? unit,
    int? lotSize,
    int? sampleSize,
    double? tareWeight,
    double? mpeValue,
    double? mpePercent,
    int? maxPermissibleT1Defectives,
  }) {
    return FifthScheduleConfig(
      commodityName: commodityName ?? this.commodityName,
      declaredQuantity: declaredQuantity ?? this.declaredQuantity,
      unit: unit ?? this.unit,
      lotSize: lotSize ?? this.lotSize,
      sampleSize: sampleSize ?? this.sampleSize,
      tareWeight: tareWeight ?? this.tareWeight,
      mpeValue: mpeValue ?? this.mpeValue,
      mpePercent: mpePercent ?? this.mpePercent,
      maxPermissibleT1Defectives: maxPermissibleT1Defectives ?? this.maxPermissibleT1Defectives,
    );
  }
}

/// Individual sample package weight measurement and error evaluation.
class SamplePackageWeight {
  final int sampleNumber; // 1-indexed
  final double grossWeight;
  final double tareWeight;
  final double netWeight; // Gross - Tare
  final double declaredQuantity;
  final double individualError; // Net - DeclaredQuantity (negative means deficiency)
  final double mpe; // Statutory MPE
  final SampleErrorClassification classification;

  const SamplePackageWeight({
    required this.sampleNumber,
    required this.grossWeight,
    required this.tareWeight,
    required this.netWeight,
    required this.declaredQuantity,
    required this.individualError,
    required this.mpe,
    required this.classification,
  });

  factory SamplePackageWeight.calculate({
    required int sampleNumber,
    required double grossWeight,
    required double tareWeight,
    required double declaredQuantity,
    required double mpe,
  }) {
    final net = grossWeight - tareWeight;
    final error = net - declaredQuantity;

    SampleErrorClassification classification;
    if (error < -(2.0 * mpe)) {
      classification = SampleErrorClassification.t2SevereDefective;
    } else if (error < -mpe) {
      classification = SampleErrorClassification.t1Defective;
    } else {
      classification = SampleErrorClassification.compliant;
    }

    return SamplePackageWeight(
      sampleNumber: sampleNumber,
      grossWeight: grossWeight,
      tareWeight: tareWeight,
      netWeight: net,
      declaredQuantity: declaredQuantity,
      individualError: error,
      mpe: mpe,
      classification: classification,
    );
  }

  bool get isT1Defective => classification == SampleErrorClassification.t1Defective;
  bool get isT2Defective => classification == SampleErrorClassification.t2SevereDefective;
  bool get isCompliant => classification == SampleErrorClassification.compliant;
}

/// Overall statistical lot compliance metrics under Fifth Schedule / Rule 24 of PCR 2011.
class StatisticalLotMetrics {
  final int totalSamples;
  final double declaredQuantity;
  final WeightUnit unit;
  final double sampleMean; // \bar{x}
  final double standardDeviation; // s
  final double studentTFactor; // t-factor for sample size n
  final double correctedAverage; // \bar{x} - (t * s / sqrt(n))
  final double mpeLimit;
  final int t1DefectiveCount; // Count of packages exceeding MPE
  final int t2DefectiveCount; // Count of packages exceeding 2x MPE
  final int maxAllowedT1;
  final bool isAverageCompliant; // Corrected Average >= Declared Quantity
  final bool isDefectivesCompliant; // T1 <= maxAllowedT1 and T2 == 0
  final bool isLotPassed; // Both average and defectives compliant
  final String statusSummary;
  final String legalCitation;

  const StatisticalLotMetrics({
    required this.totalSamples,
    required this.declaredQuantity,
    required this.unit,
    required this.sampleMean,
    required this.standardDeviation,
    required this.studentTFactor,
    required this.correctedAverage,
    required this.mpeLimit,
    required this.t1DefectiveCount,
    required this.t2DefectiveCount,
    required this.maxAllowedT1,
    required this.isAverageCompliant,
    required this.isDefectivesCompliant,
    required this.isLotPassed,
    required this.statusSummary,
    required this.legalCitation,
  });
}
