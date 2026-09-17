import 'dart:typed_data';
import 'compliance_check.dart';
import 'product_details.dart';

enum InspectionStatus {
  pass,
  violation,
}

/// Represents the complete generated inspection report memo.
class InspectionReport {
  final String caseId;
  final String officerName;
  final String officerId;
  final DateTime timestamp;
  final String businessName;
  final String location;
  final InspectionStatus overallStatus;
  final String statusSummary;
  final ProductDetails productDetails;
  final List<ComplianceCheck> complianceChecks;
  final String? imagePath;
  final Uint8List? imageBytes;
  final String? sampleImageTag;
  final String? pdfPath;

  // Category-wise Classification (User Requirement)
  final String statutoryCategory;

  // Verified Weight Metrics (Manual or Bluetooth Scale)
  final double? measuredNetWeight;
  final double? weightVariancePercent;
  final bool? isWeightCompliant;
  final double? mpeLimit;

  const InspectionReport({
    required this.caseId,
    required this.officerName,
    required this.officerId,
    required this.timestamp,
    required this.businessName,
    required this.location,
    required this.overallStatus,
    required this.statusSummary,
    required this.productDetails,
    required this.complianceChecks,
    this.imagePath,
    this.imageBytes,
    this.sampleImageTag,
    this.pdfPath,
    this.statutoryCategory = 'Compliant Packages',
    this.measuredNetWeight,
    this.weightVariancePercent,
    this.isWeightCompliant,
    this.mpeLimit,
  });

  bool get isViolation => overallStatus == InspectionStatus.violation;

  /// Automatically derives the statutory violation category based on findings
  static String deriveCategory({
    required InspectionStatus status,
    required List<ComplianceCheck> checks,
    bool? isWeightCompliant,
  }) {
    if (isWeightCompliant == false) {
      return 'Weight Shortage (Fifth Schedule)';
    }
    if (status == InspectionStatus.violation) {
      final flagged = checks.where((c) => !c.isCompliant).toList();
      for (final c in flagged) {
        final title = c.title.toLowerCase();
        final ref = c.ruleReference.toLowerCase();
        if (title.contains('font') || ref.contains('9(1)') || title.contains('caliper')) {
          return 'Font Violations (Rule 9)';
        }
        if (title.contains('mrp') || title.contains('tamper') || ref.contains('18')) {
          return 'MRP Violations (Rule 18)';
        }
        if (title.contains('weight') || title.contains('quantity') || ref.contains('fifth')) {
          return 'Weight Shortage (Fifth Schedule)';
        }
      }
      return 'Declarations Missing (Rule 6)';
    }
    return 'Compliant Packages';
  }

  InspectionReport copyWith({
    String? caseId,
    String? officerName,
    String? officerId,
    DateTime? timestamp,
    String? businessName,
    String? location,
    InspectionStatus? overallStatus,
    String? statusSummary,
    ProductDetails? productDetails,
    List<ComplianceCheck>? complianceChecks,
    String? imagePath,
    Uint8List? imageBytes,
    String? sampleImageTag,
    String? pdfPath,
    String? statutoryCategory,
    double? measuredNetWeight,
    double? weightVariancePercent,
    bool? isWeightCompliant,
    double? mpeLimit,
  }) {
    return InspectionReport(
      caseId: caseId ?? this.caseId,
      officerName: officerName ?? this.officerName,
      officerId: officerId ?? this.officerId,
      timestamp: timestamp ?? this.timestamp,
      businessName: businessName ?? this.businessName,
      location: location ?? this.location,
      overallStatus: overallStatus ?? this.overallStatus,
      statusSummary: statusSummary ?? this.statusSummary,
      productDetails: productDetails ?? this.productDetails,
      complianceChecks: complianceChecks ?? this.complianceChecks,
      imagePath: imagePath ?? this.imagePath,
      imageBytes: imageBytes ?? this.imageBytes,
      sampleImageTag: sampleImageTag ?? this.sampleImageTag,
      pdfPath: pdfPath ?? this.pdfPath,
      statutoryCategory: statutoryCategory ?? this.statutoryCategory,
      measuredNetWeight: measuredNetWeight ?? this.measuredNetWeight,
      weightVariancePercent: weightVariancePercent ?? this.weightVariancePercent,
      isWeightCompliant: isWeightCompliant ?? this.isWeightCompliant,
      mpeLimit: mpeLimit ?? this.mpeLimit,
    );
  }

