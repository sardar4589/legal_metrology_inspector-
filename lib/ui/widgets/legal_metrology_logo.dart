import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Official Emblem / Logo Widget for Legal Metrology Department
/// Displays the official Maharashtra State Legal Metrology seal featuring
/// the Ashoka Lion Capitol, Scales of Justice, and Standard Metric Weights.
class LegalMetrologyLogo extends StatelessWidget {
  final double size;
  final bool isBadge;
  final Color? borderColor;
  final double borderWidth;
  final BoxFit fit;

  const LegalMetrologyLogo({
    super.key,
    this.size = 64,
    this.isBadge = true,
    this.borderColor,
    this.borderWidth = 2.0,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? Colors.transparent;

    Widget imageContent = Image.asset(
      'assets/images/legal_metrology_logo.jpg',
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // High-fidelity fallback to balance scales emblem if asset is unavailable
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppTheme.primaryNavy,
            shape: BoxShape.circle,
            border: effectiveBorderColor != Colors.transparent
                ? Border.all(color: effectiveBorderColor, width: borderWidth)
                : null,
          ),
          child: Center(
            child: Icon(
              Icons.balance_rounded,
              size: size * 0.55,
              color: Colors.white,
            ),
          ),
        );
      },
    );

    if (!isBadge) {
      return SizedBox(
        width: size,
        height: size,
        child: imageContent,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: effectiveBorderColor != Colors.transparent
            ? Border.all(color: effectiveBorderColor, width: borderWidth)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: imageContent),
    );
  }
}
