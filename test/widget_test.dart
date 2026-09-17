import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_metrology_inspector/main.dart';
import 'package:legal_metrology_inspector/ui/screens/login_screen.dart';
import 'package:legal_metrology_inspector/ui/screens/home_screen.dart';
import 'package:legal_metrology_inspector/ui/screens/ar_viewfinder_screen.dart';
import 'package:legal_metrology_inspector/ui/screens/report_screen.dart';
import 'package:legal_metrology_inspector/data/models/inspection_report.dart';
import 'package:legal_metrology_inspector/ui/screens/pdf_generation_form_screen.dart';
import 'package:legal_metrology_inspector/ui/screens/capture_screen.dart';
import 'package:legal_metrology_inspector/ui/screens/statutory_audit_screen.dart';
import 'package:legal_metrology_inspector/ui/screens/weight_verification_screen.dart';
import 'package:legal_metrology_inspector/ui/screens/logs_screen.dart';
import 'package:legal_metrology_inspector/ui/screens/fifth_schedule_wizard_screen.dart';
import 'package:legal_metrology_inspector/ui/widgets/legal_metrology_logo.dart';

void main() {
  testWidgets('Full Inspection Flow Smoke & Navigation Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Launch App
    await tester.pumpWidget(const LegalMetrologyInspectorApp());
    await tester.pumpAndSettle();

    // Verify Screen 1: Login Screen is displayed
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Legal Metrology Department'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byIcon(Icons.balance_rounded), findsOneWidget);

    // Tap "Sign In"
    final signInFinder = find.text('Sign In');
    await tester.ensureVisible(signInFinder);
    await tester.tap(signInFinder);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Verify Screen 2: Clean Home Screen is displayed
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Inspector R. Sharma'), findsWidgets);
    expect(find.text('+ Start New Inspection'), findsOneWidget);
    expect(find.text('Statutory Enforcement Authority'), findsOneWidget);
    expect(find.text('Case Logs'), findsWidgets);
    expect(find.text('Rules & Act'), findsWidgets);

    // Tap on "+ Start New Inspection" to open Capture Screen
    final startInspectionFinder = find.text('+ Start New Inspection');
    await tester.ensureVisible(startInspectionFinder);
    await tester.tap(startInspectionFinder);
    await tester.pumpAndSettle();

    // Verify Capture Screen (Title and Camera/Gallery options, NO auto popup)
    expect(find.text('Capture & Automated Inspection'), findsOneWidget);
    expect(find.text('Capture via Camera'), findsOneWidget);
    expect(find.text('Select from Device Gallery'), findsOneWidget);
    expect(find.text('Use Sample Test Package (GoodLife Oil 1L)'), findsNothing);

    // Test Navigation to Tab 1: Case Logs directly
    final backFinder = find.byIcon(Icons.arrow_back_ios_new_rounded);
    await tester.tap(backFinder);
    await tester.pumpAndSettle();

    final logsTabFinder = find.text('Case Logs').first;
    await tester.ensureVisible(logsTabFinder);
    await tester.tap(logsTabFinder);
    await tester.pumpAndSettle();

    // Verify Inspection Case Logs Screen
    expect(find.text('Inspection Case Logs'), findsOneWidget);
    expect(find.text('Total Audited'), findsOneWidget);

    // Verify Navigation to Tab 2: Rules & Act
    final rulesTabFinder = find.text('Rules & Act').first;
    await tester.ensureVisible(rulesTabFinder);
    await tester.tap(rulesTabFinder);
    await tester.pumpAndSettle();

    // Verify Rules & Act Screen
    expect(find.text('Legal Metrology Rules & Act'), findsOneWidget);
    expect(find.text('Standard Weights & Measures Enforcement'), findsOneWidget);
    expect(find.text('Rule 9(1) & Table-I'), findsOneWidget);
    expect(find.text('Mandatory Font Height Schedule (Table-I)'), findsOneWidget);
  });

  testWidgets('Modular Flow: Capture Screen to Dedicated Statutory Audit Page Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Launch CaptureScreen directly with simulated package
    await tester.pumpWidget(
      const MaterialApp(
        home: CaptureScreen(
          initialSampleTag: 'goodlife_oil',
          autoLaunchCamera: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 1. Verify On-Page Framing Quality Report & Retake
    expect(find.text('PERFECT FRAME'), findsWidgets);
    expect(find.text('Package Framing & Clarity Report'), findsOneWidget);
    expect(find.text('Retake Photo / Scan Another Package'), findsOneWidget);

    // 2. Verify Shape Detection & Multi-Angle Accuracy
    expect(find.textContaining('SHAPE DETECTED:'), findsOneWidget);
    expect(find.textContaining('Multi-Angle Capture Accuracy'), findsWidgets);
    expect(find.textContaining('PROPER & ACCURATE'), findsWidgets);
    expect(find.textContaining('95%'), findsWidgets);

    // 3. User Requirement: "automated AI font sizing Audit and other things which are down side should be on next page"
    // On CaptureScreen itself, downside cards are replaced with clean Proceed CTA
    expect(find.text('Proceed to Automated AI Statutory Audit →'), findsOneWidget);

    // Tap "Proceed to Automated AI Statutory Audit →"
    final proceedFinder = find.text('Proceed to Automated AI Statutory Audit →');
    await tester.ensureVisible(proceedFinder);
    await tester.tap(proceedFinder);
    await tester.pumpAndSettle();

    // 4. Verify Dedicated StatutoryAuditScreen is displayed
    expect(find.byType(StatutoryAuditScreen), findsOneWidget);
    expect(find.text('Statutory Audit Report'), findsOneWidget);
    expect(find.text('Automated AI Font Sizing Audit'), findsOneWidget);
    expect(find.text('1.8 mm'), findsOneWidget);
    expect(find.text('≥ 3.0 mm'), findsOneWidget);
    expect(find.text('NON-COMPLIANT'), findsWidgets);

    // Extracted Statutory Product Declarations (Rule 6 PCR 2011)
    expect(find.text('Extracted Product Declarations'), findsOneWidget);
    expect(find.text('GoodLife Refined Oil'), findsWidgets);
    expect(find.text('1 L'), findsWidgets);
    expect(find.text('₹145.00'), findsWidgets);

    // Compliance Checklist
    expect(find.text('Compliance Checklist (PCR, 2011)'), findsOneWidget);

    // Action Buttons on StatutoryAuditScreen: Only Generate Notice (PDF) is present
    expect(find.text('Generate Notice (PDF)'), findsOneWidget);
    expect(find.text('Open AR Font Caliper Page'), findsNothing);
    expect(find.text('Save to Case Logs'), findsNothing);
    expect(find.text('Print Notice'), findsNothing);

    // Tap "Generate Notice (PDF)" -> Verifies opening dedicated PDF generator page
    final generatePdfFinder = find.text('Generate Notice (PDF)');
    await tester.ensureVisible(generatePdfFinder);
    await tester.tap(generatePdfFinder);
    await tester.pumpAndSettle();

    expect(find.byType(PdfGenerationFormScreen), findsOneWidget);
    expect(find.text('Statutory Memo & Notice Generator'), findsOneWidget);

    // Navigate back to StatutoryAuditScreen
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('AR Viewfinder Shutter Button, Direct Camera & Clean Borders Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ArViewfinderScreen(
          initialSampleTag: 'goodlife_oil',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Rule 24 PDP Overlay
    expect(find.text('AR Viewfinder & Font Caliper'), findsOneWidget);
    expect(find.text('Rule 24 PCR 2011 • Principal Display Panel'), findsOneWidget);
    expect(find.text('PDP LOCKED'), findsWidgets);

    // Verify Visual Font Caliper Widget
    expect(find.text('OPTICAL FONT CALIPER'), findsOneWidget);
    expect(find.text('DEFICIENT'), findsWidgets);
    expect(find.text('1.8'), findsOneWidget);

    expect(find.text('Open Camera'), findsWidgets);
    expect(find.text('Apply Caliper'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
  });

  testWidgets('Clean Emblem Logo & 4D Guided Angle Tabs Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(LegalMetrologyLogo), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: CaptureScreen(
          autoLaunchCamera: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Front PDP'), findsOneWidget);
    expect(find.text('Back View'), findsOneWidget);
    expect(find.text('Side Wrap'), findsOneWidget);
    expect(find.text('Flap/Date'), findsOneWidget);

    // Switch tabs
    await tester.tap(find.text('Back View'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Capture Back View'), findsOneWidget);
  });

  testWidgets('ReportScreen AR Font Caliper Image Slider & Multi-Angle Carousel Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockReport = InspectionReport.mockOilViolation();
    await tester.pumpWidget(MaterialApp(home: ReportScreen(report: mockReport)));
    await tester.pumpAndSettle();

    // User Requirement: "on the cliper page option of sliding the images whicher he captured"
    expect(find.text('AUTOMATED AR VISION INSPECTION'), findsOneWidget);
    expect(find.text('Front PDP'), findsWidgets);
    expect(find.text('Back View'), findsWidgets);
    expect(find.text('Side Wrap'), findsWidgets);
    expect(find.text('Flap/Date'), findsWidgets);

    // Slide to Next Angle using the Carousel Forward Button
    final nextAngleBtn = find.byTooltip('Next Angle');
    expect(nextAngleBtn, findsOneWidget);
    await tester.tap(nextAngleBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('BACK VIEW'), findsWidgets);

    // Tap Back to Front View
    final prevAngleBtn = find.byTooltip('Previous Angle');
    expect(prevAngleBtn, findsOneWidget);
    await tester.tap(prevAngleBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('FRONT VIEW'), findsWidgets);
  });

  testWidgets('Weight Verification Page: Manual Input, Bluetooth Scale & MPE Evaluation Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockReport = InspectionReport.mockOilViolation();
    await tester.pumpWidget(
      MaterialApp(
        home: WeightVerificationScreen(report: mockReport),
      ),
    );
    await tester.pumpAndSettle();

    // User Requirement: "add one more page where he can add the page where he can manually put the weight or he can connect the bluetooth weighing machin to it"
    expect(find.text('Weight & Volume Verification'), findsOneWidget);
    expect(find.text('Manual Input'), findsOneWidget);
    expect(find.text('Bluetooth Scale'), findsOneWidget);

    // Verify Manual Tab elements
    expect(find.text('Manual Field Weight Entry'), findsOneWidget);
    expect(find.text('Gross Weight'), findsOneWidget);
    expect(find.text('Tare Weight (Wrapper)'), findsOneWidget);
    expect(find.text('Fifth Schedule Statutory Assessment'), findsOneWidget);

    // Switch to Bluetooth Scale Tab
    final bleTab = find.text('Bluetooth Scale');
    await tester.tap(bleTab);
    await tester.pumpAndSettle();

    expect(find.text('Bluetooth Weighing Machine'), findsOneWidget);
    expect(find.text('Scan Scales'), findsOneWidget);
    expect(find.text('Essae Teraoka BLE Scale (BT-7201)'), findsOneWidget);

    // Connect to Scale
    final connectBtn = find.text('Connect').first;
    await tester.tap(connectBtn);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('Connected to Essae Teraoka BLE Scale'), findsWidgets);
    expect(find.text('LIVE SCALE STREAM'), findsOneWidget);
    expect(find.text('Record Reading'), findsOneWidget);
    expect(find.text('Zero / Tare'), findsOneWidget);

    // Save Weight Verification
    final saveBtn = find.text('Save Weight Verification & Continue');
    expect(saveBtn, findsOneWidget);
  });

  testWidgets('Case Logs Category-Wise Filtering Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: LogsScreen()));
    await tester.pumpAndSettle();

    // User Requirement: "it should saved in log categorywise"
    expect(find.byKey(const ValueKey('cat_filter_ALL')), findsOneWidget);
    expect(find.byKey(const ValueKey('cat_filter_FONT')), findsOneWidget);
    expect(find.byKey(const ValueKey('cat_filter_WEIGHT')), findsOneWidget);
    expect(find.byKey(const ValueKey('cat_filter_MRP')), findsOneWidget);
    expect(find.byKey(const ValueKey('cat_filter_COMPLIANT')), findsOneWidget);

    // Filter by Font Violations
    final fontChip = find.byKey(const ValueKey('cat_filter_FONT'));
    await tester.ensureVisible(fontChip);
    await tester.tap(fontChip);
    await tester.pumpAndSettle();
    expect(find.text('GoodLife Refined Oil'), findsOneWidget);

    // Filter by Weight Shortage
    final weightChip = find.byKey(const ValueKey('cat_filter_WEIGHT'));
    await tester.ensureVisible(weightChip);
    await tester.tap(weightChip);
    await tester.pumpAndSettle();
    expect(find.text('Assam Gold Premium CTC Tea'), findsOneWidget);

    // Filter by Compliant Packages
    final compChip = find.byKey(const ValueKey('cat_filter_COMPLIANT'));
    await tester.ensureVisible(compChip);
    await tester.tap(compChip);
    await tester.pumpAndSettle();
    expect(find.text('Puro Himalayan Pink Salt'), findsOneWidget);

    // Reset to All
    final allChip = find.byKey(const ValueKey('cat_filter_ALL'));
    await tester.ensureVisible(allChip);
    await tester.tap(allChip);
    await tester.pumpAndSettle();
    expect(find.text('Case Records (5)'), findsOneWidget);
  });

  testWidgets('Fifth Schedule Wizard Attach to Lot Memo directly opens PDF Generation Screen Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: FifthScheduleWizardScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Step 1 is open
    expect(find.text('Fifth Schedule Wizard'), findsOneWidget);
    expect(find.text('Proceed to Weight Entry'), findsOneWidget);

    // Proceed to Step 2
    await tester.tap(find.text('Proceed to Weight Entry'));
    await tester.pumpAndSettle();

    // Verify Step 2 is open
    expect(find.text('Compute Statistical Lot Metrics'), findsOneWidget);

    // Proceed to Step 3
    await tester.tap(find.text('Compute Statistical Lot Metrics'));
    await tester.pumpAndSettle();

    // Verify Step 3: LotMetricsDashboard is displayed with "Attach to Lot Memo & Generate PDF" button
    expect(find.text('Attach to Lot Memo & Generate PDF'), findsOneWidget);
    expect(find.text('Attach to Lot Memo'), findsOneWidget);

    // Tap "Attach to Lot Memo"
    await tester.tap(find.text('Attach to Lot Memo'));
    await tester.pumpAndSettle();

    // Verify PDF Generation Form Screen is opened directly
    expect(find.byType(PdfGenerationFormScreen), findsOneWidget);
    expect(find.text('Generate Statutory PDF Memo'), findsOneWidget);
  });

  testWidgets('Capture Screen Notification Pops up for 400ms on New Inspection', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: CaptureScreen(autoLaunchCamera: false),
      ),
    );
    // Pump post-frame callback
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // SnackBar should be present immediately
    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);
    expect(find.text('New Inspection: 4D package capture ready.'), findsOneWidget);

    // Verify statutory duration is strictly 0.4 seconds (400ms)
    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    expect(snackBar.duration, const Duration(milliseconds: 400));
  });
}