  /// Default realistic mock report matching the prompt requirements
  factory InspectionReport.mockOilViolation({
    String? imagePath,
    Uint8List? imageBytes,
    String? sampleTag,
  }) {
    return InspectionReport(
      caseId: 'LMD-2026-0911-042',
      officerName: 'Inspector R. Sharma',
      officerId: 'INSP-DL-4082',
      timestamp: DateTime.now(),
      businessName: 'Metro Mart, Counter 2',
      location: 'Plot 18, Central Market, North District',
      overallStatus: InspectionStatus.violation,
      statusSummary: 'VIOLATION DETECTED',
      imagePath: imagePath,
      imageBytes: imageBytes,
      sampleImageTag: sampleTag ?? 'goodlife_oil',
      productDetails: const ProductDetails(
        brandName: 'GoodLife Refined Oil',
        declaredNetQuantity: '1 L',
        declaredMrp: '₹145.00',
        unitSalePrice: '₹0.145 / ml',
        batchMfgDate: 'B-204 | 08/2026',
        manufacturerAddress: 'GoodLife Agrotech Ltd, Plot 42, GIDC Industrial Estate',
        consumerCareDetails: 'care@goodlife.com | Toll-free: 1800-200-333',
        countryOfOrigin: 'India',
      ),
      complianceChecks: const [
        ComplianceCheck(
          title: 'Mandatory Declarations',
          isCompliant: true,
          statusText: 'Found & Verified',
          ruleReference: 'Rule 6(1), PCR 2011',
          description: 'Name, address, net quantity, month/year of manufacture are all present.',
        ),
        ComplianceCheck(
          title: 'MRP & Unit Sale Price',
          isCompliant: true,
          statusText: 'Compliant',
          ruleReference: 'Rule 6(1)(e) & 6(11)',
          description: 'Declared MRP includes all taxes, and USP is accurately computed per ml.',
        ),
        ComplianceCheck(
          title: 'Principal Display Font Size',
          isCompliant: false,
          statusText: 'Non-compliant',
          flaggedDetail: 'Found 1.8mm, Required 3.0mm',
          ruleReference: 'Rule 9(1) Table-I',
          description: 'Numeral height for net quantity above 500ml/1L must not be less than 3.0mm.',
        ),
        ComplianceCheck(
          title: 'Consumer Care Redressal',
          isCompliant: true,
          statusText: 'Compliant',
          ruleReference: 'Rule 6(1)(da)',
          description: 'Official email and toll-free telephone number are legibly declared.',
        ),
      ],
    );
  }

  factory InspectionReport.mockAttaCompliant() {
    return InspectionReport(
      caseId: 'LMD-2026-0911-039',
      officerName: 'Inspector R. Sharma',
      officerId: 'INSP-DL-4082',
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
      businessName: 'Reliance Fresh Superstore',
      location: 'Sector 14, Main Road',
      overallStatus: InspectionStatus.pass,
      statusSummary: 'COMPLIANT / PASS',
      sampleImageTag: 'sharbati_atta',
      productDetails: const ProductDetails(
        brandName: 'FarmFresh Sharbati Atta',
        declaredNetQuantity: '5 kg',
        declaredMrp: '₹265.00',
        unitSalePrice: '₹53.00 / kg',
        batchMfgDate: 'A-108 | 09/2026',
        manufacturerAddress: 'Kisan Agro Foods Pvt Ltd, Industrial Area Phase II',
        consumerCareDetails: 'help@kisanagro.in | 1800-112-990',
        countryOfOrigin: 'India',
      ),
      complianceChecks: const [
        ComplianceCheck(
          title: 'Mandatory Declarations',
          isCompliant: true,
          statusText: 'Found & Verified',
          ruleReference: 'Rule 6(1), PCR 2011',
          description: 'All statutory declarations displayed conspicuously.',
        ),
        ComplianceCheck(
          title: 'MRP & Unit Sale Price',
          isCompliant: true,
          statusText: 'Compliant',
          ruleReference: 'Rule 6(1)(e) & 6(11)',
          description: 'Unit Sale Price is correctly declared per kg.',
        ),
        ComplianceCheck(
          title: 'Principal Display Font Size',
          isCompliant: true,
          statusText: 'Compliant',
          ruleReference: 'Rule 9(1) Table-I',
          description: 'Numeral height exceeds minimum 4.0mm requirement for >1kg packages.',
        ),
      ],
    );
  }
}
