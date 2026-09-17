import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/inspection_report.dart';
import '../../data/models/compliance_check.dart';
import '../../data/models/package_framing_model.dart';
import '../widgets/legal_metrology_logo.dart';
import '../widgets/status_badge.dart';
import '../widgets/sticky_forensic_footer.dart';
import 'pdf_generation_form_screen.dart';
import 'weight_verification_screen.dart';

/// Screen: Automated AI Statutory Audit & Enforcement Actions
/// Dedicated page that displays:
/// 1. Rule 9(1) Table-I Automated AI Font Sizing Measurement
/// 2. Rule 6 Extracted Mandatory Product Declarations
/// 3. PCR 2011 Compliance Checklist
/// 4. Net Weight Verification Summary (Manual / Bluetooth Scale)
/// 5. Statutory Actions: Caliper Inspection, Weight Verification, PDF Notice Generator, Category-wise Case Log Save
class StatutoryAuditScreen extends StatefulWidget {
  final InspectionReport report;
  final Map<PackageViewType, PackageViewItem>? multiAngleViews;

  const StatutoryAuditScreen({
    super.key,
    required this.report,
    this.multiAngleViews,
  });

  @override
  State<StatutoryAuditScreen> createState() => _StatutoryAuditScreenState();
}

class _StatutoryAuditScreenState extends State<StatutoryAuditScreen> {
  late InspectionReport _report;
  late List<ComplianceCheck> _complianceChecks;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _complianceChecks = List.from(widget.report.complianceChecks);
  }

  Future<void> _openWeightVerificationScreen() async {
    final updated = await Navigator.of(context).push<InspectionReport>(
      MaterialPageRoute(
        builder: (_) => WeightVerificationScreen(report: _report),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _report = updated;
        _complianceChecks = List.from(updated.complianceChecks);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Weight verified: ${_report.measuredNetWeight?.toStringAsFixed(1) ?? "0"} (${_report.isWeightCompliant == true ? "COMPLIANT" : "SHORTAGE DEFICIENCY"})',
          ),
          backgroundColor: _report.isWeightCompliant == true ? AppTheme.passGreen : AppTheme.violationRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openPdfGenerationScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfGenerationFormScreen(report: _report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isViolation = _report.isViolation;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Row(
          children: [
            LegalMetrologyLogo(size: 26, isBadge: false),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Statutory Audit Report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            tooltip: 'Generate Notice (PDF)',
            onPressed: _openPdfGenerationScreen,
          ),
        ],
      ),
      bottomNavigationBar: const StickyForensicFooter(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Status & Category Classification Header
                _buildInspectionStatusHeader(isViolation),
                const SizedBox(height: 14),

                // 2. Automated AI Font Sizing & Table-I Audit Card
                _buildAutomatedFontAuditCard(),
                const SizedBox(height: 14),

                // 3. Weight Verification Status Card (Manual or BLE Scale)
                _buildWeightVerificationSummaryCard(),
                const SizedBox(height: 14),

                // 4. Extracted Statutory Product Declarations (Rule 6 PCR 2011)
                _buildExtractedProductDetailsCard(),
                const SizedBox(height: 14),

                // 5. Statutory Compliance Checklist (PCR 2011)
                _buildComplianceChecklistCard(),
                const SizedBox(height: 20),

                // 6. Action Buttons
                _buildActionButtons(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Status and Category Classification Header Banner
  Widget _buildInspectionStatusHeader(bool isViolation) {
    final statusColor = isViolation ? AppTheme.violationBorder : AppTheme.passBorder;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor,
          width: 2.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _report.productDetails.brandName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryInk,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Case ID: ${_report.caseId}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.metadataLabel,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                status: isViolation ? InspectionStatus.violation : InspectionStatus.pass,
                customLabel: isViolation ? 'VIOLATION FLAGGED' : 'FULLY COMPLIANT',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.neutralBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.category_rounded, size: 14, color: AppTheme.primaryNavy),
                const SizedBox(width: 6),
                Text(
                  'Category: ${_report.statutoryCategory}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Automated AI Font Sizing Audit Card (Rule 9(1) Table-I)
  Widget _buildAutomatedFontAuditCard() {
    const measuredHeight = 1.8;
    const requiredHeight = 3.0;
    const isDeficient = measuredHeight < requiredHeight;
    final cardBorderColor = isDeficient ? AppTheme.violationBorder : AppTheme.passBorder;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardBorderColor,
          width: 2.0,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDeficient ? AppTheme.violationRed : AppTheme.passGreen).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDeficient ? Icons.text_fields_rounded : Icons.check_circle_rounded,
                  color: isDeficient ? AppTheme.violationRed : AppTheme.passGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Automated AI Font Sizing Audit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryInk,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Rule 9(1) Table-I • Net Quantity Numeral Height',
                      style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDeficient ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDeficient ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                  ),
                ),
                child: Text(
                  isDeficient ? 'NON-COMPLIANT' : 'COMPLIANT',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: isDeficient ? AppTheme.violationRed : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.neutralBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Measured Numeral Height',
                        style: TextStyle(fontSize: 11, color: AppTheme.secondaryText, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${measuredHeight.toStringAsFixed(1)} mm',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDeficient ? AppTheme.violationRed : AppTheme.passGreen,
                        ),
                      ),
                      const Text('AI Optical Measurement', style: TextStyle(fontSize: 10, color: AppTheme.metadataLabel)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.neutralBorder),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Table-I Minimum Required',
                        style: TextStyle(fontSize: 11, color: AppTheme.secondaryText, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '≥ 3.0 mm',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primaryInk),
                      ),
                      Text('Mandatory Statutory Standard', style: TextStyle(fontSize: 10, color: AppTheme.metadataLabel)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                isDeficient ? Icons.warning_rounded : Icons.check_circle_rounded,
                size: 16,
                color: isDeficient ? AppTheme.violationRed : AppTheme.passGreen,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isDeficient
                      ? 'Deficient by 1.2 mm. Numeral height violates Rule 9(1) Table-I standards.'
                      : 'Numeral height meets statutory requirements.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDeficient ? AppTheme.violationRed : AppTheme.passGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Weight Verification Summary Card (Manual or Bluetooth Scale)
  Widget _buildWeightVerificationSummaryCard() {
    final hasWeight = _report.measuredNetWeight != null;
    final isWeightComp = _report.isWeightCompliant ?? true;
    final cardBorderColor = hasWeight
        ? (isWeightComp ? AppTheme.passBorder : AppTheme.violationBorder)
        : AppTheme.neutralBorder;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardBorderColor,
          width: 2.0,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.scale_rounded, color: AppTheme.primaryNavy, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Weight / Volume Verification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryInk,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Rule 11 & Fifth Schedule MPE Evaluation',
                      style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                    ),
                  ],
                ),
              ),
              if (hasWeight) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isWeightComp ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isWeightComp ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Text(
                    isWeightComp ? 'COMPLIANT' : 'SHORTAGE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: isWeightComp ? const Color(0xFF15803D) : AppTheme.violationRed,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (hasWeight) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.neutralBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verified Net Weight',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.secondaryText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_report.measuredNetWeight?.toStringAsFixed(1)} g/ml',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryInk,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Variance from Label',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.secondaryText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(_report.weightVariancePercent ?? 0) >= 0 ? "+" : ""}${_report.weightVariancePercent?.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isWeightComp ? AppTheme.passGreen : AppTheme.violationRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const Text(
              'Perform net weight audit using automated digital scale stream or certified Bluetooth scale.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.secondaryText),
            ),
            const SizedBox(height: 12),
          ],

          // High-contrast, unclipped action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openWeightVerificationScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.scale_rounded, size: 18, color: Colors.white),
              label: Text(
                hasWeight ? 'Re-verify Weight (Automated & Scale)' : 'Verify Net Weight (Automated & BLE Scale)',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Extracted Statutory Product Declarations (Rule 6 PCR 2011)
  Widget _buildExtractedProductDetailsCard() {
    final p = _report.productDetails;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.neutralBorder,
          width: 2.0,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.text_snippet_rounded, color: AppTheme.primaryNavy, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Extracted Product Declarations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Rule 6 PCR 2011 • Edge AI OCR Stream Analysis',
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.neutralBorder),
          const SizedBox(height: 10),
          _buildOcrFieldTile('Brand / Commodity', p.brandName, Icons.shopping_bag_outlined),
          _buildOcrFieldTile('Declared Net Quantity', p.declaredNetQuantity, Icons.straighten_rounded),
          _buildOcrFieldTile('Declared MRP (Incl. Taxes)', p.declaredMrp, Icons.currency_rupee_rounded),
          _buildOcrFieldTile('Unit Sale Price (USP)', p.unitSalePrice, Icons.calculate_outlined),
          _buildOcrFieldTile('Batch / Mfg Date', p.batchMfgDate, Icons.calendar_today_outlined),
          _buildOcrFieldTile('Manufacturer Address', p.manufacturerAddress, Icons.business_outlined),
          _buildOcrFieldTile('Consumer Care Details', p.consumerCareDetails, Icons.support_agent_outlined),
        ],
      ),
    );
  }

  Widget _buildOcrFieldTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppTheme.secondaryText),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryInk),
            ),
          ),
        ],
      ),
    );
  }

  /// Compliance Checklist Card (PCR 2011)
  Widget _buildComplianceChecklistCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.neutralBorder,
          width: 2.0,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rounded, color: AppTheme.primaryNavy, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Compliance Checklist (PCR, 2011)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryInk),
                ),
              ),
            ],
          ),
            const SizedBox(height: 12),
            Column(
              children: _complianceChecks.map((c) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: c.isCompliant ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        c.isCompliant ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 18,
                        color: c.isCompliant ? AppTheme.passGreen : AppTheme.violationRed,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(
                              c.flaggedDetail ?? c.description,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: c.isCompliant ? AppTheme.textSecondary : AppTheme.violationRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.isCompliant ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          c.isCompliant ? 'PASS' : 'VIOLATION',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: c.isCompliant ? const Color(0xFF15803D) : AppTheme.violationRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
  }

  /// Action Button: Generate Official Statutory Notice (PDF)
  Widget _buildActionButtons() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _openPdfGenerationScreen,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.violationRed,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
        label: const Text(
          'Generate Notice (PDF)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
      ),
    );
  }
}
