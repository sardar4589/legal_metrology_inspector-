import 'dart:math';
import '../models/fifth_schedule_models.dart';

/// Statutory calculation engine according to Rule 24 and the Fifth Schedule
/// of The Legal Metrology (Packaged Commodities) Rules, 2011.
class FifthScheduleService {
  FifthScheduleService._();

  /// Computes the Maximum Permissible Error (MPE) for a given declared net quantity.
  /// Returns a Map with 'mpeValue' in base units and 'mpePercent' if percentage-based.
  static ({double mpeValue, double mpePercent}) calculateMpe({
    required double declaredQuantity,
    required WeightUnit unit,
  }) {
    // Normalize to base grams/milliliters for lookup
    final double inBase;
    final bool isKgOrL = unit == WeightUnit.kilograms || unit == WeightUnit.liters;

    if (isKgOrL) {
      inBase = declaredQuantity * 1000.0;
    } else {
      inBase = declaredQuantity;
    }

    double mpeBase;
    double mpePercent;

    if (inBase <= 50.0) {
      mpePercent = 9.0;
      mpeBase = inBase * 0.09;
    } else if (inBase <= 100.0) {
      mpePercent = (4.5 / inBase) * 100.0;
      mpeBase = 4.5;
    } else if (inBase <= 200.0) {
      mpePercent = 4.5;
      mpeBase = inBase * 0.045;
    } else if (inBase <= 300.0) {
      mpePercent = (9.0 / inBase) * 100.0;
      mpeBase = 9.0;
    } else if (inBase <= 500.0) {
      mpePercent = 3.0;
      mpeBase = inBase * 0.03;
    } else if (inBase <= 1000.0) {
      mpePercent = (15.0 / inBase) * 100.0;
      mpeBase = 15.0;
    } else if (inBase <= 10000.0) {
      mpePercent = 1.5;
      mpeBase = inBase * 0.015;
    } else if (inBase <= 15000.0) {
      mpePercent = (150.0 / inBase) * 100.0;
      mpeBase = 150.0;
    } else {
      mpePercent = 1.0;
      mpeBase = inBase * 0.01;
    }

    // Convert mpeBase back to original unit if input was kg or L
    final double finalMpe = isKgOrL ? (mpeBase / 1000.0) : mpeBase;

    return (mpeValue: finalMpe, mpePercent: mpePercent);
  }

  /// Returns the statutory Student's t factor k = t / sqrt(n)
  /// given in the Fifth Schedule Table of PCR 2011.
  static double getFactorK(int sampleSize) {
    if (sampleSize <= 8) return 0.769;
    if (sampleSize <= 13) return 0.523;
    if (sampleSize <= 20) return 0.404;
    if (sampleSize <= 32) return 0.379;
    if (sampleSize <= 50) return 0.328;
    if (sampleSize <= 80) return 0.262;
    if (sampleSize <= 125) return 0.207;
    // Asymptotic standard approximation for larger sample sizes
    return 1.645 / sqrt(sampleSize.toDouble());
  }

  /// Returns the maximum allowed T1 defective packages for a given sample size n
  /// according to the Fifth Schedule sampling criteria.
  static int getMaxPermissibleT1(int sampleSize) {
    if (sampleSize <= 8) return 0;
    if (sampleSize <= 20) return 1;
    if (sampleSize <= 32) return 2;
    if (sampleSize <= 50) return 3;
    if (sampleSize <= 80) return 5;
    if (sampleSize <= 125) return 7;
    return max(1, (sampleSize * 0.06).floor());
  }

