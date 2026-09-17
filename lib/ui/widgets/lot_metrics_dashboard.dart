import 'package:flutter/material.dart';
import '../../data/models/fifth_schedule_models.dart';

/// Results dashboard view to display statistical lot metrics
/// (Mean, Standard Deviation, Corrected Average, and MPE PASS/FAIL status badges)
/// according to Rule 24 and the Fifth Schedule of PCR 2011.
///
/// Refactored for High-Contrast Field Readability:
/// - Pure white card surfaces with high-luminance contrast borders (WCAG AAA compliant)
/// - Bold key readouts >= 20sp (21sp/22sp, FontWeight.w900) for outdoor & harsh factory lighting
/// - High-contrast statutory decision indicators and criteria cards
class LotMetricsDashboard extends StatelessWidget {
  final StatisticalLotMetrics metrics;
  final VoidCallback? onExportPressed;
  final VoidCallback? onSaveToInspection;

  const LotMetricsDashboard({
    super.key,
    required this.metrics,
    this.onExportPressed,
    this.onSaveToInspection,
  });

  // High contrast field theme constants
  static const Color _contrastNavy = Color(0xFF0C2340);
  static const Color _contrastPass = Color(0xFF047857);
  static const Color _contrastPassBg = Color(0xFFECFDF5);
  static const Color _contrastViolation = Color(0xFFB91C1C);
  static const Color _contrastViolationBg = Color(0xFFFEF2F2);
  static const Color _contrastBorder = Color(0xFF94A3B8);
  static const Color _contrastLabel = Color(0xFF334155);

  @override
  Widget build(BuildContext context) {
    final isPass = metrics.isLotPassed;
    final statusColor = isPass ? _contrastPass : _contrastViolation;
    final statusBg = isPass ? _contrastPassBg : _contrastViolationBg;
    final unitSym = metrics.unit.symbol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Prominent Official Statutory Decision Banner (High Luminance Contrast)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withAlpha(80),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isPass ? Icons.verified_user_rounded : Icons.gavel_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPass ? 'MPE PASS — LOT APPROVED' : 'MPE FAIL — LOT REJECTED',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPass
                              ? 'Sample lot strictly meets the statutory net content criteria under Rule 24 of PCR 2011.'
                              : 'Lot fails statutory deficiency limits under Fifth Schedule. Seizure or compounding applicable.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: statusColor.withAlpha(70)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      metrics.legalCitation,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _contrastLabel,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPass ? 'SECTION 15 COMPLIANT' : 'SECTION 39 OFFENCE',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. High-Contrast Statistical Lot Metrics Grid (Bold Readouts >= 20sp)
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'SAMPLE MEAN (x̄)',
                value: '${metrics.sampleMean.toStringAsFixed(2)} $unitSym',
                subtext: 'Declared: ${metrics.declaredQuantity.toStringAsFixed(1)} $unitSym',
                icon: Icons.functions_rounded,
                accentColor: _contrastNavy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'STD DEVIATION (s)',
                value: '± ${metrics.standardDeviation.toStringAsFixed(2)} $unitSym',
                subtext: 'k = ${metrics.studentTFactor.toStringAsFixed(3)}',
                icon: Icons.stacked_line_chart_rounded,
                accentColor: const Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'CORRECTED AVERAGE',
                value: '${metrics.correctedAverage.toStringAsFixed(2)} $unitSym',
                subtext: metrics.isAverageCompliant ? '≥ Declared (Pass)' : '< Declared (Deficient)',
                icon: Icons.rule_rounded,
                accentColor: metrics.isAverageCompliant ? _contrastPass : _contrastViolation,
                isHighlight: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'MPE DEFECTIVES',
                value: 'T1: ${metrics.t1DefectiveCount}/${metrics.maxAllowedT1}',
                subtext: 'T2 (Severe): ${metrics.t2DefectiveCount} (Zero allowed)',
                icon: Icons.checklist_rtl_rounded,
                accentColor: metrics.isDefectivesCompliant ? _contrastPass : _contrastViolation,
                isHighlight: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 3. Statutory Lot Breakdown Card (High Contrast)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _contrastBorder, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.assessment_rounded, color: _contrastNavy, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Statutory Lot Compliance Criteria',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _contrastNavy,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildCriteriaRow(
                label: 'Criterion 1: Corrected Average (x̄ - ks ≥ Qn)',
                value: '${metrics.correctedAverage.toStringAsFixed(2)} vs ${metrics.declaredQuantity.toStringAsFixed(1)} $unitSym',
                isPass: metrics.isAverageCompliant,
                explanation: metrics.isAverageCompliant
                    ? 'The average net content of the sampled lot is not less than the declared quantity.'
                    : 'Corrected average falls below the declared net quantity. Statutory violation.',
              ),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),

              _buildCriteriaRow(
                label: 'Criterion 2: Individual MPE Limits (T1 Defectives)',
                value: '${metrics.t1DefectiveCount} found (Max ${metrics.maxAllowedT1} allowed)',
                isPass: metrics.t1DefectiveCount <= metrics.maxAllowedT1,
                explanation: 'Permissible error limit: ±${metrics.mpeLimit.toStringAsFixed(2)} $unitSym per Fifth Schedule.',
              ),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),

              _buildCriteriaRow(
                label: 'Criterion 3: Severe Negative Errors (T2 Defectives)',
                value: '${metrics.t2DefectiveCount} found (Strictly 0 allowed)',
                isPass: metrics.t2DefectiveCount == 0,
                explanation: 'No package shall have a deficiency greater than twice the MPE.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4. Action Buttons
        if (onExportPressed != null || onSaveToInspection != null) ...[
          Row(
            children: [
              if (onExportPressed != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onExportPressed,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: _contrastNavy, width: 2.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18, color: _contrastNavy),
                    label: const Text(
                      'Export Form V',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _contrastNavy),
                    ),
                  ),
                ),
              ],
              if (onExportPressed != null && onSaveToInspection != null) const SizedBox(width: 12),
              if (onSaveToInspection != null) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSaveToInspection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _contrastNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text(
                      'Attach to Lot Memo',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  /// High-Contrast Metric Tile with bold key readout >= 20sp (21sp, FontWeight.w900)
  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight ? accentColor : _contrastBorder,
          width: isHighlight ? 2.0 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: _contrastLabel,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: accentColor),
            ],
          ),
          const SizedBox(height: 8),
          // User Requirement: Bold key readouts >= 20sp (21sp, FontWeight.w900)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 21.0,
                fontWeight: FontWeight.w900,
                color: accentColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaRow({
    required String label,
    required String value,
    required bool isPass,
    required String explanation,
  }) {
    final statusColor = isPass ? _contrastPass : _contrastViolation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isPass ? 'PASS' : 'FAIL',
                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: statusColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          explanation,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.35, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
