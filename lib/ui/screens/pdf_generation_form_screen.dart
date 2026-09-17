import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/inspection_report.dart';
import '../../data/services/mock_inspection_service.dart';
import '../../data/services/pdf_report_service.dart';
import '../widgets/legal_metrology_logo.dart';
import '../widgets/sticky_forensic_footer.dart';

/// Screen: Dedicated Statutory Memo & PDF Generation Form
/// Allows field officers to customize statutory notice types, officer designations,
/// directives, and hearing requirements, preview the live PDF, and generate/save the document.
class PdfGenerationFormScreen extends StatefulWidget {
  final InspectionReport report;

  const PdfGenerationFormScreen({
    super.key,
    required this.report,
  });

  @override
  State<PdfGenerationFormScreen> createState() => _PdfGenerationFormScreenState();
}

class _PdfGenerationFormScreenState extends State<PdfGenerationFormScreen> {
  final MockInspectionService _inspectionService = MockInspectionService();

  late TextEditingController _officerNameCtrl;
  late TextEditingController _designationCtrl;
  late TextEditingController _jurisdictionCtrl;
  late TextEditingController _businessNameCtrl;
  late TextEditingController _remarksCtrl;
  late TextEditingController _rectificationCtrl;

  String _selectedNoticeType = 'Form II: Inspection & Compliance Memo';
  final List<String> _noticeOptions = [
    'Form II: Inspection & Compliance Memo',
    'Form III: Notice of Statutory Violation (Rule 6/9 PCR)',
    'Form IV: Seizure Memo & Panchnama (Sec 15 LM Act)',
    'Certificate of Verified Compliance',
  ];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.report;
    _officerNameCtrl = TextEditingController(text: r.officerName);
    _designationCtrl = TextEditingController(text: 'Senior Inspector of Legal Metrology');
    _jurisdictionCtrl = TextEditingController(text: 'District Commercial Enforcement Zone');
    _businessNameCtrl = TextEditingController(text: r.businessName);