  /// Performs full statistical analysis of sample package weights
  /// according to Rule 24 and Fifth Schedule of PCR 2011.
  static StatisticalLotMetrics computeLotMetrics({
    required List<SamplePackageWeight> samples,
    required double declaredQuantity,
    required WeightUnit unit,
    required double mpe,
  }) {
    if (samples.isEmpty) {
      return StatisticalLotMetrics(
        totalSamples: 0,
        declaredQuantity: declaredQuantity,
        unit: unit,
        sampleMean: 0.0,
        standardDeviation: 0.0,
        studentTFactor: 0.0,
        correctedAverage: 0.0,
        mpeLimit: mpe,
        t1DefectiveCount: 0,
        t2DefectiveCount: 0,
        maxAllowedT1: 0,
        isAverageCompliant: false,
        isDefectivesCompliant: false,
        isLotPassed: false,
        statusSummary: 'No samples recorded',
        legalCitation: 'Rule 24, Fifth Schedule PCR 2011',
      );
    }

    final n = samples.length;
    final netWeights = samples.map((s) => s.netWeight).toList();

    // 1. Sample Mean
    final sum = netWeights.reduce((a, b) => a + b);
    final mean = sum / n;

    // 2. Standard Deviation
    double variance = 0.0;
    if (n > 1) {
      for (final w in netWeights) {
        variance += (w - mean) * (w - mean);
      }
      variance = variance / (n - 1);
    }
    final stdDev = sqrt(variance);

    // 3. Statutory factor k and Corrected Average
    final k = getFactorK(n);
    final correctedAvg = mean - (k * stdDev);

    // 4. Defective counts
    int t1Count = 0;
    int t2Count = 0;
    for (final s in samples) {
      if (s.classification == SampleErrorClassification.t2SevereDefective) {
        t2Count++;
        t1Count++; // T2 is also a T1 error
      } else if (s.classification == SampleErrorClassification.t1Defective) {
        t1Count++;
      }
    }

    final maxT1 = getMaxPermissibleT1(n);
    final isAvgCompliant = correctedAvg >= declaredQuantity;
    // T2 defectives must be strictly ZERO per statutory law
    final isDefectivesCompliant = (t1Count <= maxT1) && (t2Count == 0);
    final isPassed = isAvgCompliant && isDefectivesCompliant;

    String summary;
    if (isPassed) {
      summary = 'MPE PASS — Lot complies with Rule 24 & Fifth Schedule criteria.';
    } else if (!isAvgCompliant && !isDefectivesCompliant) {
      summary = 'MPE FAIL — Corrected Average ($correctedAvg) < Declared ($declaredQuantity) & Defectives exceed limit.';
    } else if (!isAvgCompliant) {
      summary = 'MPE FAIL — Corrected Average ($correctedAvg) is below Declared Net Content ($declaredQuantity).';
    } else {
      summary = 'MPE FAIL — $t1Count packages exceed MPE (limit: $maxT1). Zero T2 errors permitted.';
    }

    return StatisticalLotMetrics(
      totalSamples: n,
      declaredQuantity: declaredQuantity,
      unit: unit,
      sampleMean: mean,
      standardDeviation: stdDev,
      studentTFactor: k,
      correctedAverage: correctedAvg,
      mpeLimit: mpe,
      t1DefectiveCount: t1Count,
      t2DefectiveCount: t2Count,
      maxAllowedT1: maxT1,
      isAverageCompliant: isAvgCompliant,
      isDefectivesCompliant: isDefectivesCompliant,
      isLotPassed: isPassed,
      statusSummary: summary,
      legalCitation: 'Fifth Schedule, Rule 24 of PCR 2011 read with Sec. 39 LM Act 2009',
    );
  }

  /// Generates a realistic mock batch of sample package weights for testing & demonstration.
  /// If [simulateDeficient] is true, generates a batch with negative bias and defective units.
  static List<SamplePackageWeight> generateMockSampleWeights({
    required int sampleCount,
    required double declaredQuantity,
    required double tareWeight,
    required double mpe,
    bool simulateDeficient = false,
  }) {
    final random = Random(42);
    final List<SamplePackageWeight> result = [];

    for (int i = 1; i <= sampleCount; i++) {
      double simulatedNet;
      if (simulateDeficient) {
        // Deliberately deficient lot around Qn - 1.2 * MPE with occasional severe drops
        if (i == 3 || i == 14) {
          // T2 severe defective (> 2x MPE)
          simulatedNet = declaredQuantity - (mpe * 2.3) + (random.nextDouble() * 0.2);
        } else if (i == 7 || i == 21 || i == 29) {
          // T1 defective (> 1x MPE)
          simulatedNet = declaredQuantity - (mpe * 1.3) + (random.nextDouble() * 0.4);
        } else {
          // Slight deficiency
          simulatedNet = declaredQuantity - (mpe * 0.4) + ((random.nextDouble() - 0.5) * mpe * 0.6);
        }
      } else {
        // Compliant passing lot centered around Qn + 0.3 * MPE
        simulatedNet = declaredQuantity + (mpe * 0.25) + ((random.nextDouble() - 0.4) * mpe * 0.5);
      }

      final gross = simulatedNet + tareWeight;
      result.add(
        SamplePackageWeight.calculate(
          sampleNumber: i,
          grossWeight: double.parse(gross.toStringAsFixed(2)),
          tareWeight: tareWeight,
          declaredQuantity: declaredQuantity,
          mpe: mpe,
        ),
      );
    }

    return result;
  }
}
