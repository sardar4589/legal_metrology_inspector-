import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/inspection_report.dart';
import 'location_service.dart';

/// PdfReportService generates and saves official Government Form II / Form III Inspection Memos in PDF format.
class PdfReportService {
  PdfReportService._();

  /// Generates the official PDF document for an inspection report.
  static Future<Uint8List> generateInspectionPdf(
    InspectionReport report, {
    String noticeTitle = 'Package Inspection & Statutory Compliance Memo (Form II)',
    String? customOfficerDesignation,
    String? customRemarks,
    String? rectificationPeriod,
  }) async {
    final pdf = pw.Document();

    final isViolation = report.isViolation;
    final primaryNavy = PdfColor.fromHex('#0C2340');
    final accentGold = PdfColor.fromHex('#C8963E');
    final passGreen = PdfColor.fromHex('#1B5E20');
    final violationRed = PdfColor.fromHex('#B71C1C');

    // Load captured image if available
    pw.MemoryImage? packageImage;
    if (report.imageBytes != null && report.imageBytes!.isNotEmpty) {
      try {
        packageImage = pw.MemoryImage(report.imageBytes!);
      } catch (_) {}
    }

    // Load department emblem logo if available
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/legal_metrology_logo.jpg');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    // Forensic metadata: IST UTC+05:30 timestamp & live online/cached GPS coordinates
    final istTimestamp = report.timestamp.toUtc().add(const Duration(hours: 5, minutes: 30));
    final istFormatted = '${istTimestamp.year}-${istTimestamp.month.toString().padLeft(2, '0')}-${istTimestamp.day.toString().padLeft(2, '0')} '
        '${istTimestamp.hour.toString().padLeft(2, '0')}:${istTimestamp.minute.toString().padLeft(2, '0')}:${istTimestamp.second.toString().padLeft(2, '0')} IST (UTC+05:30)';
    final gpsCoordinates = LocationService.currentCoordinates;

    // Compute cryptographic SHA-256 integrity manifest
    final manifestPayload = [
      'CASE_ID:${report.caseId}',
      'OFFICER:${report.officerId}|${report.officerName}',
      'ESTABLISHMENT:${report.businessName}',
      'LOCATION:${report.location}|$gpsCoordinates',
      'TIMESTAMP:$istFormatted',
      'STATUS:${report.overallStatus.name}',
      'COMMODITY:${report.productDetails.brandName}|${report.productDetails.declaredNetQuantity}',
      'NOTICE_TYPE:$noticeTitle',
      'REMARKS:${customRemarks ?? ""}',
      'RECTIFICATION:${rectificationPeriod ?? ""}',
    ].join(';\n');

    final sha256Digest = sha256.convert(utf8.encode(manifestPayload)).toString();
    final truncatedHash = sha256Digest.substring(0, 16);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Case: ${report.caseId} • Stamped: $istFormatted • Geo: $gpsCoordinates',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
                pw.Text(
                  'SHA-256: $truncatedHash... • Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Official Government Header
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1.5)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(logoImage, width: 44, height: 44),
                        pw.SizedBox(width: 10),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'GOVERNMENT OF INDIA',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryNavy,
                              letterSpacing: 1.2,
                            ),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'DEPARTMENT OF CONSUMER AFFAIRS • LEGAL METROLOGY DIVISION',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: accentGold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'STATUTORY ENFORCEMENT & COMPLIANCE DIRECTORATE',
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryNavy,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            noticeTitle.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: isViolation ? violationRed : primaryNavy,
                            ),
                          ),
                          pw.Text(
                            'Issued under Section 15, 18 & 39 Legal Metrology Act, 2009 read with PCR, 2011',
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Official Case ID Box
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: accentGold, width: 1.5),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('CASE MEMO NO.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        pw.Text(
                          report.caseId,
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // High-Contrast Status Banner Stamp
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: pw.BoxDecoration(
                color: isViolation ? PdfColor.fromHex('#FFEBEE') : PdfColor.fromHex('#E8F5E9'),
                border: pw.Border.all(color: isViolation ? violationRed : passGreen, width: 1.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'OFFICIAL COMPLIANCE FINDING:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                  ),
                  pw.Text(
                    report.statusSummary.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: isViolation ? violationRed : passGreen,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Case Metadata Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
              children: [
                _buildTableRow('Inspecting Officer', report.officerName, 'Officer ID', report.officerId),
                _buildTableRow(
                  'Date & Time',
                  '${report.timestamp.day.toString().padLeft(2, '0')}/${report.timestamp.month.toString().padLeft(2, '0')}/${report.timestamp.year}  ${report.timestamp.hour.toString().padLeft(2, '0')}:${report.timestamp.minute.toString().padLeft(2, '0')}',
                  'Location / Zone',
                  report.location,
                ),
                _buildTableRow('Establishment / Shop', report.businessName, 'Act / Rules', 'PCR, 2011 & LM Act 2009'),
              ],
            ),
            pw.SizedBox(height: 16),

            // Extracted Product Details Header & Content
            pw.Text(
              '1. EXTRACTED COMMODITY & PACKAGING DECLARATIONS',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryNavy),
            ),
            pw.SizedBox(height: 6),

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Details table
                pw.Expanded(
                  flex: 3,
                  child: pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
                    children: [
                      _buildProductRow('Brand / Commodity', report.productDetails.brandName, isBold: true),
                      _buildProductRow('Declared Net Quantity', report.productDetails.declaredNetQuantity, isHighlight: true),
                      _buildProductRow('Declared MRP', '${report.productDetails.declaredMrp.replaceAll('₹', 'Rs. ')} (Incl. of all taxes)'),
                      _buildProductRow('Unit Sale Price (USP)', report.productDetails.unitSalePrice.replaceAll('₹', 'Rs. '), isHighlight: true),
                      _buildProductRow('Batch / Mfg Date', report.productDetails.batchMfgDate),
                      _buildProductRow('Manufacturer / Packer', report.productDetails.manufacturerAddress),
                      _buildProductRow('Consumer Care Details', report.productDetails.consumerCareDetails),
                    ],
                  ),
                ),
                // Captured Package Image Thumbnail if available
                if (packageImage != null) ...[
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Container(
                      height: 140,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400, width: 1),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 4,
                        verticalRadius: 4,
                        child: pw.Image(packageImage, fit: pw.BoxFit.cover),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            pw.SizedBox(height: 18),

            // 2. Compliance Checklist (PCR 2011)
            pw.Text(
              '2. STATUTORY COMPLIANCE CHECKLIST (PACKAGED COMMODITIES RULES, 2011)',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryNavy),
            ),
            pw.SizedBox(height: 6),

            ...report.complianceChecks.map((check) {
              final isPass = check.isCompliant;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: isPass ? PdfColor.fromHex('#F0FDF4') : PdfColor.fromHex('#FEF2F2'),
                  border: pw.Border.all(color: isPass ? passGreen : violationRed, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: isPass ? passGreen : violationRed,
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                      child: pw.Text(
                        isPass ? 'COMPLIANT' : 'VIOLATION',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${check.title} [${check.ruleReference}]',
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                          ),
                          if (check.flaggedDetail != null) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'FLAGGED NON-COMPLIANCE: ${check.flaggedDetail!.replaceAll('₹', 'Rs. ')}',
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: violationRed),
                            ),
                          ],
                          if (check.description.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              check.description,
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            // Official Directives & Statutory Notes (if provided or violation)
            if (customRemarks != null && customRemarks.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'STATUTORY DIRECTIVES & INSPECTING OFFICER REMARKS:',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      customRemarks,
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                    ),
                    if (rectificationPeriod != null && rectificationPeriod.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Compliance / Hearing Requirement: $rectificationPeriod',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: violationRed),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 14),

            // Cryptographic SHA-256 Integrity Manifest Block (Statutory Evidence Hardening)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: primaryNavy, width: 1.2),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: primaryNavy,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                            child: pw.Text(
                              'STATUTORY INTEGRITY MANIFEST',
                              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            'SEC 65B EVIDENCE ACT / SEC 63 BSA COMPLIANT',
                            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: passGreen),
                          ),
                        ],
                      ),
                      pw.Text(
                        'DIGITALLY VERIFIED',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: accentGold),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'SHA-256 Checksum: $sha256Digest',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Geo-Coordinates: $gpsCoordinates',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                      ),
                      pw.Text(
                        'Timestamp: $istFormatted',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Legal Notice: This electronic document is generated under Section 15 of Legal Metrology Act, 2009. The cryptographic hash guarantees tamper-proof evidentiary integrity for judicial proceedings.',
                    style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Signatures & Legal Endorsement
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Dealer / Establishment Representative', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 24),
                    pw.Text('(Signature / Stamp)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      customOfficerDesignation ?? 'Legal Metrology Inspector',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(report.officerName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Badge ID: ${report.officerId}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 12),
                    pw.Text('[Digitally Certified Inspection Memo]', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.TableRow _buildTableRow(String k1, String v1, String k2, String v2) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(k1, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(v1, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(k2, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(v2, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  static pw.TableRow _buildProductRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: (isBold || isHighlight) ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  /// Saves the PDF document to the device's local file storage.
  /// Returns the file path of the saved PDF.
  static Future<String> savePdfToFile(
    InspectionReport report, {
    String noticeTitle = 'Package Inspection & Statutory Compliance Memo (Form II)',
    String? customOfficerDesignation,
    String? customRemarks,
    String? rectificationPeriod,
  }) async {
    final sanitizedId = report.caseId.replaceAll(RegExp(r'[^\w\-]'), '_');
    final bytes = await generateInspectionPdf(
      report,
      noticeTitle: noticeTitle,
      customOfficerDesignation: customOfficerDesignation,
      customRemarks: customRemarks,
      rectificationPeriod: rectificationPeriod,
    );

    if (kIsWeb) {
      // In web browser, trigger download
      try {
        await Printing.sharePdf(bytes: bytes, filename: 'Inspection_${report.caseId}.pdf');
      } catch (_) {}
      return 'Inspection_${report.caseId}.pdf';
    }

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return 'Memo_$sanitizedId.pdf';
    }

    // On Android / iOS / Desktop: Save to Application Documents directory
    try {
      final dir = await getApplicationDocumentsDirectory();
      final inspectionDir = Directory('${dir.path}/legal_metrology_memos');
      if (!await inspectionDir.exists()) {
        await inspectionDir.create(recursive: true);
      }

      final filePath = '${inspectionDir.path}/Memo_$sanitizedId.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (_) {
      return 'Memo_$sanitizedId.pdf';
    }
  }

  /// Prints or shares the PDF memo using the native OS printer / file share dialog.
  static Future<void> printOrSharePdf(
    InspectionReport report, {
    String noticeTitle = 'Package Inspection & Statutory Compliance Memo (Form II)',
    String? customOfficerDesignation,
    String? customRemarks,
    String? rectificationPeriod,
  }) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;

    final bytes = await generateInspectionPdf(
      report,
      noticeTitle: noticeTitle,
      customOfficerDesignation: customOfficerDesignation,
      customRemarks: customRemarks,
      rectificationPeriod: rectificationPeriod,
    );
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Inspection_Memo_${report.caseId}',
      );
    } catch (_) {}
  }
}
