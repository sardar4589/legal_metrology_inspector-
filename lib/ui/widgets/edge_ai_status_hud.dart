import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/font_caliper_models.dart';

/// Edge AI processing status HUD and dynamic warning banner
/// that alerts officers when OCR confidence drops below 75% ("Manual Verification Required").
class EdgeAiStatusHud extends StatelessWidget {
  final EdgeAiState state;
  final double confidence; // 0.0 to 1.0 (e.g. 0.68)
  final VoidCallback? onManualVerifyPressed;
  final ValueChanged<double>? onConfidenceChanged;

  const EdgeAiStatusHud({
    super.key,
    required this.state,
    required this.confidence,
    this.onManualVerifyPressed,
    this.onConfidenceChanged,
  });

  bool get isLowConfidence => confidence < 0.75;

  @override
  Widget build(BuildContext context) {
    final confPercent = (confidence * 100).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Distinct Warning Banner when OCR Confidence < 75%
        if (isLowConfidence) ...[
          _buildLowConfidenceWarningBanner(confPercent),
          const SizedBox(height: 8),
        ],

        // 2. Edge AI Processing State Status Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0C2340).withAlpha(230),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isLowConfidence ? AppTheme.warningAmber : AppTheme.accentGold.withAlpha(120),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              // Edge AI Activity Indicator
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isLowConfidence ? AppTheme.warningAmber : const Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isLowConfidence ? AppTheme.warningAmber : const Color(0xFF4ADE80)).withAlpha(140),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Processing State Text
              Expanded(
                child: Row(
                  children: [
                    Text(
                      state.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'AI ACTIVE',
                        style: TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),

              // Confidence Score Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLowConfidence
                      ? AppTheme.warningAmber.withAlpha(40)
                      : AppTheme.passGreen.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isLowConfidence ? AppTheme.warningAmber : AppTheme.passGreen,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLowConfidence ? Icons.warning_amber_rounded : Icons.verified_rounded,
                      size: 13,
                      color: isLowConfidence ? AppTheme.warningAmber : AppTheme.passGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$confPercent% OCR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isLowConfidence ? AppTheme.warningAmber : const Color(0xFF4ADE80),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// High-contrast warning banner for field officers when confidence drops below 75%
  Widget _buildLowConfidenceWarningBanner(int confPercent) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFF991B1B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.amberAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'LOW OCR CONFIDENCE ($confPercent%) — MANUAL VERIFICATION REQUIRED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Glare or curvature detected. Calibrate caliper or verify manually.',
                    style: TextStyle(color: Color(0xFFFEE2E2), fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onManualVerifyPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF991B1B),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 14),
                  label: const Text(
                    'Calibrate',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
