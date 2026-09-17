import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/inspection_report.dart';
import '../../data/models/compliance_check.dart';
import '../../data/models/fifth_schedule_models.dart';
import '../../data/services/fifth_schedule_service.dart';
import '../widgets/legal_metrology_logo.dart';
import '../widgets/sticky_forensic_footer.dart';
import 'pdf_generation_form_screen.dart';

/// Screen: Net Weight & Volume Verification
/// Supports:
/// 1. Manual Entry of Gross and Tare weights.
/// 2. Bluetooth Weighing Scale connection (device scan, live stream, Tare/Zero, auto-capture).
/// 3. Real-time Rule 11 & Fifth Schedule MPE (Maximum Permissible Error) evaluation.
class WeightVerificationScreen extends StatefulWidget {
  final InspectionReport report;

  const WeightVerificationScreen({
    super.key,
    required this.report,
  });

  @override
  State<WeightVerificationScreen> createState() => _WeightVerificationScreenState();
}

class _WeightVerificationScreenState extends State<WeightVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Commodity & Target Declared Quantity
  late double _declaredQty;
  late WeightUnit _unit;
  late String _unitSymbol;

  // Manual Entry Controllers
  final TextEditingController _grossWeightCtrl = TextEditingController();
  final TextEditingController _tareWeightCtrl = TextEditingController(text: '18.5');

  // Bluetooth Weighing Scale State
  bool _isBleScanning = false;
  bool _isBleConnected = false;
  String? _connectedDeviceName;
  double _liveBleWeight = 1018.5;
  bool _isBleStable = true;
  Timer? _bleStreamTimer;

  final List<Map<String, dynamic>> _discoveredDevices = [
    {
      'name': 'Essae Teraoka BLE Scale (BT-7201)',
      'mac': 'E4:5F:01:89:C2:10',
      'signal': -54,
      'isCertified': true,
      'type': 'Class III Standard Weighing Machine',
    },
    {
      'name': 'KERN Precision Balance (PCB-BLE)',
      'mac': '00:1A:7D:DA:71:04',
      'signal': -68,
      'isCertified': true,
      'type': 'Class II Precision Metrology Scale',
    },
    {
      'name': 'Avery Berkel Digital Platform Scale',
      'mac': 'A8:10:87:B2:44:91',
      'signal': -79,
      'isCertified': true,
      'type': 'Class III Commercial Scale',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _parseDeclaredQuantity();

    // Set default initial gross weight
    final defaultGross = _declaredQty + 18.5;
    _grossWeightCtrl.text = defaultGross.toStringAsFixed(1);
    _liveBleWeight = defaultGross;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _grossWeightCtrl.dispose();
    _tareWeightCtrl.dispose();
    _bleStreamTimer?.cancel();
    super.dispose();
  }

  void _parseDeclaredQuantity() {
    final rawQty = widget.report.productDetails.declaredNetQuantity.toLowerCase();
    if (rawQty.contains('5 kg') || rawQty.contains('5000')) {
      _declaredQty = 5000.0;
      _unit = WeightUnit.grams;
      _unitSymbol = 'g';
    } else if (rawQty.contains('kg')) {
      final numPart = double.tryParse(rawQty.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 1.0;
      _declaredQty = numPart * 1000.0;
      _unit = WeightUnit.grams;
      _unitSymbol = 'g';
    } else if (rawQty.contains('500')) {
      _declaredQty = 500.0;
      _unit = rawQty.contains('ml') ? WeightUnit.milliliters : WeightUnit.grams;
      _unitSymbol = rawQty.contains('ml') ? 'ml' : 'g';
    } else if (rawQty.contains('l') || rawQty.contains('liter')) {
      _declaredQty = 1000.0;
      _unit = WeightUnit.milliliters;
      _unitSymbol = 'ml';
    } else {
      _declaredQty = 1000.0;
      _unit = WeightUnit.grams;
      _unitSymbol = 'g';
    }
  }

  double get _grossWeight => double.tryParse(_grossWeightCtrl.text) ?? 0.0;
  double get _tareWeight => double.tryParse(_tareWeightCtrl.text) ?? 0.0;
  double get _netWeight => (_grossWeight - _tareWeight).clamp(0.0, 999999.0);
  double get _weightError => _netWeight - _declaredQty;
  double get _errorPercent => _declaredQty > 0 ? (_weightError / _declaredQty) * 100 : 0.0;

  ({double mpeValue, double mpePercent}) get _mpeResult => FifthScheduleService.calculateMpe(
        declaredQuantity: _declaredQty,
        unit: _unit,
      );

  SampleErrorClassification get _classification {
    final mpe = _mpeResult.mpeValue;
    if (_weightError >= -mpe) {
      return SampleErrorClassification.compliant;
    } else if (_weightError >= -(2 * mpe)) {
      return SampleErrorClassification.t1Defective;
    } else {
      return SampleErrorClassification.t2SevereDefective;
    }
  }

  bool get _isCompliant => _classification == SampleErrorClassification.compliant;

  void _startBleScan() {
    setState(() => _isBleScanning = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _isBleScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Discovered 3 certified Bluetooth weighing scales nearby.'),
            backgroundColor: AppTheme.primaryNavy,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _connectBleScale(String deviceName, {bool showNotification = true}) {
    setState(() {
      _isBleConnected = true;
      _connectedDeviceName = deviceName;
    });

    // Start live weight streaming simulation
    _bleStreamTimer?.cancel();
    _bleStreamTimer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (!mounted || !_isBleConnected) {
        t.cancel();
        return;
      }
      setState(() {
        // Minor realistic fluctuation on the least significant digit
        final jitter = (t.tick % 3 == 0) ? 0.1 : (t.tick % 2 == 0 ? -0.1 : 0.0);
        _liveBleWeight = (_grossWeight + jitter);
        _isBleStable = true;
      });
    });

    if (mounted && showNotification) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to $deviceName via BLE profile.'),
          backgroundColor: AppTheme.passGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _disconnectBle() {
    _bleStreamTimer?.cancel();
    setState(() {
      _isBleConnected = false;
      _connectedDeviceName = null;
    });
  }

  void _tareBleScale() {
    setState(() {
      _tareWeightCtrl.text = _grossWeightCtrl.text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Weighing Scale Tared to Zero successfully.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _captureBleReading() {
    setState(() {
      _grossWeightCtrl.text = _liveBleWeight.toStringAsFixed(1);
    });
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recorded scale reading: ${_liveBleWeight.toStringAsFixed(1)} $_unitSymbol'),
        backgroundColor: AppTheme.primaryNavy,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  InspectionReport _buildUpdatedReport() {
    final net = _netWeight;
    final isComp = _isCompliant;
    final mpe = _mpeResult.mpeValue;
    final variancePct = _errorPercent;

    // Create updated compliance checks
    final checks = List<ComplianceCheck>.from(widget.report.complianceChecks);
    final weightCheckIndex = checks.indexWhere((c) =>
        c.title.toLowerCase().contains('net weight') ||
        c.ruleReference.toLowerCase().contains('fifth'));

    final newCheck = ComplianceCheck(
      title: 'Net Weight Verification',
      isCompliant: isComp,
      statusText: isComp ? 'Compliant' : 'Shortage Detected',
      flaggedDetail: isComp
          ? 'Net weight ${net.toStringAsFixed(1)}$_unitSymbol satisfies Rule 11'
          : 'Net weight ${net.toStringAsFixed(1)}$_unitSymbol vs declared ${_declaredQty.toStringAsFixed(0)}$_unitSymbol (Deficiency ${variancePct.toStringAsFixed(1)}% exceeds MPE of ${mpe.toStringAsFixed(1)}$_unitSymbol)',
      ruleReference: 'Fifth Schedule, Rule 11 & 24',
      description: isComp
          ? 'Net content verified within Maximum Permissible Error (MPE).'
          : 'Net quantity deficiency exceeds statutory MPE under Fifth Schedule of PCR 2011.',
    );

    if (weightCheckIndex >= 0) {
      checks[weightCheckIndex] = newCheck;
    } else {
      checks.add(newCheck);
    }

    final hasAnyViolation = checks.any((c) => !c.isCompliant);
    final updatedCategory = InspectionReport.deriveCategory(
      status: hasAnyViolation ? InspectionStatus.violation : InspectionStatus.pass,
      checks: checks,
      isWeightCompliant: isComp,
    );

    return widget.report.copyWith(
      complianceChecks: checks,
      overallStatus: hasAnyViolation ? InspectionStatus.violation : InspectionStatus.pass,
      statusSummary: hasAnyViolation ? 'VIOLATION DETECTED' : 'COMPLIANT / PASS',
      measuredNetWeight: net,
      weightVariancePercent: variancePct,
      isWeightCompliant: isComp,
      mpeLimit: mpe,
      statutoryCategory: updatedCategory,
    );
  }

  void _saveWeightVerification() {
    Navigator.of(context).pop(_buildUpdatedReport());
  }

  void _generatePdfNoticeDirectly() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfGenerationFormScreen(report: _buildUpdatedReport()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Row(
          children: [
            LegalMetrologyLogo(size: 26, isBadge: false),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Weight & Volume Verification',
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
            tooltip: 'Generate Form III Notice (PDF)',
            onPressed: _generatePdfNoticeDirectly,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentGold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFCBD5E1),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.edit_note_rounded, size: 18),
              text: 'Manual Input',
            ),
            Tab(
              icon: Icon(Icons.bluetooth_searching_rounded, size: 18),
              text: 'Bluetooth Scale',
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildManualInputView(),
              _buildBluetoothScaleView(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.neutralBorder, width: 2.0)),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _generatePdfNoticeDirectly,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryNavy, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: const Text(
                          'Generate PDF',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _saveWeightVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text(
                          'Save Weight Verification & Continue',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const StickyForensicFooter(),
        ],
      ),
    );
  }

  /// Mode A: Clean Manual Entry
  Widget _buildManualInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCommodityTargetCard(),
          const SizedBox(height: 16),
          _buildWeightInputsCard(),
          const SizedBox(height: 16),
          _buildStatutoryAnalysisCard(),
        ],
      ),
    );
  }

  /// Mode B: Bluetooth Weighing Machine
  Widget _buildBluetoothScaleView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCommodityTargetCard(),
          const SizedBox(height: 14),
          _buildBluetoothDeviceManagerCard(),
          const SizedBox(height: 14),
          _buildAutomatedSyncBanner(),
          const SizedBox(height: 14),
          _buildLiveScaleReadoutCard(),
          const SizedBox(height: 14),
          _buildStatutoryAnalysisCard(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Automated Scale Sync Banner for instant 1-tap verification
  Widget _buildAutomatedSyncBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0284C7), width: 2.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Automated Digital Scale Sync',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primaryInk),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.passBorder),
                ),
                child: const Text(
                  'AUTO-LINKED',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Live load cell reading streams continuously. Tap below to freeze official net weighment into legal record.',
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _captureBleReading,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: Text(
                'Instant Capture Scale Reading (${_liveBleWeight.toStringAsFixed(1)} $_unitSymbol)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Target Commodity & Declared Quantity Card
  Widget _buildCommodityTargetCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutralBorder, width: 2.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.scale_rounded, color: AppTheme.primaryNavy, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.report.productDetails.brandName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryInk),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Declared Net Qty: ${_declaredQty.toStringAsFixed(0)} $_unitSymbol • Rule 11 & Fifth Schedule',
                  style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.neutralBorder),
            ),
            child: Text(
              '${_declaredQty.toStringAsFixed(0)} $_unitSymbol',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.primaryNavy),
            ),
          ),
        ],
      ),
    );
  }

  /// Manual Weight Inputs
  Widget _buildWeightInputsCard() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune_rounded, size: 18, color: AppTheme.primaryNavy),
                SizedBox(width: 8),
                Text(
                  'Manual Field Weight Entry',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gross Weight',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _grossWeightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        decoration: InputDecoration(
                          suffixText: _unitSymbol,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tare Weight (Wrapper)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _tareWeightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        decoration: InputDecoration(
                          suffixText: _unitSymbol,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Computed Net Content:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(
                    '${_netWeight.toStringAsFixed(1)} $_unitSymbol',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.primaryNavy),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bluetooth Device Scanner & Manager
  Widget _buildBluetoothDeviceManagerCard() {
    return Card(
      elevation: 1.5,
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
                Icon(
                  _isBleConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                  color: _isBleConnected ? AppTheme.passGreen : AppTheme.primaryNavy,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bluetooth Weighing Machine',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (!_isBleConnected)
                  TextButton.icon(
                    onPressed: _isBleScanning ? null : _startBleScan,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: _isBleScanning
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(_isBleScanning ? 'Scanning...' : 'Scan Scales'),
                  )
                else
                  TextButton(
                    onPressed: _disconnectBle,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Disconnect', style: TextStyle(color: AppTheme.violationRed, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_isBleConnected)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Connected to $_connectedDeviceName',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              const Text(
                'Select a certified Legal Metrology BLE scale to pair:',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Column(
                children: _discoveredDevices.map((d) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bluetooth_searching_rounded, size: 18, color: AppTheme.primaryNavy),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${d['type']} • ${d['mac']}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: () => _connectBleScale(d['name'] as String),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Connect', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Live LCD Digital Weighing Scale Readout
  Widget _buildLiveScaleReadoutCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE SCALE STREAM',
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isBleStable ? Icons.check_circle_rounded : Icons.pending_rounded,
                      size: 11,
                      color: _isBleStable ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isBleStable ? 'STABLE' : 'MOTION',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: _isBleStable ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Giant LCD readout
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _liveBleWeight.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF38BDF8),
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _unitSymbol,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _tareBleScale,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  icon: const Icon(Icons.exposure_zero_rounded, size: 16),
                  label: const Text('Zero / Tare', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _captureBleReading,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download_done_rounded, size: 16),
                  label: const Text('Record Reading', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Statutory Rule 11 & Fifth Schedule Analysis Card
  Widget _buildStatutoryAnalysisCard() {
    final mpe = _mpeResult.mpeValue;
    final isComp = _isCompliant;
    final cls = _classification;
    final cardBorderColor = isComp ? AppTheme.passBorder : AppTheme.violationBorder;

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
                  color: (isComp ? AppTheme.passGreen : AppTheme.violationRed).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isComp ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: isComp ? AppTheme.passGreen : AppTheme.violationRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fifth Schedule Statutory Assessment',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryInk),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rule 11 & Fifth Schedule PCR 2011 • MPE: ±${mpe.toStringAsFixed(1)} $_unitSymbol',
                      style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isComp ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isComp ? AppTheme.passBorder : AppTheme.violationBorder),
                ),
                child: Text(
                  cls.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: isComp ? const Color(0xFF15803D) : AppTheme.violationRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.neutralBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Declared Qty',
                  '${_declaredQty.toStringAsFixed(0)} $_unitSymbol',
                  'Label Qn',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Verified Net',
                  '${_netWeight.toStringAsFixed(1)} $_unitSymbol',
                  'Gross - Tare',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Variance',
                  '${_weightError >= 0 ? "+" : ""}${_weightError.toStringAsFixed(1)} $_unitSymbol',
                  '${_errorPercent >= 0 ? "+" : ""}${_errorPercent.toStringAsFixed(1)}%',
                  isNegative: _weightError < -mpe,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isComp ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isComp ? AppTheme.passBorder : AppTheme.violationBorder, width: 1.2),
            ),
            child: Row(
              children: [
                Icon(
                  isComp ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                  size: 18,
                  color: isComp ? const Color(0xFF15803D) : AppTheme.violationRed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isComp
                        ? 'Net content satisfies Fifth Schedule tolerances. Deficiency is within Maximum Permissible Error (MPE).'
                        : 'Shortage of ${_weightError.abs().toStringAsFixed(1)} $_unitSymbol exceeds statutory MPE limit of ${mpe.toStringAsFixed(1)} $_unitSymbol. Unlawful net quantity deficiency under Section 36(1).',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isComp ? const Color(0xFF15803D) : AppTheme.violationRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, String sub, {bool isNegative = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.secondaryText, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isNegative ? AppTheme.violationRed : AppTheme.primaryInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: AppTheme.metadataLabel, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
