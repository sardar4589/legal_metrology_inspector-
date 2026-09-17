import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/inspection_report.dart';
import '../../data/models/compliance_check.dart';
import '../../data/models/font_caliper_models.dart';
import '../../data/services/mock_inspection_service.dart';
import '../../data/services/pdf_report_service.dart';
import '../widgets/legal_metrology_logo.dart';
import '../widgets/status_badge.dart';
import '../widgets/package_canvas_widget.dart';
import '../widgets/ar_pdp_overlay.dart';
import '../widgets/font_caliper_widget.dart';
import '../widgets/edge_ai_status_hud.dart';
import '../../data/services/automated_vision_service.dart';
import 'pdf_generation_form_screen.dart';
import '../../data/models/package_framing_model.dart';
import 'weight_verification_screen.dart';
import '../widgets/sticky_forensic_footer.dart';

/// Screen 4: Unified Inspection & Text Extraction Screen
/// All-in-one scan result screen combining:
/// 1. AR Viewfinder & PDP bounding overlay (Rule 24)
/// 2. Interactive Optical Font Caliper (Rule 9(1) Table-I)
/// 3. Extracted product text declarations (Brand, Net Qty, MRP, USP, Mfg Date, Address)
/// 4. Line-by-line Raw OCR text stream
/// 5. Statutory compliance checklist & Form II PDF export
class ReportScreen extends StatefulWidget {
  final InspectionReport report;
  final bool isSavedRecord;
  final Map<PackageViewType, PackageViewItem>? multiAngleViews;

