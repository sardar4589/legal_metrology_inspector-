import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/font_caliper_models.dart';
import '../widgets/ar_pdp_overlay.dart';
import '../widgets/edge_ai_status_hud.dart';
import '../widgets/font_caliper_widget.dart';
import '../widgets/package_canvas_widget.dart';
import '../../data/services/automated_vision_service.dart';

/// Screen: AR Viewfinder & Optical Caliper Overlay
/// Provides real-time visual assistance for field officers targeting the
/// Principal Display Panel (PDP), verifying numeral font heights via an optical caliper,
/// and displaying Edge AI processing states with high-contrast low-confidence warnings.
class ArViewfinderScreen extends StatefulWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final String? initialSampleTag;

  const ArViewfinderScreen({
    super.key,
    this.imagePath,
    this.imageBytes,
    this.initialSampleTag,
  });

  @override
  State<ArViewfinderScreen> createState() => _ArViewfinderScreenState();
}

class _ArViewfinderScreenState extends State<ArViewfinderScreen> {
  String? _imagePath;
  Uint8List? _imageBytes;
  String? _currentSampleTag;
  late PdpDimensions _pdpDimensions;
  late FontCaliperMeasurement _caliperMeasurement;
  EdgeAiState _aiState = EdgeAiState.measuring;
  bool _isAligned = true;
  double _currentNetQtyGrams = 1000.0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _imagePath = widget.imagePath;
    _imageBytes = widget.imageBytes;
    _currentSampleTag = widget.initialSampleTag ?? (_imagePath == null && _imageBytes == null ? 'goodlife_oil' : null);
    _setupInitialParameters();
  }

  void _setupInitialParameters() {
    if (_currentSampleTag == 'goodlife_oil') {
      // 1 L Oil package: Area = 18cm x 10cm = 180 cm^2
      // Rule 9(1) Table-I requires 3.0mm for Net Qty numeral
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
        ocrConfidence: 0.64, // Default low confidence (<75%) to demonstrate requirement
        ruleReference: 'Rule 9(1) Table-I, PCR 2011',
      );
    } else if (_currentSampleTag == 'sharbati_atta') {
      // 5 kg Atta package: Area = 28cm x 22cm = 616 cm^2
      // Rule 9(1) Table-I requires 4.0mm - 6.0mm
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
        ocrConfidence: 0.92,
        ruleReference: 'Rule 9(1) Table-I, PCR 2011',
      );
    } else if (_currentSampleTag == 'himalayan_salt') {
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
        ocrConfidence: 0.88,
        ruleReference: 'Rule 9(1) Table-I, PCR 2011',
      );
    } else {
      // Custom captured package
      _currentNetQtyGrams = 1000.0;
      _pdpDimensions = PdpDimensions.calculate(
        widthCm: 12.0,
        heightCm: 18.0,
        shape: PdpShape.rectangular,
        netQuantityGrams: _currentNetQtyGrams,
      );
      _caliperMeasurement = const FontCaliperMeasurement(
        measuredHeightMm: 2.8,
        requiredHeightMm: 3.0,
        targetField: 'Declared Net Quantity',
        ocrConfidence: 0.89,
        ruleReference: 'Rule 9(1) Table-I, PCR 2011',
      );
    }
  }

  Future<void> _captureOrPickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 92,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;

        // Show Confirmation Dialog: Verify if image is correct or retake
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.camera_enhance_rounded, color: AppTheme.primaryNavy, size: 22),
                SizedBox(width: 8),
                Text('Confirm Package Image', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderLight),
                    color: const Color(0xFF0F172A),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Is the package image clear and legible, or do you want to retake it?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: AppTheme.passGreen),
                          SizedBox(width: 6),
                          Text('Lighting: Adequate & Uniform', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: AppTheme.passGreen),
                          SizedBox(width: 6),
                          Text('Clarity: Numerals & Text Sharp', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retake Photo'),
                onPressed: () => Navigator.pop(ctx, false),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                icon: const Icon(Icons.auto_awesome, size: 16, color: AppTheme.accentGold),
                label: const Text('Confirm & Auto-Inspect'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          setState(() {
            _imagePath = picked.path;
            _imageBytes = bytes;
            _currentSampleTag = null;
            _aiState = EdgeAiState.measuring;
          });
          await _executeAutomatedInspection(imagePath: picked.path, imageBytes: bytes);
        } else if (confirmed == false) {
          _captureOrPickImage(source);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing image: $e'),
            backgroundColor: AppTheme.violationRed,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _executeAutomatedInspection({String? imagePath, Uint8List? imageBytes, String? sampleTag}) async {
    final result = await AutomatedVisionService.autoInspectImage(
      imagePath: imagePath ?? _imagePath,
      imageBytes: imageBytes ?? _imageBytes,
      sampleTag: sampleTag ?? _currentSampleTag,
    );

    setState(() {
      _pdpDimensions = result.pdpDimensions;
      _caliperMeasurement = result.caliperMeasurement;
      _aiState = EdgeAiState.completed;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.accentGold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Automated AR Inspection: ${result.detectionSummary}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryNavy,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 400),
        ),
      );
    }
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
                    'Configure statutory specifications for any audited package under Rule 24 & Rule 9(1) of PCR 2011:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // Width and Height Fields
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

                  // Net Quantity Field
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Net Quantity (g or ml)',
                      hintText: 'e.g. 500 for 500g, 1000 for 1kg/L',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // Shape Selector
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

                  // Computed Statutory Summary Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated PDP: ${w}cm × ${h}cm (${_pdpDimensions.areaCm2} cm²), Req Font ≥ ${_pdpDimensions.minimumRequiredFontMm}mm'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Apply Specifications'),
              ),
            ],
          );
        },
      ),
    );
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
    });
  }

  void _switchPackageSample(String tag) {
    setState(() {
      _currentSampleTag = tag;
      _setupInitialParameters();
    });
  }

  void _toggleConfidenceSimulation() {
    setState(() {
      // Toggle between low confidence (<75%) and high confidence (>75%)
      if (_caliperMeasurement.ocrConfidence < 0.75) {
        _caliperMeasurement = _caliperMeasurement.copyWith(ocrConfidence: 0.94);
        _aiState = EdgeAiState.completed;
      } else {
        _caliperMeasurement = _caliperMeasurement.copyWith(ocrConfidence: 0.64);
        _aiState = EdgeAiState.measuring;
      }
    });
  }

  void _openManualCalibrationDialog() {
    double currentVal = _caliperMeasurement.measuredHeightMm;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppTheme.primaryNavy),
              SizedBox(width: 8),
              Text('Manual Font Caliper Gauge', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Physical Gauge Verification (Rule 9(1) Table-I):',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Due to reflection/curvature, align the physical metric ruler with the numeral x-height on the package.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      '${currentVal.toStringAsFixed(1)} mm',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: currentVal >= _caliperMeasurement.requiredHeightMm
                            ? AppTheme.passGreen
                            : AppTheme.violationRed,
                      ),
                    ),
                    Text(
                      'Required: ≥ ${_caliperMeasurement.requiredHeightMm.toStringAsFixed(1)} mm',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove_rounded),
                    onPressed: currentVal > 0.5
                        ? () => setDialogState(() => currentVal = double.parse((currentVal - 0.1).toStringAsFixed(1)))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => setDialogState(() => currentVal = double.parse((currentVal + 0.1).toStringAsFixed(1))),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
              onPressed: () {
                setState(() {
                  _caliperMeasurement = _caliperMeasurement.copyWith(
                    measuredHeightMm: currentVal,
                    ocrConfidence: 0.98, // Calibrated by field officer
                  );
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Manual caliper calibration recorded with digital officer stamp.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                );
              },
              child: const Text('Apply Measurement'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C2340),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AR Viewfinder & Font Caliper',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            Text(
              'Principal Display Panel & Numeral Verification',
              style: TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white),
            tooltip: 'Package PDP Specifications',
            onPressed: _openPdpDimensionsDialog,
          ),
          IconButton(
            icon: Icon(
              _caliperMeasurement.isLowConfidence
                  ? Icons.warning_amber_rounded
                  : Icons.speed_rounded,
              color: _caliperMeasurement.isLowConfidence ? AppTheme.warningAmber : AppTheme.accentGold,
            ),
            tooltip: 'Simulate Confidence Level',
            onPressed: _toggleConfidenceSimulation,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            tooltip: 'Manual Calibration',
            onPressed: _openManualCalibrationDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Live Camera Preview / Uploaded Photo / Simulated High-Resolution Package Background
          Positioned.fill(
            child: PackageCanvasWidget(
              imagePath: _imagePath,
              imageBytes: _imageBytes,
              sampleTag: _currentSampleTag,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // 2. AR Viewfinder Overlay (Targeting Principal Display Panel)
          Positioned.fill(
            child: ArPdpOverlay(
              dimensions: _pdpDimensions,
              isAligned: _isAligned,
              onToggleShape: _togglePdpShape,
              onEditDimensions: _openPdpDimensionsDialog,
            ),
          ),

          // 3. Top Floating Action Toolbar: Camera, Gallery, Sample Presets & PDP Alignment
          Positioned(
            top: 14,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Camera Capture Button
                  InkWell(
                    onTap: () => _captureOrPickImage(ImageSource.camera),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C2340).withAlpha(230),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white60, width: 1.2),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Open Camera', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Device Gallery Button
                  InkWell(
                    onTap: () => _captureOrPickImage(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C2340).withAlpha(230),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white30, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library_rounded, size: 14, color: Colors.white70),
                          SizedBox(width: 4),
                          Text('Gallery', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Demo Presets Popup Menu
                  PopupMenuButton<String>(
                    tooltip: 'Load Sample Product',
                    padding: EdgeInsets.zero,
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C2340).withAlpha(230),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers_outlined, size: 13, color: AppTheme.accentGold),
                          SizedBox(width: 4),
                          Text('Presets', style: TextStyle(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    color: const Color(0xFF0C2340),
                    onSelected: (val) {
                      setState(() {
                        _imagePath = null;
                        _imageBytes = null;
                        _switchPackageSample(val);
                      });
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'goodlife_oil',
                        child: Text('Refined Oil 1 L (Table-I 3.0mm)', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: 'sharbati_atta',
                        child: Text('Wheat Atta 5 kg (Table-I 4.0mm)', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: 'himalayan_salt',
                        child: Text('Table Salt 1 kg (Table-I 3.0mm)', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),

                  const SizedBox(width: 8),

                  // PDP Alignment Lock Toggle Button
                  InkWell(
                    onTap: () => setState(() => _isAligned = !_isAligned),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C2340).withAlpha(230),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _isAligned ? AppTheme.passGreen : AppTheme.warningAmber,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isAligned ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                            color: _isAligned ? AppTheme.passGreen : AppTheme.warningAmber,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isAligned ? 'PDP LOCKED' : 'SEARCHING',
                            style: TextStyle(
                              color: _isAligned ? const Color(0xFF4ADE80) : AppTheme.warningAmber,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Section: Edge AI HUD + Visual Font Caliper Widget + Action
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 20, top: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(200),
                    Colors.black.withAlpha(250),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edge AI Status HUD with Low-Confidence Warning Banner (<75%)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: EdgeAiStatusHud(
                        state: _aiState,
                        confidence: _caliperMeasurement.ocrConfidence,
                        onManualVerifyPressed: _openManualCalibrationDialog,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Visual Font Caliper Widget
                    FontCaliperWidget(
                      measurement: _caliperMeasurement,
                      onMeasurementChanged: (newVal) {
                        setState(() {
                          _caliperMeasurement = _caliperMeasurement.copyWith(measuredHeightMm: newVal);
                        });
                      },
                      onRequiredHeightChanged: (newReq) {
                        setState(() {
                          _caliperMeasurement = _caliperMeasurement.copyWith(requiredHeightMm: newReq);
                        });
                      },
                    ),

                    // Prominent Camera Shutter / Retake & Apply Action Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _captureOrPickImage(ImageSource.camera),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white70, width: 1.5),
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF0C2340).withAlpha(180),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.photo_camera_rounded, size: 18, color: Colors.white),
                              label: const Text(
                                'Open Camera',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context, _caliperMeasurement);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                              label: const Text(
                                'Apply Caliper',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