    // Initial default remarks based on violation status
    final violations = r.complianceChecks.where((c) => !c.isCompliant).toList();
    if (violations.isNotEmpty) {
      _selectedNoticeType = 'Form III: Notice of Statutory Violation (Rule 6/9 PCR)';
      _remarksCtrl = TextEditingController(
        text: 'Non-compliance detected in package declarations: '
            '${violations.map((v) => "${v.title} (${v.ruleReference})").join(", ")}. '
            'Trader/Manufacturer directed to explain discrepancy.',
      );
      _rectificationCtrl = TextEditingController(text: 'Rectify within 15 days or appear before District Controller.');
    } else {
      _selectedNoticeType = 'Form II: Inspection & Compliance Memo';
      _remarksCtrl = TextEditingController(
        text: 'All statutory declarations under PCR 2011 verified as compliant with Legal Metrology Standards.',
      );
      _rectificationCtrl = TextEditingController(text: 'Standard Routine Verification — Lot Cleared.');
    }
  }

  @override
  void dispose() {
    _officerNameCtrl.dispose();
    _designationCtrl.dispose();
    _jurisdictionCtrl.dispose();
    _businessNameCtrl.dispose();
    _remarksCtrl.dispose();
    _rectificationCtrl.dispose();
    super.dispose();
  }

  void _refreshPdfPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _savePdfToDevice() async {
    setState(() => _isSaving = true);
    try {
      final path = await PdfReportService.savePdfToFile(
        widget.report.copyWith(
          officerName: _officerNameCtrl.text,
          businessName: _businessNameCtrl.text,
        ),
        noticeTitle: _selectedNoticeType,
        customOfficerDesignation: _designationCtrl.text,
        customRemarks: _remarksCtrl.text,
        rectificationPeriod: _rectificationCtrl.text,
      );

      // Also attach to logs
      final updatedReport = widget.report.copyWith(
        officerName: _officerNameCtrl.text,
        businessName: _businessNameCtrl.text,
        pdfPath: path,
      );
      await _inspectionService.saveInspectionToLogs(updatedReport);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Statutory notice PDF generated & saved successfully ($path).',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryNavy,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: AppTheme.violationRed,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _printOrShare() async {
    await PdfReportService.printOrSharePdf(
      widget.report.copyWith(
        officerName: _officerNameCtrl.text,
        businessName: _businessNameCtrl.text,
      ),
      noticeTitle: _selectedNoticeType,
      customOfficerDesignation: _designationCtrl.text,
      customRemarks: _remarksCtrl.text,
      rectificationPeriod: _rectificationCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Generate Statutory PDF Memo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withAlpha(40),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.accentGold),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_rounded, color: AppTheme.accentGold, size: 14),
                const SizedBox(width: 4),
                Text(
                  widget.report.caseId,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Government Header Card
                _buildFormHeaderCard(),
                const SizedBox(height: 16),

                // Form Configuration Section
                _buildNoticeFormCard(),
                const SizedBox(height: 16),

                // Live PDF Preview Section
                _buildLivePdfPreviewCard(),
                const SizedBox(height: 20),

                // Bottom Action Buttons
                _buildActionButtons(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const StickyForensicFooter(),
    );
  }

  Widget _buildFormHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          LegalMetrologyLogo(size: 46, isBadge: true, borderWidth: 1.5),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GOVERNMENT OF INDIA',
                  style: TextStyle(
                    color: AppTheme.accentGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Statutory Memo & Notice Generator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Configure legal parameters before generating official PDF record',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeFormCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.neutralBorder, width: 2.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune_rounded, color: AppTheme.primaryNavy, size: 20),
                SizedBox(width: 8),
                Text(
                  'Statutory Form Particulars',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.borderLight),
            const SizedBox(height: 14),

            // Notice Type Dropdown
            const Text(
              'Statutory Notice / Document Type',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderLight),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedNoticeType,
                  isExpanded: true,
                  items: _noticeOptions.map((opt) {
                    return DropdownMenuItem(
                      value: opt,
                      child: Text(
                        opt,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedNoticeType = val);
                      _refreshPdfPreview();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Officer Name & Designation
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _officerNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Inspecting Officer',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (_) => _refreshPdfPreview(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _designationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Designation',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (_) => _refreshPdfPreview(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Establishment Name & Jurisdiction
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _businessNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Establishment / Trader',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (_) => _refreshPdfPreview(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _jurisdictionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Jurisdiction Zone',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (_) => _refreshPdfPreview(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Directives / Hearing Period
            TextField(
              controller: _rectificationCtrl,
              decoration: const InputDecoration(
                labelText: 'Compliance / Rectification Deadline',
                labelStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => _refreshPdfPreview(),
            ),
            const SizedBox(height: 14),

            // Form III Remarks / Directives (Auto-sizing with ScrollController)
            _buildFormIIRemarksSection(),
          ],
        ),
      ),
    );
  }

  /// Fixed Form III Remarks Section with proper ScrollController, auto-sizing scroll,
  /// character metrics, and quick-insert statutory templates. Prevents text clipping on all viewports.
  Widget _buildFormIIRemarksSection() {
    final text = _remarksCtrl.text;
    final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: AppTheme.primaryNavy, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Form III Statutory Remarks & Directives',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${text.length} chars • $wordCount words',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Quick Statutory Presets Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip(
                  'Rule 6 Non-Compliance',
                  'Violation under Rule 6 of PCR 2011: Mandatory product declarations omitted or obscured on package surface.',
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  'Rule 9 Font Deficiency',
                  'Violation under Rule 9(1) Table-I of PCR 2011: Net quantity numeral height is deficient and below statutory minimum.',
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  'Rule 18 MRP Tampering',
                  'Offence under Rule 18(2) of PCR 2011: Package displays altered or sticker-smudged MRP in violation of declared maximum retail price.',
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  'Fifth Schedule Shortage',
                  'Statutory Defect under Fifth Schedule: Measured net content deficiency exceeds Maximum Permissible Error (MPE).',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Auto-Expanding Multi-Line TextField (minLines: 3, maxLines: 6) with explicit #475569 border
          TextField(
            controller: _remarksCtrl,
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), height: 1.4, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Enter statutory findings, hearing dates, or seizure remarks under PCR 2011...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF475569), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0284C7), width: 2.0),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (_) {
              setState(() {});
              _refreshPdfPreview();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String templateText) {
    return InkWell(
      onTap: () {
        setState(() {
          if (_remarksCtrl.text.trim().isEmpty) {
            _remarksCtrl.text = templateText;
          } else {
            _remarksCtrl.text = '${_remarksCtrl.text.trim()}\n\n$templateText';
          }
        });
        _refreshPdfPreview();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF94A3B8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_outline_rounded, size: 11, color: AppTheme.primaryNavy),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePdfPreviewCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.neutralBorder, width: 2.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.visibility_rounded, color: AppTheme.primaryNavy, size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Live Document Preview',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _refreshPdfPreview,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppTheme.borderLight),
            const SizedBox(height: 14),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.neutralBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Document Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GOVERNMENT OF INDIA',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryNavy,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Text(
                              'LEGAL METROLOGY ENFORCEMENT DEPT',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                            ),
                            Text(
                              _selectedNoticeType,
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.accentGold, width: 1.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.report.caseId,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: AppTheme.borderLight),

                  // Metadata Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Officer: ${_officerNameCtrl.text}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Target: ${_businessNameCtrl.text}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Violations summary in preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.report.isViolation ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: widget.report.isViolation ? AppTheme.violationBorder : AppTheme.passBorder,
                        width: 2.0,
                      ),
                    ),
                    child: Text(
                      widget.report.isViolation
                          ? 'Statutory Violations Flagged: ${widget.report.complianceChecks.where((c) => !c.isCompliant).map((c) => c.title).join(", ")}'
                          : 'Statutory Verification: All Declarations Compliant (PCR 2011)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: widget.report.isViolation ? AppTheme.violationText : AppTheme.passGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Remarks preview
                  if (_remarksCtrl.text.isNotEmpty) ...[
                    Text(
                      'Directives: ${_remarksCtrl.text}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Document watermark / stamp
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Official Government Seal', style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.black38)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withAlpha(30),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('DIGITALLY CERTIFIED', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary: Save PDF to Device & Logs
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _savePdfToDevice,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(
              _isSaving ? 'Compiling & Saving PDF...' : 'Generate & Save PDF Document',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary: Print / Share PDF
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _printOrShare,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
            ),
            icon: const Icon(Icons.print_rounded, size: 20),
            label: const Text(
              'Print / Share Official Memo',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
