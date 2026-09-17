import 'dart:typed_data';
import 'inspection_report.dart';

/// Represents an inspection record displayed in the Case Logs register.
class InspectionItem {
  final String id;
  final String productName;
  final String businessName;
  final String formattedTime;
  final DateTime timestamp;
  final InspectionStatus status;
  final String? violationReason;
  final InspectionReport? fullReport;
  final String? imagePath;
  final Uint8List? imageBytes;
  final String? sampleImageTag;
  final String? pdfPath;
  final String category;

  const InspectionItem({
    required this.id,
    required this.productName,
    required this.businessName,
    required this.formattedTime,
    required this.timestamp,
    required this.status,
    this.violationReason,
    this.fullReport,
    this.imagePath,
    this.imageBytes,
    this.sampleImageTag,
    this.pdfPath,
    this.category = 'Compliant Packages',
  });

  bool get isViolation => status == InspectionStatus.violation;
  bool get isPass => status == InspectionStatus.pass;

  factory InspectionItem.fromReport(InspectionReport report) {
    final now = DateTime.now();
    final isToday = report.timestamp.year == now.year &&
        report.timestamp.month == now.month &&
        report.timestamp.day == now.day;

    final hour = report.timestamp.hour > 12
        ? report.timestamp.hour - 12
        : (report.timestamp.hour == 0 ? 12 : report.timestamp.hour);
    final period = report.timestamp.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = report.timestamp.minute.toString().padLeft(2, '0');

    final timeStr = isToday
        ? 'Today, $hour:$minuteStr $period'
        : '${report.timestamp.day}/${report.timestamp.month}, $hour:$minuteStr $period';

    String? reason;
    if (report.isViolation) {
      final flagged = report.complianceChecks.where((c) => !c.isCompliant);
      if (flagged.isNotEmpty) {
        reason = flagged.first.flaggedDetail ?? flagged.first.title;
      }
    }

    final derivedCategory = report.statutoryCategory.isNotEmpty && report.statutoryCategory != 'Compliant Packages'
        ? report.statutoryCategory
        : InspectionReport.deriveCategory(
            status: report.overallStatus,
            checks: report.complianceChecks,
            isWeightCompliant: report.isWeightCompliant,
          );

    return InspectionItem(
      id: report.caseId,
      productName: report.productDetails.brandName,
      businessName: report.businessName,
      formattedTime: timeStr,
      timestamp: report.timestamp,
      status: report.overallStatus,
      violationReason: reason,
      fullReport: report,
      imagePath: report.imagePath,
      imageBytes: report.imageBytes,
      sampleImageTag: report.sampleImageTag,
      pdfPath: report.pdfPath,
      category: derivedCategory,
    );
  }
}