  const ReportScreen({
    super.key,
    required this.report,
    this.isSavedRecord = false,
    this.multiAngleViews,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _service = MockInspectionService();
  bool _isSaving = false;
  late List<ComplianceCheck> _complianceChecks;
  late PdpDimensions _pdpDimensions;
  late FontCaliperMeasurement _caliperMeasurement;
  final EdgeAiState _aiState = EdgeAiState.completed;
  double _currentNetQtyGrams = 1000.0;

  // Multi-Angle Image Slider / Carousel State (User Requirement)
  late Map<PackageViewType, PackageViewItem> _views;
  PackageViewType _activeView = PackageViewType.front;

  @override
  void initState() {
    super.initState();
    _complianceChecks = List.from(widget.report.complianceChecks);
    _initMultiAngleViews();
    _setupInitialCaliperAndPdp();
  }

  void _initMultiAngleViews() {
    if (widget.multiAngleViews != null && widget.multiAngleViews!.isNotEmpty) {
      _views = Map.from(widget.multiAngleViews!);
    } else {
      _views = {
        for (final v in PackageViewType.values)
          v: PackageViewItem(
            viewType: v,
            imagePath: widget.report.imagePath,
            imageBytes: widget.report.imageBytes,
            isCaptured: true,
            framingReport: FramingQualityReport.evaluate(sampleTag: widget.report.sampleImageTag, viewType: v),
            accuracyPercent: v == PackageViewType.front ? 96 : (v == PackageViewType.back ? 94 : (v == PackageViewType.side ? 92 : 95)),
            isProper: true,
            evaluationNotes: 'Optimal statutory contrast & edge boundary',
          ),
      };
    }
  }

  void _slideNextAngle() {
    final values = PackageViewType.values;
    final idx = values.indexOf(_activeView);
    setState(() {
      _activeView = values[(idx + 1) % values.length];
    });
  }

  void _slidePrevAngle() {
    final values = PackageViewType.values;
    final idx = values.indexOf(_activeView);
    setState(() {
      _activeView = values[(idx - 1 + values.length) % values.length];
    });
  }

  Future<void> _openWeightVerification() async {
    final updated = await Navigator.of(context).push<InspectionReport>(
      MaterialPageRoute(
        builder: (_) => WeightVerificationScreen(
          report: widget.report.copyWith(complianceChecks: _complianceChecks),
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _complianceChecks = List.from(updated.complianceChecks);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Weight verified: ${updated.measuredNetWeight?.toStringAsFixed(1)} g (${updated.isWeightCompliant == true ? "COMPLIANT" : "SHORTAGE"})',
          ),
          backgroundColor: updated.isWeightCompliant == true ? AppTheme.passGreen : AppTheme.violationRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _setupInitialCaliperAndPdp() {
    final tag = widget.report.sampleImageTag;
    if (tag == 'sharbati_atta') {
      _currentNetQtyGrams = 5000.0;
      _pdpDimensions = PdpDimensions.calculate(
        widthCm: 22.0,
        heightCm: 28.0,
        shape: PdpShape.rectangular,
        netQuantityGrams: 5000.0,
      );
      _caliperMeasurement = const FontCaliperMeasurement(
        measuredHeightMm: 4.8,
        requiredHeightMm: 4.0,
        targetField: 'Net Quantity numeral "5 kg"',
        ocrConfidence: 0.94,
        ruleReference: 'Rule 9(1) Table-I, PCR 2011',
      );
    } else if (tag == 'himalayan_salt') {
      _currentNetQtyGrams = 1000.0;
      _pdpDimensions = PdpDimensions.calculate(
        widthCm: 12.0,
        heightCm: 16.0,
        shape: PdpShape.cylindrical,
        netQuantityGrams: 1000.0,
      );
      _caliperMeasurement = const FontCaliperMeasurement(
        measuredHeightMm: 3.4,
        requiredHeightMm: 3.0,
        targetField: 'Net Quantity numeral "1 kg"',
        ocrConfidence: 0.91,
        ruleReference: 'Rule 9(1) Table-I, PCR 2011',
      );
    } else {
      // GoodLife Oil or custom captured package
      _currentNetQtyGrams = 1000.0;
      _pdpDimensions = PdpDimensions.calculate(
        widthCm: 10.0,
        heightCm: 18.0,
        shape: PdpShape.rectangular,
        netQuantityGrams: 1000.0,
      );
      _caliperMeasurement = const FontCaliperMeasurement(
        measuredHeightMm: 1.8,
        requiredHeightMm: 3.0,
        targetField: 'Net Quantity numeral "1 L"',
        ocrConfidence: 0.88,
        ruleReference: 'Rule 9(1) Table-I, PCR 2011',
      );
    }
  }

  void _updateCaliperMeasurement(double newHeight) {
    setState(() {
      _caliperMeasurement = _caliperMeasurement.copyWith(measuredHeightMm: newHeight);
      _syncComplianceChecks();
    });
  }

  void _updateCaliperRequiredHeight(double newReq) {
    setState(() {
      _caliperMeasurement = _caliperMeasurement.copyWith(requiredHeightMm: newReq);
      _syncComplianceChecks();
    });
  }

  void _syncComplianceChecks() {
    final isCompliant = _caliperMeasurement.isCompliant;
    final index = _complianceChecks.indexWhere((c) => c.title.contains('Font Size'));
    if (index != -1) {
      final old = _complianceChecks[index];
      _complianceChecks[index] = ComplianceCheck(
        title: old.title,
        isCompliant: isCompliant,
        statusText: isCompliant ? 'Compliant' : 'Non-compliant',
        flaggedDetail: isCompliant
            ? null
            : 'Found ${_caliperMeasurement.measuredHeightMm.toStringAsFixed(1)}mm, Required ${_caliperMeasurement.requiredHeightMm.toStringAsFixed(1)}mm',
        ruleReference: old.ruleReference,
        description: isCompliant
            ? 'Font height ${_caliperMeasurement.measuredHeightMm.toStringAsFixed(1)}mm satisfies Table-I minimum standard.'
            : 'Numeral height for net quantity must not be less than ${_caliperMeasurement.requiredHeightMm.toStringAsFixed(1)}mm under Rule 9(1) Table-I.',
      );
    }
  }

  void _togglePdpShape() {
    setState(() {
      final nextShape = _pdpDimensions.shape == PdpShape.rectangular
          ? PdpShape.cylindrical
          : (_pdpDimensions.shape == PdpShape.cylindrical ? PdpShape.irregular : PdpShape.rectangular);
      _pdpDimensions = PdpDimensions.calculate(
        widthCm: _pdpDimensions.widthCm,
        heightCm: _pdpDimensions.heightCm,
        shape: nextShape,
        netQuantityGrams: _currentNetQtyGrams,
      );
      _caliperMeasurement = _caliperMeasurement.copyWith(
        requiredHeightMm: _pdpDimensions.minimumRequiredFontMm,
      );
      _syncComplianceChecks();
    });
  }

  void _openPdpDimensionsDialog() {
    final widthCtrl = TextEditingController(text: _pdpDimensions.widthCm.toStringAsFixed(1));
    final heightCtrl = TextEditingController(text: _pdpDimensions.heightCm.toStringAsFixed(1));
    final qtyCtrl = TextEditingController(text: _currentNetQtyGrams.toStringAsFixed(0));
    PdpShape selectedShape = _pdpDimensions.shape;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final w = double.tryParse(widthCtrl.text) ?? 10.0;
          final h = double.tryParse(heightCtrl.text) ?? 18.0;
          final q = double.tryParse(qtyCtrl.text) ?? 1000.0;
          final previewPdp = PdpDimensions.calculate(
            widthCm: w,
            heightCm: h,
            shape: selectedShape,
            netQuantityGrams: q,
          );

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.straighten_rounded, color: AppTheme.primaryNavy),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Package PDP & Font Specifications',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statutory dimensions under Rule 24 & Rule 9(1) Table-I:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widthCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Width (cm)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: heightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Height (cm)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Net Quantity (g or ml)',
                      hintText: 'e.g. 1000 for 1kg/L',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 14),
                  const Text('Package Shape (Rule 24):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: PdpShape.values.map((s) {
                      final isSelected = s == selectedShape;
                      return ChoiceChip(
                        label: Text(s.label, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : AppTheme.textPrimary)),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryNavy,
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedShape = s);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Computed PDP Area:', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                            Text('${previewPdp.areaCm2} cm²', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Table-I Min Font Height:', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                            Text('≥ ${previewPdp.minimumRequiredFontMm.toStringAsFixed(1)} mm', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                onPressed: () {
                  final w = double.tryParse(widthCtrl.text) ?? _pdpDimensions.widthCm;
                  final h = double.tryParse(heightCtrl.text) ?? _pdpDimensions.heightCm;
                  final q = double.tryParse(qtyCtrl.text) ?? _currentNetQtyGrams;
                  setState(() {
                    _currentNetQtyGrams = q;
                    _pdpDimensions = PdpDimensions.calculate(
                      widthCm: w,
                      heightCm: h,
                      shape: selectedShape,
                      netQuantityGrams: q,
                    );
                    _caliperMeasurement = _caliperMeasurement.copyWith(
                      requiredHeightMm: _pdpDimensions.minimumRequiredFontMm,
                      targetField: 'Net Quantity (${q.toStringAsFixed(0)} g/ml)',
                    );
                    _syncComplianceChecks();
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Apply Specifications'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleSaveToLogs() async {
    setState(() => _isSaving = true);
    String savedPdfPath = '';
    final isViolation = _complianceChecks.any((c) => !c.isCompliant);
    final updatedReport = widget.report.copyWith(
      complianceChecks: _complianceChecks,
      overallStatus: isViolation ? InspectionStatus.violation : InspectionStatus.pass,
      statusSummary: isViolation ? 'VIOLATION DETECTED' : 'COMPLIANT / PASS',
    );

    try {
      // 1. Generate and save the official PDF file to device storage
      savedPdfPath = await PdfReportService.savePdfToFile(updatedReport);
    } catch (_) {}

    // 2. Save the inspection report with PDF path attached into case logs
    final finalReport = updatedReport.copyWith(pdfPath: savedPdfPath);
    await _service.saveInspectionToLogs(finalReport);
    if (!mounted) return;

    // 3. Show high-contrast confirmation SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Case #${widget.report.caseId} saved to Case Logs in PDF form.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );

    // Navigate back to Home with true to indicate record was saved
    Navigator.of(context).pop(true);
  }

  void _openPdfGenerationForm() {
    final isViolation = _complianceChecks.any((c) => !c.isCompliant);
    final currentReport = widget.report.copyWith(
      complianceChecks: _complianceChecks,
      overallStatus: isViolation ? InspectionStatus.violation : InspectionStatus.pass,
      statusSummary: isViolation ? 'VIOLATION DETECTED' : 'COMPLIANT / PASS',
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfGenerationFormScreen(report: currentReport),
      ),
    );
  }

  void _handlePrintSharePdf() {
    _openPdfGenerationForm();
  }

  Future<void> _runAutoInspection() async {
    final result = await AutomatedVisionService.autoInspectImage(
      imagePath: widget.report.imagePath,
      imageBytes: widget.report.imageBytes,
      sampleTag: widget.report.sampleImageTag,
    );
    setState(() {
      _pdpDimensions = result.pdpDimensions;
      _caliperMeasurement = result.caliperMeasurement;
      _syncComplianceChecks();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Automated AR Inspection: ${result.detectionSummary}'),
          backgroundColor: AppTheme.primaryNavy,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showImageZoomDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(8),
              child: PackageCanvasWidget(
                imagePath: widget.report.imagePath,
                imageBytes: widget.report.imageBytes,
                sampleTag: widget.report.sampleImageTag,
                height: 480,
                showBoundingBoxes: false,
              ),
            ),
            IconButton(
              padding: const EdgeInsets.all(16),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final isViolation = _complianceChecks.any((c) => !c.isCompliant);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Row(
          children: [
            LegalMetrologyLogo(size: 26, isBadge: false),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Inspection Memo',
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
            tooltip: 'Generate Statutory PDF Notice',
            onPressed: _openPdfGenerationForm,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Colors.white),
            tooltip: 'Print Memo',
            onPressed: _handlePrintSharePdf,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Status Banner at Top (High-contrast red or green)
                StatusBadge(
                  status: isViolation ? InspectionStatus.violation : InspectionStatus.pass,
                  isLargeBanner: true,
                  customLabel: isViolation ? 'VIOLATION DETECTED' : 'COMPLIANT / PASS',
                ),
                const SizedBox(height: 16),

                // 2. Summary Card: Case ID, Timestamp, Officer Name, Thumbnail
                _buildSummaryCard(report),
                const SizedBox(height: 16),

                // 3. Integrated AR Viewfinder & Font Caliper Inspection Section
                _buildVisualArCaliperCard(),
                const SizedBox(height: 16),

                // 4. Extracted Product Details (Structured OCR Fields)
                _buildExtractedDetailsCard(report),
                const SizedBox(height: 16),

                // 5. Raw OCR Text Stream (Complete line-by-line inspection)
                _buildRawOcrStreamCard(report),
                const SizedBox(height: 16),

                // 6. Compliance Checklist Card (PCR 2011) - Linked live to Caliper
                _buildComplianceChecklistCard(report),
                const SizedBox(height: 24),

                // 7. Action Buttons at Bottom (Save to Logs, Print/Share PDF)
                _buildBottomActionButtons(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const StickyForensicFooter(),
    );
  }

  /// AR Viewfinder & Integrated Font Caliper Card
  Widget _buildVisualArCaliperCard() {
    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF0C2340),
            child: Row(
              children: [
                const Icon(Icons.straighten_rounded, color: AppTheme.accentGold, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AR Visual Inspection & Font Caliper',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Rule 24 (PDP Area) & Rule 9(1) Table-I (Font Height)',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 20),
                  tooltip: 'Edit Package PDP Specifications',
                  onPressed: _openPdpDimensionsDialog,
                ),
              ],
            ),
          ),

          // Automated Vision AI Detection Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.accentGold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AUTOMATED AR VISION INSPECTION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentGold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Auto-detected PDP: ${_pdpDimensions.areaCm2.toStringAsFixed(1)} cm² | Numeral Font: ${_caliperMeasurement.measuredHeightMm.toStringAsFixed(1)} mm (${_caliperMeasurement.isCompliant ? "COMPLIANT" : "DEFICIENT"})',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _runAutoInspection,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Re-analyze',
                    style: TextStyle(color: AppTheme.accentGold, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Multi-Angle Image Slider Bar (Slide between Front, Back, Side, Flap)
          _buildAngleSliderStrip(),

          // AR Package Image with PDP Overlay (supports swipe to slide images)
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -200) {
                  _slideNextAngle();
                } else if (details.primaryVelocity! > 200) {
                  _slidePrevAngle();
                }
              }
            },
            child: SizedBox(
              height: 320,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PackageCanvasWidget(
                      imagePath: _views[_activeView]?.imagePath ?? widget.report.imagePath,
                      imageBytes: _views[_activeView]?.imageBytes ?? widget.report.imageBytes,
                      sampleTag: widget.report.sampleImageTag,
                      height: 320,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: ArPdpOverlay(
                      dimensions: _pdpDimensions,
                      isAligned: true,
                      onToggleShape: _togglePdpShape,
                      onEditDimensions: _openPdpDimensionsDialog,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Edge AI Status HUD
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: EdgeAiStatusHud(
              state: _aiState,
              confidence: _caliperMeasurement.ocrConfidence,
              onManualVerifyPressed: _openPdpDimensionsDialog,
            ),
          ),

          // Integrated Visual Font Caliper Widget
          FontCaliperWidget(
            measurement: _caliperMeasurement,
            onMeasurementChanged: _updateCaliperMeasurement,
            onRequiredHeightChanged: _updateCaliperRequiredHeight,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// Raw OCR Text Stream Recognized on Package
  Widget _buildRawOcrStreamCard(InspectionReport report) {
    final d = report.productDetails;
    final ocrLines = [
      {'line': 1, 'text': d.brandName.toUpperCase(), 'conf': 98},
      {'line': 2, 'text': 'NET QUANTITY : ${d.declaredNetQuantity}', 'conf': 96},
      {'line': 3, 'text': 'MRP ${d.declaredMrp} (INCL. OF ALL TAXES)', 'conf': 94},
      {'line': 4, 'text': 'UNIT SALE PRICE : ${d.unitSalePrice}', 'conf': 95},
      {'line': 5, 'text': 'BATCH / MFG : ${d.batchMfgDate}', 'conf': 92},
      {'line': 6, 'text': 'PACKER / MFR : ${d.manufacturerAddress}', 'conf': 91},
      {'line': 7, 'text': 'CONSUMER CARE : ${d.consumerCareDetails}', 'conf': 97},
      {'line': 8, 'text': 'COUNTRY OF ORIGIN : ${d.countryOfOrigin.toUpperCase()}', 'conf': 99},
      {'line': 9, 'text': 'FSSAI LIC NO. 10018021003452', 'conf': 90},
    ];

    return Card(
      elevation: 1,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: const Icon(Icons.document_scanner_rounded, color: AppTheme.primaryNavy, size: 22),
        title: const Text(
          'Raw OCR Text Recognized on Package',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        subtitle: const Text(
          'Complete line-by-line optical character recognition stream',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        children: [
          const Divider(height: 1, color: AppTheme.borderLight),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: ocrLines.map((item) {
                final lineNo = item['line'];
                final text = item['text'];
                final conf = item['conf'];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          'L$lineNo',
                          style: const TextStyle(fontSize: 9.5, color: AppTheme.accentGold, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$text',
                          style: const TextStyle(fontSize: 11.5, color: Colors.white, fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$conf%',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF4ADE80), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Summary Card: Case ID, Timestamp, Officer Name + Image Thumbnail
  Widget _buildSummaryCard(InspectionReport report) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Case Metadata',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    report.caseId,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryNavy,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.borderLight),
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Column
                Expanded(
                  child: Column(
                    children: [
                      _buildMetaRow(Icons.person_pin_rounded, 'Officer', report.officerName),
                      const SizedBox(height: 10),
                      _buildMetaRow(
                        Icons.calendar_today_rounded,
                        'Date & Time',
                        '${report.timestamp.day.toString().padLeft(2, '0')}/${report.timestamp.month.toString().padLeft(2, '0')}/${report.timestamp.year}  ${report.timestamp.hour.toString().padLeft(2, '0')}:${report.timestamp.minute.toString().padLeft(2, '0')}',
                      ),
                      const SizedBox(height: 10),
                      _buildMetaRow(Icons.storefront_rounded, 'Establishment', report.businessName),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Captured Image Thumbnail
                GestureDetector(
                  onTap: _showImageZoomDialog,
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderLight, width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            PackageCanvasWidget(
                              imagePath: report.imagePath,
                              imageBytes: report.imageBytes,
                              sampleTag: report.sampleImageTag,
                              height: 80,
                              showBoundingBoxes: false,
                            ),
                            Container(
                              color: Colors.black.withAlpha(40),
                              child: const Center(
                                child: Icon(Icons.zoom_in_rounded, color: Colors.white, size: 24),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to zoom',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Extracted Product Details (mocked)
  Widget _buildExtractedDetailsCard(InspectionReport report) {
    final d = report.productDetails;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_rounded, color: AppTheme.primaryNavy, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Extracted Product Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.borderLight),
            const SizedBox(height: 12),

            _buildDetailRow('Brand / Commodity', d.brandName, isBold: true),
            _buildDetailRow('Declared Net Quantity', d.declaredNetQuantity, isHighlight: true),
            _buildDetailRow('Declared MRP', '${d.declaredMrp} (Incl. of all taxes)'),
            _buildDetailRow('Unit Sale Price (USP)', d.unitSalePrice, isHighlight: true),
            _buildDetailRow('Batch / Mfg Date', d.batchMfgDate),
            _buildDetailRow('Manufacturer / Packer', d.manufacturerAddress),
            _buildDetailRow('Consumer Care Redressal', d.consumerCareDetails),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isHighlight ? AppTheme.primaryNavy : AppTheme.textPrimary,
                fontWeight: (isBold || isHighlight) ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compliance Checklist Card
  Widget _buildComplianceChecklistCard(InspectionReport report) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.rule_folder_rounded, color: AppTheme.primaryNavy, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Compliance Checklist (PCR, 2011)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.borderLight),
            const SizedBox(height: 10),

            ..._complianceChecks.map((check) => _buildCheckItem(check)),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(ComplianceCheck check) {
    final isPass = check.isCompliant;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPass ? AppTheme.passBackground.withAlpha(90) : AppTheme.violationBackground.withAlpha(90),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPass ? AppTheme.passGreen.withAlpha(60) : AppTheme.violationRed.withAlpha(80),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPass ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isPass ? AppTheme.passGreen : AppTheme.violationRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  check.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPass ? AppTheme.passGreen : AppTheme.violationRed,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  check.statusText.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          // Flagged Detail if any (e.g. Found 1.8mm, Required 3.0mm)
          if (check.flaggedDetail != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.violationRed.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.violationRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Flagged: ${check.flaggedDetail}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.violationText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (check.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              check.description,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.3,
              ),
            ),
          ],

          const SizedBox(height: 4),
          Text(
            'Reference: ${check.ruleReference}',
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Action Buttons at Bottom: "Save to Logs" & "Print / Share PDF"
  /// Multi-Angle Image Slider Strip (Slide between Front PDP, Back, Side, Flap)
  Widget _buildAngleSliderStrip() {
    final values = PackageViewType.values;
    final currentItem = _views[_activeView];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 14, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Previous Angle',
                onPressed: _slidePrevAngle,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: values.map((v) {
                      final isSelected = v == _activeView;
                      final item = _views[v];
                      final accuracy = item?.accuracyPercent ?? 95;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => setState(() => _activeView = v),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.accentGold : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? AppTheme.accentGold : Colors.white24,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.photo_camera_back_rounded,
                                  size: 13,
                                  color: isSelected ? AppTheme.primaryNavy : Colors.white70,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  v == PackageViewType.front
                                      ? 'Front PDP'
                                      : (v == PackageViewType.back
                                          ? 'Back View'
                                          : (v == PackageViewType.side ? 'Side Wrap' : 'Flap/Date')),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                    color: isSelected ? AppTheme.primaryNavy : Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primaryNavy.withAlpha(25) : Colors.white12,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    '$accuracy%',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? AppTheme.primaryNavy : AppTheme.accentGold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Next Angle',
                onPressed: _slideNextAngle,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Slide ${values.indexOf(_activeView) + 1} of 4: ${_activeView.label.toUpperCase()} (${currentItem?.accuracyPercent ?? 95}% Accurate)',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary: Save to Logs
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _handleSaveToLogs,
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
              _isSaving ? 'Saving...' : 'Save to Logs',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary: Print / Share PDF
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _handlePrintSharePdf,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            label: const Text(
              'Print / Share PDF',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Action: Verify Weight with Bluetooth Scale or Manual Entry
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _openWeightVerification,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 1.5,
            ),
            icon: const Icon(Icons.bluetooth_searching_rounded, color: AppTheme.accentGold, size: 20),
            label: const Text(
              'Verify Weight (Bluetooth Scale)',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Dedicated: Open Statutory PDF Notice Generator Form
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _openPdfGenerationForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.violationRed,
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
            label: const Text(
              'Generate Statutory Notice (PDF)',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
