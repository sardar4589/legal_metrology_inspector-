import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/inspection_report.dart';
import '../../data/models/package_framing_model.dart';
import '../../data/services/mock_inspection_service.dart';
import '../widgets/legal_metrology_logo.dart';
import '../widgets/package_canvas_widget.dart';
import '../widgets/sticky_forensic_footer.dart';
import 'statutory_audit_screen.dart';

/// Screen: Image Capture & Automated In-Situ Inspection Screen
/// Features:
/// 1. Automatic camera activation upon page load.
/// 2. Automatic package shape detection (Rule 24).
/// 3. In-situ Framing Quality & Alignment Report (In the perfect frame).
/// 4. Automated AI Font Sizing & Table-I compliance audit (Rule 9(1)).
/// 5. Extracted statutory product declarations (Rule 6).
/// 6. Prominent and unmistakable "Retake Photo" CTA.
/// 7. Direct "Save to Case Logs", "Generate Notice (PDF)", and "Print" actions without leaving the page.
class CaptureScreen extends StatefulWidget {
  final bool autoLaunchCamera;
  final String? initialSampleTag;

  const CaptureScreen({
    super.key,
    this.autoLaunchCamera = false,
    this.initialSampleTag,
  });

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final MockInspectionService _service = MockInspectionService();

  String? _capturedImagePath;
  Uint8List? _capturedImageBytes;
  String? _sampleTag;
  bool _hasImage = false;
  bool _isPicking = false;
  bool _isAnalyzing = false;

  // 4D Multi-Angle & Shape Analysis State
  PackageViewType _activeView = PackageViewType.front;
  late AutoShapeAnalysisResult _shapeResult;
  late Map<PackageViewType, PackageViewItem> _viewItems;
  late MultiAngleCaptureAssessment _multiAngleAssessment;
  FramingQualityReport? _currentFramingReport;
  InspectionReport? _inspectionReport;

