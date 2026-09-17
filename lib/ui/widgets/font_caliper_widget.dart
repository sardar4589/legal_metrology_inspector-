import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/font_caliper_models.dart';

/// Visual "Font Caliper" widget displaying optical text sizing checks
/// against Rule 9(1) Table-I minimum numeral height requirements.
class FontCaliperWidget extends StatelessWidget {
  final FontCaliperMeasurement measurement;
  final ValueChanged<double>? onMeasurementChanged;
  final ValueChanged<double>? onRequiredHeightChanged;
  final VoidCallback? onReset;

  const FontCaliperWidget({
    super.key,
    required this.measurement,
    this.onMeasurementChanged,
    this.onRequiredHeightChanged,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isPass = measurement.isCompliant;
    final statusColor = isPass ? AppTheme.passGreen : AppTheme.violationRed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2340).withAlpha(240),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row: Caliper Title + Compliance Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.straighten_rounded, color: AppTheme.accentGold, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OPTICAL FONT CALIPER',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      measurement.targetField,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Compliance Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPass ? Icons.check_circle_rounded : Icons.error_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPass ? 'COMPLIANT' : 'DEFICIENT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Caliper Jaws & Vernier Scale Graphic
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF071526),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                // Visual Caliper Jaws
                SizedBox(
                  width: 36,
                  height: 48,
                  child: CustomPaint(
                    painter: _CaliperJawsPainter(
                      measuredMm: measurement.measuredHeightMm,
                      requiredMm: measurement.requiredHeightMm,
                      accentColor: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Height Metrics Comparison
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        measurement.measuredHeightMm.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Text(
                        ' mm',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Req: ≥ ${measurement.requiredHeightMm.toStringAsFixed(1)} mm',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Stepper Adjustments for Field Precision Tuning
                if (onMeasurementChanged != null) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: measurement.measuredHeightMm > 0.5
                            ? () => onMeasurementChanged!(
                                double.parse((measurement.measuredHeightMm - 0.1).toStringAsFixed(1)),
                              )
                            : null,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.remove_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => onMeasurementChanged!(
                          double.parse((measurement.measuredHeightMm + 0.1).toStringAsFixed(1)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Interactive Drag Slider
          if (onMeasurementChanged != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.straighten_outlined, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: statusColor,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: statusColor.withAlpha(32),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: measurement.measuredHeightMm.clamp(0.5, 10.0),
                      min: 0.5,
                      max: 10.0,
                      divisions: 95,
                      onChanged: (val) {
                        onMeasurementChanged!(double.parse(val.toStringAsFixed(1)));
                      },
                    ),
                  ),
                ),
                Text(
                  '${measurement.measuredHeightMm.toStringAsFixed(1)} mm',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ],
            ),
          ],

          // Quick Table-I Target Selector Buttons
          if (onRequiredHeightChanged != null) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Table-I Target:',
                  style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                ...[1.0, 2.0, 3.0, 4.0, 6.0].map((h) {
                  final isSelected = (measurement.requiredHeightMm - h).abs() < 0.05;
                  return InkWell(
                    onTap: () => onRequiredHeightChanged!(h),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accentGold : Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected ? AppTheme.accentGold : Colors.white24,
                        ),
                      ),
                      child: Text(
                        '${h.toStringAsFixed(0)}mm',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? const Color(0xFF0C2340) : Colors.white70,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Custom painter for the vernier caliper jaws with target datum lines.
class _CaliperJawsPainter extends CustomPainter {
  final double measuredMm;
  final double requiredMm;
  final Color accentColor;

  _CaliperJawsPainter({
    required this.measuredMm,
    required this.requiredMm,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final jawPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final beamPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Top Jaw
    canvas.drawLine(Offset(0, 4), Offset(size.width, 4), jawPaint);
    canvas.drawLine(Offset(0, 4), Offset(0, 14), jawPaint);

    // Bottom Jaw
    canvas.drawLine(Offset(0, size.height - 4), Offset(size.width, size.height - 4), jawPaint);
    canvas.drawLine(Offset(0, size.height - 14), Offset(0, size.height - 4), jawPaint);

    // Measurement beam with dimension arrow
    final cx = size.width * 0.65;
    canvas.drawLine(Offset(cx, 6), Offset(cx, size.height - 6), beamPaint);

    // Top arrow tick
    canvas.drawLine(Offset(cx - 3, 10), Offset(cx, 6), beamPaint);
    canvas.drawLine(Offset(cx + 3, 10), Offset(cx, 6), beamPaint);

    // Bottom arrow tick
    canvas.drawLine(Offset(cx - 3, size.height - 10), Offset(cx, size.height - 6), beamPaint);
    canvas.drawLine(Offset(cx + 3, size.height - 10), Offset(cx, size.height - 6), beamPaint);
  }

  @override
  bool shouldRepaint(covariant _CaliperJawsPainter oldDelegate) {
    return oldDelegate.measuredMm != measuredMm ||
        oldDelegate.requiredMm != requiredMm ||
        oldDelegate.accentColor != accentColor;
  }
}
