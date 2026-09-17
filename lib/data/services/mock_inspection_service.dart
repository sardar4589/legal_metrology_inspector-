import 'dart:typed_data';
import '../models/inspection_item.dart';
import '../models/inspection_report.dart';
import '../models/compliance_check.dart';
import '../models/product_details.dart';
import 'inspection_service_interface.dart';

/// Mock implementation of [InspectionServiceInterface].
///
/// Ready for backend integration:
/// To connect to your real REST API:
/// 1. Replace the mock delay with an `http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/analyze'))`
/// 2. Stream the image bytes or file to your ML model endpoint
/// 3. Parse JSON response into [InspectionReport.fromJson]
class MockInspectionService implements InspectionServiceInterface {
  // Singleton pattern for consistent in-memory state during the session
  static final MockInspectionService _instance = MockInspectionService._internal();
  factory MockInspectionService() => _instance;

  final List<InspectionItem> _recentInspections = [];

  MockInspectionService._internal() {
    _seedInitialMockData();
  }

  void _seedInitialMockData() {
    final oilReport = InspectionReport.mockOilViolation();
    final attaReport = InspectionReport.mockAttaCompliant();

    final saltReport = InspectionReport(
      caseId: 'LMD-2026-0910-028',
      officerName: 'Inspector R. Sharma',
      officerId: 'INSP-DL-4082',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      businessName: 'Nature Basket Store, Aisle 3',
      location: 'Ring Road, Sector 5',
      overallStatus: InspectionStatus.pass,
      statusSummary: 'COMPLIANT / PASS',
      sampleImageTag: 'himalayan_salt',
      statutoryCategory: 'Compliant Packages',
      productDetails: const ProductDetails(
        brandName: 'Puro Himalayan Pink Salt',
        declaredNetQuantity: '1 kg',
        declaredMrp: '₹120.00',
        unitSalePrice: '₹0.12 / g',
        batchMfgDate: 'H-91 / 07/2026',
        manufacturerAddress: 'Pure Salts India Ltd, Kutch, Gujarat',
        consumerCareDetails: 'support@purosalts.com | 1800-455-888',
      ),
      complianceChecks: const [
        ComplianceCheck(
          title: 'Mandatory Declarations',
          isCompliant: true,
          statusText: 'Found & Verified',
          ruleReference: 'Rule 6, PCR 2011',
          description: 'Net quantity, FSSAI lic no, manufacturer info verified.',
        ),
        ComplianceCheck(
          title: 'MRP & Unit Sale Price',
          isCompliant: true,
          statusText: 'Compliant',
          ruleReference: 'Rule 6(11)',
          description: 'Accurate unit pricing per gram displayed prominently.',
        ),
        ComplianceCheck(
          title: 'Principal Display Font Size',
          isCompliant: true,
          statusText: 'Compliant',
          ruleReference: 'Rule 9(1)',
          description: 'Font height 4.2mm meets minimum standard of 3.0mm.',
        ),
      ],
    );

    final waterReport = InspectionReport(
      caseId: 'LMD-2026-0910-019',
      officerName: 'Inspector R. Sharma',
      officerId: 'INSP-DL-4082',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      businessName: 'Highway Express Dhaba',
      location: 'NH-44 Toll Bypass',
      overallStatus: InspectionStatus.violation,
      statusSummary: 'VIOLATION DETECTED',
      sampleImageTag: 'packaged_water',
      statutoryCategory: 'MRP Violations (Rule 18)',
      productDetails: const ProductDetails(
        brandName: 'Aquasure Sparkling Water',
        declaredNetQuantity: '500 ml',
        declaredMrp: '₹35.00',
        unitSalePrice: '₹0.07 / ml',
        batchMfgDate: 'W-04 / 06/2026',
        manufacturerAddress: 'Aqua Beverage Bottlers, Sonepat',
        consumerCareDetails: 'care@aquasure.in',
      ),
      complianceChecks: const [
        ComplianceCheck(
          title: 'Dual MRP Tampering',
          isCompliant: false,
          statusText: 'Violation Detected',
          flaggedDetail: 'Original MRP ₹20 altered to ₹35 with sticker',
          ruleReference: 'Rule 18(2), PCR 2011',
          description: 'No person shall alter, obliterate or smudge the MRP originally declared.',
        ),
        ComplianceCheck(
          title: 'Unit Sale Price',
          isCompliant: true,
          statusText: 'Compliant',
          ruleReference: 'Rule 6(11)',
          description: 'Declared per ml as required.',
        ),
      ],
    );

    final teaReport = InspectionReport(
      caseId: 'LMD-2026-0909-012',
      officerName: 'Inspector R. Sharma',
      officerId: 'INSP-DL-4082',
      timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
      businessName: 'Royal Tea Traders & Packaging Unit',
      location: 'Industrial Area Phase I',
      overallStatus: InspectionStatus.violation,
      statusSummary: 'VIOLATION DETECTED',
      statutoryCategory: 'Weight Shortage (Fifth Schedule)',
      measuredNetWeight: 476.0,
      weightVariancePercent: -4.8,
      isWeightCompliant: false,
      mpeLimit: 15.0,
      productDetails: const ProductDetails(
        brandName: 'Assam Gold Premium CTC Tea',
        declaredNetQuantity: '500 g',
        declaredMrp: '₹220.00',
        unitSalePrice: '₹0.44 / g',
        batchMfgDate: 'T-88 / 05/2026',
        manufacturerAddress: 'Assam Gold Blenders Ltd, Guwahati',
        consumerCareDetails: 'care@assamgold.in',
      ),
      complianceChecks: const [
        ComplianceCheck(
          title: 'Net Weight Deficiency',
          isCompliant: false,
          statusText: 'Shortage Detected',
          flaggedDetail: 'Net weight 476.0g vs declared 500g (Deficiency -24.0g exceeds MPE of 15.0g)',
          ruleReference: 'Fifth Schedule, Rule 11 & 24',
          description: 'Net quantity deficiency exceeds Maximum Permissible Error (MPE) under Fifth Schedule.',
        ),
        ComplianceCheck(
          title: 'Mandatory Declarations',
          isCompliant: true,
          statusText: 'Compliant',
          ruleReference: 'Rule 6(1)',
          description: 'Packer, brand, batch and dates properly specified.',
        ),
      ],
    );

    _recentInspections.addAll([
      InspectionItem.fromReport(oilReport),
      InspectionItem.fromReport(attaReport),
      InspectionItem.fromReport(saltReport),
      InspectionItem.fromReport(waterReport),
      InspectionItem.fromReport(teaReport),
    ]);
  }

  @override
  Future<List<InspectionItem>> getRecentInspections() async {
    // Simulate brief local/network latency
    await Future.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_recentInspections);
  }

  @override
  Future<InspectionReport> analyzePackageLabel({
    String? imagePath,
    Uint8List? imageBytes,
    String? sampleTag,
  }) async {
    // Realistic AI inference latency (2 seconds) as requested
    await Future.delayed(const Duration(seconds: 2));

    // Return the detailed mock report matching the prompt specs
    return InspectionReport.mockOilViolation(
      imagePath: imagePath,
      imageBytes: imageBytes,
      sampleTag: sampleTag,
    );
  }

  @override
  Future<void> saveInspectionToLogs(InspectionReport report) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newItem = InspectionItem.fromReport(report);
    // Remove if already exists with same case ID
    _recentInspections.removeWhere((i) => i.id == newItem.id);
    // Add to top of recent inspections list
    _recentInspections.insert(0, newItem);
  }
}
