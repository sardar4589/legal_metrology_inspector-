import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/compliance_check.dart';
import '../../data/models/fifth_schedule_models.dart';
import '../../data/models/inspection_report.dart';
import '../../data/models/product_details.dart';
import '../../data/services/fifth_schedule_service.dart';
import '../../data/services/pdf_report_service.dart';
import '../widgets/lot_metrics_dashboard.dart';
import '../widgets/sticky_forensic_footer.dart';
import 'pdf_generation_form_screen.dart';

/// Screen: Fifth Schedule Lot Sampling Wizard & Results Dashboard
/// Guides officers through:
/// 1. Lot Configuration (Commodity, Qn, N, n, Tare, MPE)
/// 2. Sample Package Weight Entry (Gross weights, Net weights, Individual errors, Bluetooth scale stream)
/// 3. Statistical Lot Metrics Results Dashboard (Mean, Std Dev, Corrected Avg, MPE PASS/FAIL)
///
/// Refactored for Field Ergonomics & Statutory Forensics:
/// - Sticky live forensic header (GPS Lat/Long, IST UTC-offset timestamp, Inspector badge ID)
/// - Compact step indicator chips preventing text truncation on narrow mobile viewports
/// - Bluetooth scale connection status pill & quick-fill stream receiver banner in Step 2
/// - High luminance contrast cards and inputs
class FifthScheduleWizardScreen extends StatefulWidget {
  final String? initialCommodity;
  final double? initialDeclaredQuantity;
  final WeightUnit? initialUnit;

  const FifthScheduleWizardScreen({
    super.key,
    this.initialCommodity,
    this.initialDeclaredQuantity,
    this.initialUnit,
  });

  @override
  State<FifthScheduleWizardScreen> createState() => _FifthScheduleWizardScreenState();
}

class _FifthScheduleWizardScreenState extends State<FifthScheduleWizardScreen> {
  int _currentStep = 0; // 0: Config, 1: Weights Entry, 2: Statistical Results

  // Step 1 Controllers & State
  final _commodityController = TextEditingController(text: 'GoodLife Refined Sunflower Oil');
  final _declaredQtyController = TextEditingController(text: '1000');
  final _lotSizeController = TextEditingController(text: '1200');
  final _sampleSizeController = TextEditingController(text: '32');
  final _tareWeightController = TextEditingController(text: '18.5');
  WeightUnit _selectedUnit = WeightUnit.milliliters;

  late FifthScheduleConfig _config;

  // Step 2 State & BLE Simulation
  List<SamplePackageWeight> _samples = [];
  final Map<int, TextEditingController> _weightControllers = {};
  final _quickGrossController = TextEditingController();
  final _quickGrossFocusNode = FocusNode();

  bool _isBleConnected = true;
  final String _bleDeviceName = 'Essae Teraoka BLE-900';
  double _liveBleWeight = 0.0;
  bool _isStreamingActive = true;

  // Step 3 State
  StatisticalLotMetrics? _lotMetrics;

  @override
  void initState() {
    super.initState();
    if (widget.initialCommodity != null) {
      _commodityController.text = widget.initialCommodity!;
    }
    if (widget.initialDeclaredQuantity != null) {
      _declaredQtyController.text = widget.initialDeclaredQuantity!.toStringAsFixed(0);
    }
    if (widget.initialUnit != null) {
      _selectedUnit = widget.initialUnit!;
    }

    _updateConfig();
    _loadPassingSampleBatch(); // Default to pre-filled 32 realistic samples for rapid field testing
  }