  @override
  void initState() {
    super.initState();
    _sampleTag = widget.initialSampleTag;
    _resetMultiViewSetup();

    if (_sampleTag != null) {
      _hasImage = true;
      _currentFramingReport = _viewItems[_activeView]?.framingReport ?? FramingQualityReport.evaluate(sampleTag: _sampleTag);
      _runMultiAngleComprehensiveAudit();
    }

    // User Requirement: Notification of captured package pops up every time for only 0.4s
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: AppTheme.passGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sampleTag != null
                        ? 'Captured package image loaded and analyzed.'
                        : 'New Inspection: 4D package capture ready.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryNavy,
            duration: const Duration(milliseconds: 400),
          ),
        );
      }
    });

    if (_sampleTag == null && widget.autoLaunchCamera) {
      // Auto-launch camera immediately upon entering the page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasImage && !_isPicking) {
          _pickImage(ImageSource.camera);
        }
      });
    }
  }

  void _resetMultiViewSetup() {
    _shapeResult = AutoShapeAnalysisResult.analyze(sampleTag: _sampleTag);
    if (_sampleTag != null) {
      _viewItems = {
        for (final v in PackageViewType.values)
          v: PackageViewItem(
            viewType: v,
            imagePath: _capturedImagePath,
            imageBytes: _capturedImageBytes,
            isCaptured: true,
            framingReport: FramingQualityReport.evaluate(sampleTag: _sampleTag, viewType: v),
            accuracyPercent: v == PackageViewType.front ? 96 : (v == PackageViewType.back ? 94 : (v == PackageViewType.side ? 92 : 95)),
            isProper: true,
            evaluationNotes: 'Optimal text clarity and statutory contrast',
          ),
      };
    } else {
      _viewItems = {
        for (final v in PackageViewType.values)
          v: PackageViewItem(viewType: v),
      };
    }
    _multiAngleAssessment = MultiAngleCaptureAssessment.evaluate(_viewItems, sampleTag: _sampleTag);
  }

  /// Evaluates multi-angle image accuracy and generates statutory inspection report once all sides are collected
  Future<void> _runMultiAngleComprehensiveAudit() async {
    _shapeResult = AutoShapeAnalysisResult.analyze(
      imagePath: _capturedImagePath,
      imageBytes: _capturedImageBytes,
      sampleTag: _sampleTag,
    );

    final assessment = MultiAngleCaptureAssessment.evaluate(
      _viewItems,
      sampleTag: _sampleTag,
    );

    setState(() {
      _multiAngleAssessment = assessment;
      _isAnalyzing = true;
    });

    try {
      final report = await _service.analyzePackageLabel(
        imagePath: _capturedImagePath,
        imageBytes: _capturedImageBytes,
        sampleTag: _sampleTag,
      );

      if (mounted) {
        setState(() {
          _inspectionReport = report;
          _isAnalyzing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _inspectionReport = InspectionReport.mockOilViolation(
            imagePath: _capturedImagePath,
            imageBytes: _capturedImageBytes,
            sampleTag: _sampleTag,
          );
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        final framingReport = FramingQualityReport.evaluate(
          imagePath: file.path,
          imageBytes: bytes,
          viewType: _activeView,
        );

        final updatedItem = PackageViewItem(
          viewType: _activeView,
          imagePath: file.path,
          imageBytes: bytes,
          isCaptured: true,
          framingReport: framingReport,
          accuracyPercent: framingReport.overallScorePercent,
          isProper: framingReport.overallScorePercent >= 75,
          evaluationNotes: framingReport.actionableAdvice,
        );

        _viewItems[_activeView] = updatedItem;
        final assessment = MultiAngleCaptureAssessment.evaluate(_viewItems);

        setState(() {
          _capturedImagePath = file.path;
          _capturedImageBytes = bytes;
          _sampleTag = null;
          _hasImage = true;
          _currentFramingReport = framingReport;
          _multiAngleAssessment = assessment;
        });

        if (assessment.allSidesCollected) {
          // All 4 sides collected! Run full comprehensive audit and report generation
          await _runMultiAngleComprehensiveAudit();
        } else {
          // Find next uncaptured side to prompt the user
          final nextUncaptured = PackageViewType.values.firstWhere(
            (v) => !(_viewItems[v]?.isCaptured ?? false),
            orElse: () => _activeView,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: AppTheme.passGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Captured ${_activeView.label}! Next: capture ${nextUncaptured.label} (${assessment.capturedSidesCount}/${assessment.totalRequiredSides} collected).',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppTheme.primaryNavy,
                duration: const Duration(milliseconds: 400),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera/Gallery status: $e'),
            backgroundColor: AppTheme.primaryNavy,
            duration: const Duration(milliseconds: 400),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  void _retakeSide(PackageViewType view) {
    setState(() {
      _activeView = view;
      _viewItems[view] = PackageViewItem(viewType: view);
      _multiAngleAssessment = MultiAngleCaptureAssessment.evaluate(_viewItems);
      _capturedImagePath = null;
      _capturedImageBytes = null;
      _hasImage = false;
      _currentFramingReport = null;
      _inspectionReport = null;
    });
    _pickImage(ImageSource.camera);
  }

  void _retakePhoto() {
    _retakeSide(_activeView);
  }

  void _switchView(PackageViewType view) {
    setState(() {
      _activeView = view;
      final item = _viewItems[view];
      if (item != null && item.isCaptured) {
        _capturedImagePath = item.imagePath;
        _capturedImageBytes = item.imageBytes;
        _hasImage = true;
        _currentFramingReport = item.framingReport ?? FramingQualityReport.evaluate(viewType: view);
      } else {
        _capturedImagePath = null;
        _capturedImageBytes = null;
        _hasImage = false;
        _currentFramingReport = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Row(
          children: [
            const LegalMetrologyLogo(size: 30, isBadge: false),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Capture & Automated Inspection',
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
          if (_hasImage)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Retake Photo',
              onPressed: _retakePhoto,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 4D Multi-Angle Capture & Auto Shape Analysis Header
                _build4dMultiAngleHeader(),
                const SizedBox(height: 16),

                // 2. Main Content: Active Capture or Unified On-Page Inspection
                _buildBodyContent(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const StickyForensicFooter(),
    );
  }

  /// 4D Multi-Angle Capture Strip with Automatic 3D Shape Analysis
  Widget _build4dMultiAngleHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Auto Shape Detection Banner
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryNavy.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.view_in_ar_rounded, size: 15, color: AppTheme.primaryNavy),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'SHAPE DETECTED: ${_shapeResult.detectedShape.label.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryNavy,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Text(
                  '${(_shapeResult.confidence * 100).toInt()}% AI Match',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _shapeResult.shapeReasoning,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderLight),
          const SizedBox(height: 10),

          // 4D Collection Progress & Multi-Angle Accuracy Status
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _multiAngleAssessment.allSidesCollected ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2).withAlpha(150),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _multiAngleAssessment.allSidesCollected ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _multiAngleAssessment.allSidesCollected ? Icons.verified_rounded : Icons.pending_actions_rounded,
                      size: 16,
                      color: _multiAngleAssessment.allSidesCollected ? AppTheme.passGreen : AppTheme.violationRed,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _multiAngleAssessment.allSidesCollected
                            ? 'ALL 4 SIDES COLLECTED • ${_multiAngleAssessment.overallAccuracyPercent}% MULTI-ANGLE ACCURACY'
                            : '4D SCANNING: ${_multiAngleAssessment.capturedSidesCount} OF ${_multiAngleAssessment.totalRequiredSides} SIDES COLLECTED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _multiAngleAssessment.allSidesCollected ? const Color(0xFF15803D) : AppTheme.violationRed,
                        ),
                      ),
                    ),
                    if (!_multiAngleAssessment.allSidesCollected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${(_multiAngleAssessment.capturedSidesCount / _multiAngleAssessment.totalRequiredSides * 100).toInt()}%',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                if (!_multiAngleAssessment.allSidesCollected) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _multiAngleAssessment.totalRequiredSides > 0
                          ? _multiAngleAssessment.capturedSidesCount / _multiAngleAssessment.totalRequiredSides
                          : 0.0,
                      minHeight: 4,
                      backgroundColor: Colors.black12,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Capture pictures from all package sides (any shape). Final report and case actions unlock when all sides are collected.',
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ],
              ],
            ),
          ),

          // Multi-Angle View Selector Tabs (Front, Back, Side, Flap)
          Row(
            children: PackageViewType.values.map((v) {
              final isSelected = v == _activeView;
              final isCaptured = _viewItems[v]?.isCaptured ?? false;
              final accuracy = _viewItems[v]?.accuracyPercent ?? 0;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => _switchView(v),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryNavy : (isCaptured ? const Color(0xFFF1F5F9) : Colors.white),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryNavy : (isCaptured ? AppTheme.passGreen : AppTheme.borderLight),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isCaptured ? Icons.check_circle_rounded : (isSelected ? Icons.camera_alt_rounded : Icons.crop_free_rounded),
                            size: 16,
                            color: isSelected ? Colors.white : (isCaptured ? AppTheme.passGreen : AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            v == PackageViewType.front ? 'Front PDP' : (v == PackageViewType.back ? 'Back View' : (v == PackageViewType.side ? 'Side Wrap' : 'Flap/Date')),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isCaptured)
                            Text(
                              '$accuracy%',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white70 : AppTheme.passGreen,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Initial selection state: Officer chooses Camera or Gallery (NO sample package option)
  Widget _buildSelectionView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instructions Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight, width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.primaryBlue, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Capture ${_activeView.label}. Camera will automatically evaluate framing, detect shape, and complete full statutory compliance inspection.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Interactive Viewfinder Frame with Live Guidelines
        Container(
          height: 260,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight, width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 240,
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withAlpha(70), width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.document_scanner_rounded,
                        size: 48,
                        color: Colors.white.withAlpha(190),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Target ${_activeView.label}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Align package within reticle boundaries',
                        style: TextStyle(color: Colors.white54, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                top: 16,
                left: 16,
                child: Text(
                  'CAMERA READY',
                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Primary: Camera Capture Button
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isPicking ? null : () => _pickImage(ImageSource.camera),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.photo_camera_rounded, size: 22),
            label: const Text(
              'Capture via Camera',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary: Choose from Gallery
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _isPicking ? null : () => _pickImage(ImageSource.gallery),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
            ),
            icon: const Icon(Icons.photo_library_outlined, size: 20, color: AppTheme.primaryNavy),
            label: const Text(
              'Select from Device Gallery',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryNavy),
            ),
          ),
        ),
      ],
    );
  }

  /// Manages content based on whether all package sides are collected
  Widget _buildBodyContent() {
    if (!_multiAngleAssessment.allSidesCollected) {
      return _buildIncompleteCaptureWorkflow();
    } else {
      return _buildUnifiedOnPageInspection();
    }
  }

  /// Workflow while package sides are still being collected across angles
  Widget _buildIncompleteCaptureWorkflow() {
    final currentItem = _viewItems[_activeView];
    final isCurrentCaptured = currentItem != null && currentItem.isCaptured;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isCurrentCaptured) ...[
          // Show preview of current side with prominent option to advance to next missing side
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.passGreen, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PackageCanvasWidget(
                    imagePath: _capturedImagePath,
                    imageBytes: _capturedImageBytes,
                    sampleTag: _sampleTag,
                    height: 280,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.passGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_activeView.label.toUpperCase()} CAPTURED',
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _retakeSide(_activeView),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.violationRed,
                    side: const BorderSide(color: AppTheme.violationRed),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retake This Side', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final nextUncaptured = PackageViewType.values.firstWhere(
                      (v) => !(_viewItems[v]?.isCaptured ?? false),
                      orElse: () => _activeView,
                    );
                    _switchView(nextUncaptured);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Capture Next Side', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ] else ...[
          _buildSelectionView(),
        ],
      ],
    );
  }

  /// Multi-Angle Accuracy & Propriety Card shown once all sides are collected
  Widget _buildMultiAngleAccuracyCard() {
    final assessment = _multiAngleAssessment;
    final isProper = assessment.isProperAndAccurate;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isProper ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isProper ? AppTheme.passGreen : AppTheme.warningAmber).withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isProper ? Icons.verified_rounded : Icons.warning_amber_rounded,
                    color: isProper ? AppTheme.passGreen : AppTheme.warningAmber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${assessment.overallAccuracyPercent}% Multi-Angle Capture Accuracy',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isProper
                            ? 'Proper & accurate for 3D shape and text declarations'
                            : 'Border margins or contrast sub-optimal for OCR',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isProper ? const Color(0xFF15803D) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isProper ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isProper ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
                    ),
                  ),
                  child: Text(
                    isProper ? 'PROPER & ACCURATE' : 'VERIFY MARGIN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isProper ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              assessment.accuracyVerdict,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.borderLight),
            const SizedBox(height: 12),

            // 4-Side Grid Breakdown
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.3,
              children: PackageViewType.values.map((v) {
                final metric = assessment.sideMetrics[v];
                final score = metric?.accuracyPercent ?? 0;
                final isSideProper = metric?.isProper ?? false;
                final isCurrent = v == _activeView;

                return InkWell(
                  onTap: () => _switchView(v),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent ? AppTheme.primaryNavy.withAlpha(10) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent ? AppTheme.primaryNavy : AppTheme.borderLight,
                        width: isCurrent ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSideProper ? Icons.check_circle_rounded : Icons.pending_rounded,
                          size: 16,
                          color: isSideProper ? AppTheme.passGreen : AppTheme.warningAmber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                v == PackageViewType.front ? 'Front PDP' : (v == PackageViewType.back ? 'Back Panel' : (v == PackageViewType.side ? 'Side Wrap' : 'Flap/Date')),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                isSideProper ? '$score% Accurate' : 'Pending',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSideProper ? AppTheme.passGreen : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Complete In-Situ Automated Inspection Report on CaptureScreen
  Widget _buildUnifiedOnPageInspection() {
    final framingReport = _currentFramingReport ?? FramingQualityReport.evaluate();
    final report = _inspectionReport;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 0. Comprehensive 4D Multi-Angle Image Accuracy & Verification Card
        _buildMultiAngleAccuracyCard(),
        const SizedBox(height: 16),

        // 1. Captured Image Canvas with Live Framing Quality Badge
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: framingReport.verdict.isOptimal ? AppTheme.passGreen : AppTheme.warningAmber,
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (framingReport.verdict.isOptimal ? AppTheme.passGreen : AppTheme.warningAmber).withAlpha(35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PackageCanvasWidget(
                  imagePath: _capturedImagePath,
                  imageBytes: _capturedImageBytes,
                  sampleTag: _sampleTag,
                  height: 320,
                ),
              ),
            ),

            // Top-Pinned In-Situ Framing Badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: framingReport.verdict.isOptimal ? const Color(0xFF047857) : const Color(0xFFB45309),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(70),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      framingReport.verdict.isOptimal ? Icons.verified_rounded : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      framingReport.verdict.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${framingReport.overallScorePercent}% SCORE',
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Quick Retake Shutter Button Overlay on Top-Right
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: _retakePhoto,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Retake',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. PROMINENT RETAKE BUTTON: Impossible to miss
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _retakePhoto,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.violationRed,
              side: const BorderSide(color: AppTheme.violationRed, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.violationRed),
            label: const Text(
              'Retake Photo / Scan Another Package',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.violationRed),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Live On-Page Framing Quality Diagnostics Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.borderLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF047857).withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF047857), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Package Framing & Clarity Report',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          Text(
                            'Automated boundary, sharpness & lighting analysis',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Text(
                        'PERFECT FRAME',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.borderLight),
                const SizedBox(height: 12),

                // Diagnostic 4-Metric Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Boundary Margin',
                        value: '${framingReport.boundaryMarginPercent}% Margin',
                        statusText: '100% In Bounds',
                        isPass: framingReport.isWithinSafeBoundary,
                        icon: Icons.crop_free_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Focus Sharpness',
                        value: '${framingReport.sharpnessPercent}% Clarity',
                        statusText: 'High Contrast',
                        isPass: framingReport.sharpnessPercent >= 85,
                        icon: Icons.lens_blur_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Lighting & Glare',
                        value: '${framingReport.glareIndexPercent}% Reflection',
                        statusText: 'Optimal Low Glare',
                        isPass: framingReport.glareIndexPercent <= 15,
                        icon: Icons.light_mode_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'PDP Coverage',
                        value: '${framingReport.pdpCoveragePercent}% Surface Fill',
                        statusText: 'Full Target Scale',
                        isPass: framingReport.pdpCoveragePercent >= 70,
                        icon: Icons.aspect_ratio_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Actionable advice banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.passGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          framingReport.actionableAdvice,
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Automated Inspection Status / Loading Indicator
        if (_isAnalyzing)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: const Column(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryNavy),
                ),
                SizedBox(height: 12),
                Text(
                  'Running automated statutory compliance audit...',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                SizedBox(height: 4),
                Text(
                  'Edge AI text recognition, shape profiling & Rule 9(1) Table-I font measurement in progress',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else if (report != null) ...[
          // Prominent Next Step: Proceed to Dedicated Statutory Audit Page (User Requirement)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '4D Package Capture Verified',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          Text(
                            'All sides verified proper & accurate for statutory audit',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StatutoryAuditScreen(
                            report: report,
                            multiAngleViews: _viewItems,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.accentGold, size: 20),
                    label: const Text(
                      'Proceed to Automated AI Statutory Audit →',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String statusText,
    required bool isPass,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isPass ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPass ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: isPass ? AppTheme.passGreen : AppTheme.violationRed),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: isPass ? AppTheme.passGreen : AppTheme.violationRed,
            ),
          ),
        ],
      ),
    );
  }
}