  @override
  void dispose() {
    _commodityController.dispose();
    _declaredQtyController.dispose();
    _lotSizeController.dispose();
    _sampleSizeController.dispose();
    _tareWeightController.dispose();
    _quickGrossController.dispose();
    _quickGrossFocusNode.dispose();
    for (final c in _weightControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateConfig() {
    final qty = double.tryParse(_declaredQtyController.text) ?? 1000.0;
    final lot = int.tryParse(_lotSizeController.text) ?? 1200;
    final sample = int.tryParse(_sampleSizeController.text) ?? 32;
    final tare = double.tryParse(_tareWeightController.text) ?? 18.5;

    final mpeCalc = FifthScheduleService.calculateMpe(
      declaredQuantity: qty,
      unit: _selectedUnit,
    );

    final maxT1 = FifthScheduleService.getMaxPermissibleT1(sample);

    setState(() {
      _config = FifthScheduleConfig(
        commodityName: _commodityController.text,
        declaredQuantity: qty,
        unit: _selectedUnit,
        lotSize: lot,
        sampleSize: sample,
        tareWeight: tare,
        mpeValue: mpeCalc.mpeValue,
        mpePercent: mpeCalc.mpePercent,
        maxPermissibleT1Defectives: maxT1,
      );
    });
  }

  void _loadPassingSampleBatch() {
    _updateConfig();
    final list = FifthScheduleService.generateMockSampleWeights(
      sampleCount: _config.sampleSize > 0 ? _config.sampleSize : 32,
      declaredQuantity: _config.declaredQuantity,
      tareWeight: _config.tareWeight,
      mpe: _config.mpeValue,
      simulateDeficient: false,
    );

    _syncSamples(list);
  }

  void _loadFailingSampleBatch() {
    _updateConfig();
    final list = FifthScheduleService.generateMockSampleWeights(
      sampleCount: _config.sampleSize > 0 ? _config.sampleSize : 32,
      declaredQuantity: _config.declaredQuantity,
      tareWeight: _config.tareWeight,
      mpe: _config.mpeValue,
      simulateDeficient: true,
    );

    _syncSamples(list);
  }

  void _syncSamples(List<SamplePackageWeight> list) {
    setState(() {
      _samples = list;
      _weightControllers.clear();
      for (final s in list) {
        _weightControllers[s.sampleNumber] = TextEditingController(text: s.grossWeight.toStringAsFixed(1));
      }
      _sampleSizeController.text = _samples.length.toString();
      _config = _config.copyWith(
        sampleSize: _samples.length,
        maxPermissibleT1Defectives: FifthScheduleService.getMaxPermissibleT1(_samples.length),
      );
    });
  }

  void _addSingleSampleWeight([double? customGross]) {
    final textVal = _quickGrossController.text.trim();
    final gross = customGross ?? double.tryParse(textVal);
    if (gross == null || gross <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid gross weight number.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final newIndex = _samples.length + 1;
    final newSample = SamplePackageWeight.calculate(
      sampleNumber: newIndex,
      grossWeight: gross,
      tareWeight: _config.tareWeight,
      declaredQuantity: _config.declaredQuantity,
      mpe: _config.mpeValue,
    );

    setState(() {
      _samples.add(newSample);
      _weightControllers[newIndex] = TextEditingController(text: gross.toStringAsFixed(1));
      _sampleSizeController.text = _samples.length.toString();
      _config = _config.copyWith(
        sampleSize: _samples.length,
        maxPermissibleT1Defectives: FifthScheduleService.getMaxPermissibleT1(_samples.length),
      );
    });

    _quickGrossController.clear();
    _quickGrossFocusNode.requestFocus();
  }

  void _streamNextBleWeight() {
    // Generate realistic live streamed weight around Qn + Tare
    final jitter = (DateTime.now().millisecond % 9 - 4) * 0.4;
    final streamedGross = (_config.declaredQuantity + _config.tareWeight + jitter);
    _liveBleWeight = streamedGross;

    _addSingleSampleWeight(streamedGross);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Captured sample #${_samples.length} from BLE Scale: ${streamedGross.toStringAsFixed(1)} ${_config.unit.symbol}',
        ),
        backgroundColor: const Color(0xFF0C2340),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _zeroBleScale() {
    setState(() {
      _liveBleWeight = 0.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('BLE Scale calibrated to 0.00g (Tare/Zero successful).'),
        backgroundColor: Color(0xFF166534),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeSample(int index) {
    setState(() {
      _samples.removeAt(index);
      final updatedList = <SamplePackageWeight>[];
      _weightControllers.clear();
      for (int i = 0; i < _samples.length; i++) {
        final s = _samples[i];
        final renumbered = SamplePackageWeight.calculate(
          sampleNumber: i + 1,
          grossWeight: s.grossWeight,
          tareWeight: _config.tareWeight,
          declaredQuantity: _config.declaredQuantity,
          mpe: _config.mpeValue,
        );
        updatedList.add(renumbered);
        _weightControllers[i + 1] = TextEditingController(text: s.grossWeight.toStringAsFixed(1));
      }
      _samples = updatedList;
      _sampleSizeController.text = _samples.length.toString();
      _config = _config.copyWith(
        sampleSize: _samples.length,
        maxPermissibleT1Defectives: FifthScheduleService.getMaxPermissibleT1(_samples.length),
      );
    });
  }

  void _clearAllSamples() {
    setState(() {
      _samples.clear();
      _weightControllers.clear();
      _sampleSizeController.text = '0';
      _config = _config.copyWith(
        sampleSize: 0,
        maxPermissibleT1Defectives: 0,
      );
    });
  }

  void _updateSampleGrossWeight(int index, String val) {
    final gross = double.tryParse(val);
    if (gross != null) {
      setState(() {
        _samples[index] = SamplePackageWeight.calculate(
          sampleNumber: index + 1,
          grossWeight: gross,
          tareWeight: _config.tareWeight,
          declaredQuantity: _config.declaredQuantity,
          mpe: _config.mpeValue,
        );
      });
    }
  }

  void _calculateAndProceedToResults() {
    if (_samples.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one sample weight to calculate lot metrics.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _lotMetrics = FifthScheduleService.computeLotMetrics(
      samples: _samples,
      declaredQuantity: _config.declaredQuantity,
      unit: _config.unit,
      mpe: _config.mpeValue,
    );

    setState(() {
      _currentStep = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fifth Schedule Wizard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            Text(
              'Net Content Testing & MPE Statistical Audit (Rule 24)',
              style: TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1)),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              // Refactored compact step indicator preventing text truncation
              _buildWizardStepIndicator(),

              // Step Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: _buildCurrentStepView(),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBottomControls(),
          const StickyForensicFooter(),
        ],
      ),
    );
  }

  /// Compact icon+label chips step indicator (prevents text truncation on all viewports)
  Widget _buildWizardStepIndicator() {
    final steps = [
      {'label': 'Setup', 'number': 1},
      {'label': 'Weights', 'number': 2},
      {'label': 'Audit', 'number': 3},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(steps.length, (index) {
            final isCurrent = _currentStep == index;
            final isCompleted = _currentStep > index;
            final item = steps[index];

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    if (index <= _currentStep || (index == 2 && _samples.isNotEmpty)) {
                      setState(() => _currentStep = index);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppTheme.primaryNavy
                          : (isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrent
                            ? AppTheme.primaryNavy
                            : (isCompleted ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1)),
                        width: isCurrent ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: isCurrent
                              ? Colors.white
                              : (isCompleted ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
                          child: isCompleted
                              ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                              : Text(
                                  '${item['number']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: isCurrent ? AppTheme.primaryNavy : Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                            color: isCurrent
                                ? Colors.white
                                : (isCompleted ? const Color(0xFF15803D) : const Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < steps.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFF94A3B8)),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  InspectionReport _buildInspectionReportFromLotMetrics() {
    final metrics = _lotMetrics;
    final isCompliant = metrics?.isLotPassed ?? true;
    final commodityName = _commodityController.text.trim().isEmpty
        ? 'GoodLife Refined Sunflower Oil'
        : _commodityController.text.trim();
    final declaredQtyStr = '${_config.declaredQuantity} ${_config.unit.symbol}';

    return InspectionReport(
      caseId: 'LOT-FS-${DateTime.now().millisecondsSinceEpoch % 100000}',
      officerName: 'R. Sharma',
      officerId: 'INSP-DL-4082',
      timestamp: DateTime.now(),
      businessName: 'Apex Commodities Distribution Hub',
      location: 'Delhi Regional Enforcement Zone',
      overallStatus: isCompliant ? InspectionStatus.pass : InspectionStatus.violation,
      statusSummary: isCompliant
          ? 'Lot Passed Fifth Schedule Standards'
          : 'Fifth Schedule MPE Deficiency Flagged',
      statutoryCategory: isCompliant ? 'Compliant Packages' : 'Weight Shortage (Fifth Schedule)',
      measuredNetWeight: metrics?.sampleMean,
      isWeightCompliant: isCompliant,
      mpeLimit: _config.mpeValue,
      productDetails: ProductDetails(
        brandName: commodityName,
        declaredNetQuantity: declaredQtyStr,
        declaredMrp: '₹145.00',
        unitSalePrice: '₹0.145 / ${_config.unit.symbol}',
        batchMfgDate: 'B.No: B7-402, Mfg: 08/2026',
        manufacturerAddress: 'Apex Commodities Agro Processing Ltd, Sector 62',
        consumerCareDetails: 'care@apexagro.in | 1800-11-4082',
      ),
      complianceChecks: [
        ComplianceCheck(
          title: 'Fifth Schedule Statistical Sampling Audit (n=${metrics?.totalSamples ?? _config.sampleSize}, N=${_config.lotSize})',
          isCompliant: isCompliant,
          statusText: isCompliant ? 'PASS' : 'VIOLATION',
          ruleReference: 'Rule 11 & Fifth Schedule PCR 2011',
          description: metrics?.statusSummary ??
              'Average net quantity and T1/T2 defective packages evaluated under Fifth Schedule.',
          flaggedDetail: isCompliant
              ? null
              : 'Defective packages exceed permissible threshold under Table-1 / Table-2',
        ),
      ],
    );
  }

  void _attachToLotMemoAndGeneratePdf() {
    final report = _buildInspectionReportFromLotMetrics();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfGenerationFormScreen(report: report),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStep1LotConfig();
      case 1:
        return _buildStep2WeightsEntry();
      case 2:
      default:
        return _lotMetrics != null
            ? LotMetricsDashboard(
                metrics: _lotMetrics!,
                onExportPressed: () async {
                  final report = _buildInspectionReportFromLotMetrics();
                  await PdfReportService.printOrSharePdf(
                    report,
                    noticeTitle: 'Form V: Fifth Schedule Statutory Sampling Register',
                  );
                },
                onSaveToInspection: _attachToLotMemoAndGeneratePdf,
              )
            : const SizedBox();
    }
  }

  /// Step 1: Batch & Commodity Setup
  Widget _buildStep1LotConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Statutory Instruction Card (High Contrast)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.primaryNavy, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fifth Schedule of PCR 2011 prescribes statistical lot sampling to verify that the average net quantity conforms to declared weight and that individual deficiencies do not exceed statutory MPE.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF0F172A), height: 1.35, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Commodity Name
        TextField(
          controller: _commodityController,
          onChanged: (_) => _updateConfig(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          decoration: const InputDecoration(
            labelText: 'Product / Commodity Name',
            hintText: 'e.g. Refined Sunflower Oil 1L',
            prefixIcon: Icon(Icons.inventory_2_outlined, color: AppTheme.primaryNavy),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // Declared Quantity + Unit Row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _declaredQtyController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _updateConfig(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: const InputDecoration(
                  labelText: 'Declared Net Quantity (Qn)',
                  prefixIcon: Icon(Icons.scale_rounded, color: AppTheme.primaryNavy),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<WeightUnit>(
                initialValue: _selectedUnit,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                items: WeightUnit.values.map((u) {
                  return DropdownMenuItem(
                    value: u,
                    child: Text('${u.symbol} (${u.label})', overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedUnit = val);
                    _updateConfig();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Lot Size (N) + Sample Size (n) Row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _lotSizeController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _updateConfig(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: const InputDecoration(
                  labelText: 'Lot Size (N)',
                  helperText: 'Total units in batch',
                  prefixIcon: Icon(Icons.warehouse_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _sampleSizeController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _updateConfig(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: const InputDecoration(
                  labelText: 'Sample Size (n)',
                  helperText: 'Statutory sample draw',
                  prefixIcon: Icon(Icons.format_list_numbered_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Average Tare Weight (T)
        TextField(
          controller: _tareWeightController,
          keyboardType: TextInputType.number,
          onChanged: (_) => _updateConfig(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          decoration: InputDecoration(
            labelText: 'Average Tare Weight (T)',
            helperText: 'Empty packaging / pouch / bottle tare weight',
            suffixText: _selectedUnit.symbol,
            prefixIcon: const Icon(Icons.takeout_dining_outlined),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),

        // Auto-Computed MPE Statutory Card (High Contrast)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC8963E), width: 2.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8963E).withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.gavel_rounded, color: Color(0xFFC8963E), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Fifth Schedule Maximum Permissible Error (MPE)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0C2340)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Statutory MPE Limit:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        const SizedBox(height: 2),
                        Text(
                          '± ${_config.mpeValue.toStringAsFixed(2)} ${_selectedUnit.symbol}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0C2340)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Max Allowed T1 Defectives:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        const SizedBox(height: 2),
                        Text(
                          '${_config.maxPermissibleT1Defectives} pkgs (T2 = 0)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF166534)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Step 2: Sample Weights Entry Grid & BLE Stream Receiver
  Widget _buildStep2WeightsEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // User Requirement: Bluetooth Scale Connection Status Pill & Streaming Banner
        _buildBluetoothStreamBanner(),
        const SizedBox(height: 14),

        // Quick presets bar
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              'Sample Packages (${_samples.length} units)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0C2340)),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_samples.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearAllSamples,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.violationRed,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 14),
                    label: const Text('Clear All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                OutlinedButton.icon(
                  onPressed: _loadPassingSampleBatch,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    side: const BorderSide(color: Color(0xFF166534), width: 1.2),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF166534)),
                  label: const Text('Fill Passing Lot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF166534))),
                ),
                OutlinedButton.icon(
                  onPressed: _loadFailingSampleBatch,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    side: const BorderSide(color: AppTheme.violationRed, width: 1.2),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.violationRed),
                  label: const Text('Fill Deficient Lot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.violationRed)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Header parameters
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('Tare: ${_config.tareWeight}${_config.unit.symbol}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              Text('Declared Qn: ${_config.declaredQuantity}${_config.unit.symbol}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              Text('MPE: ±${_config.mpeValue}${_config.unit.symbol}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFC8963E))),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Quick Gross Weight Entry Bar (Allows rapid manual entry or scanner input)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0C2340), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quickGrossController,
                  focusNode: _quickGrossFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => _addSingleSampleWeight(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Enter Gross Weight (#${_samples.length + 1})',
                    hintText: 'e.g. ${(_config.declaredQuantity + _config.tareWeight).toStringAsFixed(1)}',
                    prefixIcon: const Icon(Icons.scale_rounded, color: AppTheme.primaryNavy, size: 20),
                    suffixText: _config.unit.symbol,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _addSingleSampleWeight(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Weight', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Weights List or Empty State
        if (_samples.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
            ),
            child: const Column(
              children: [
                Icon(Icons.scale_outlined, size: 36, color: Color(0xFF64748B)),
                SizedBox(height: 8),
                Text(
                  'No Sample Weights Added Yet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                ),
                SizedBox(height: 4),
                Text(
                  'Use BLE Stream Reading or tap "Fill Passing Lot" above for instant population.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _samples.length,
            itemBuilder: (ctx, index) {
              final sample = _samples[index];
              final err = sample.individualError;
              final isT1 = sample.isT1Defective;
              final isT2 = sample.isT2Defective;
              final isOk = !isT1 && !isT2;

              final statusColor = isT2
                  ? AppTheme.violationRed
                  : (isT1 ? const Color(0xFFD97706) : const Color(0xFF166534));

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOk ? const Color(0xFFCBD5E1) : statusColor,
                    width: isOk ? 1.0 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Sample Index Chip
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF94A3B8)),
                      ),
                      child: Center(
                        child: Text(
                          '#${sample.sampleNumber}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primaryNavy),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Gross Weight Input
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _weightControllers[sample.sampleNumber],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) => _updateSampleGrossWeight(index, val),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Gross',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            suffixText: _config.unit.symbol,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Computed Net Weight
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Net Content', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                          Text(
                            '${sample.netWeight.toStringAsFixed(1)} ${_config.unit.symbol}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Error Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${err >= 0 ? '+' : ''}${err.toStringAsFixed(1)}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: statusColor),
                          ),
                          Text(
                            isT2 ? 'T2 DEFECT' : (isT1 ? 'T1 DEFECT' : 'OK'),
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: statusColor),
                          ),
                        ],
                      ),
                    ),

                    // Remove Sample Button
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.black45),
                      tooltip: 'Remove sample',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () => _removeSample(index),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _quickGrossFocusNode.requestFocus(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryNavy, size: 16),
            label: const Text(
              '+ Add Another Sample Weight',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, fontSize: 12.5),
            ),
          ),
        ],
      ],
    );
  }

  /// Bluetooth Scale Connection Status Pill & Quick-Fill Stream Receiver Banner
  Widget _buildBluetoothStreamBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2340),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8963E), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bluetooth Status Row
          Row(
            children: [
              // Animated Pulse Status Pill
              InkWell(
                onTap: () {
                  setState(() {
                    _isBleConnected = !_isBleConnected;
                    _isStreamingActive = _isBleConnected;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isBleConnected ? const Color(0xFF166534) : const Color(0xFFB91C1C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isBleConnected ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isBleConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isBleConnected ? 'BLE SCALE CONNECTED' : 'SCALE DISCONNECTED',
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _bleDeviceName,
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Live Reading LCD Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF22C55E)),
                ),
                child: Text(
                  '[ ${_liveBleWeight.toStringAsFixed(1)} ${_config.unit.symbol} ]',
                  style: const TextStyle(
                    color: Color(0xFF4ADE80),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFF334155)),
          const SizedBox(height: 10),

          // Quick-Fill Sample Batch Simulator & Stream Controls
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Automated BLE Stream Ingestion',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _isStreamingActive ? 'Ready to receive stable load-cell weights directly from platform.' : 'Stream paused.',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _zeroBleScale,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFCBD5E1),
                  side: const BorderSide(color: Color(0xFF64748B)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.exposure_zero_rounded, size: 13),
                label: const Text('Tare/Zero', style: TextStyle(fontSize: 10.5)),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: _streamNextBleWeight,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: const Color(0xFF020617),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.download_rounded, size: 14),
                label: const Text('Capture Reading', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom Stepper Action Buttons
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
                ),
                child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_currentStep == 0) {
                  _updateConfig();
                  setState(() => _currentStep = 1);
                } else if (_currentStep == 1) {
                  _calculateAndProceedToResults();
                } else {
                  _attachToLotMemoAndGeneratePdf();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
              ),
              icon: Icon(
                _currentStep == 2 ? Icons.picture_as_pdf_rounded : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(
                _currentStep == 0
                    ? 'Proceed to Weight Entry'
                    : (_currentStep == 1 ? 'Compute Statistical Lot Metrics' : 'Attach to Lot Memo & Generate PDF'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
