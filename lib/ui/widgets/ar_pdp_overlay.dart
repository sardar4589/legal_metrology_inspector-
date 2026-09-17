import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/font_caliper_models.dart';

/// AR Camera preview overlay targeting the Principal Display Panel (PDP)
/// according to statutory specifications in Rule 24 of PCR 2011.
class ArPdpOverlay extends StatelessWidget {
  final PdpDimensions dimensions;
  final bool isAligned;
  final VoidCallback? onToggleShape;
  final VoidCallback? onEditDimensions;

  const ArPdpOverlay({
    super.key,
    required this.dimensions,
    this.isAligned = true,
    this.onToggleShape,
    this.onEditDimensions,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactCard = constraints.maxHeight < 450;
        final availableHeight = isCompactCard
            ? constraints.maxHeight
            : (constraints.maxHeight - 330).clamp(160.0, constraints.maxHeight);
        final boxWidth = (constraints.maxWidth * (isCompactCard ? 0.90 : 0.86)).clamp(220.0, constraints.maxWidth - 20);
        final boxHeight = (availableHeight * (isCompactCard ? 0.84 : 0.84)).clamp(140.0, availableHeight);
        final centerY = isCompactCard
            ? constraints.maxHeight / 2
            : (68 + (availableHeight / 2));
        final center = Offset(constraints.maxWidth / 2, centerY);
        final cutoutRect = Rect.fromCenter(
          center: center,
          width: boxWidth,
          height: boxHeight,
        );

        return Stack(
          children: [
            // Darkened peripheral mask
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _PdpPeripheralMaskPainter(cutoutRect: cutoutRect),
            ),

            // PDP Viewfinder Reticle Frame placed exactly inside cutoutRect
            Positioned.fromRect(
              rect: cutoutRect,
              child: CustomPaint(
                painter: _PdpReticlePainter(
                  accentColor: isAligned ? AppTheme.accentGold : const Color(0xFF38BDF8),
                  isAligned: isAligned,
                ),
                child: Stack(
                  children: [
                    // Top Bar: PDP Rule 24 Area & Shape Chip
                    Positioned(
                      top: 10,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: InkWell(
                              onTap: onEditDimensions,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0C2340).withAlpha(225),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.accentGold, width: 1.2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.crop_free_rounded, color: AppTheme.accentGold, size: 14),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'PDP: ${dimensions.widthCm}cm × ${dimensions.heightCm}cm (${dimensions.areaCm2} cm²)',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    if (onEditDimensions != null) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.tune_rounded, color: AppTheme.accentGold, size: 12),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: onToggleShape,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C2340).withAlpha(225),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white38, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    dimensions.shape == PdpShape.cylindrical
                                        ? Icons.circle_outlined
                                        : Icons.rectangle_outlined,
                                    color: AppTheme.accentGold,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    dimensions.shape.label.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom Bar: Statutory Rule Citation
                    Positioned(
                      bottom: 10,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C2340).withAlpha(220),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isAligned ? AppTheme.passGreen : AppTheme.warningAmber,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.gavel_rounded, color: Colors.white70, size: 13),
                                  SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Rule 24 PCR 2011 • Principal Display Panel',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isAligned ? AppTheme.passGreen : AppTheme.warningAmber,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isAligned ? 'ALIGNED' : 'ALIGNING',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
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
          ],
        );
      },
    );
  }
}

/// Paints peripheral darkened vignette around the PDP focus target.
class _PdpPeripheralMaskPainter extends CustomPainter {
  final Rect cutoutRect;

  _PdpPeripheralMaskPainter({required this.cutoutRect});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(12)));

    final maskPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    final paint = Paint()
      ..color = Colors.black.withAlpha(110)
      ..style = PaintingStyle.fill;

    canvas.drawPath(maskPath, paint);
  }

  @override
  bool shouldRepaint(covariant _PdpPeripheralMaskPainter oldDelegate) {
    return oldDelegate.cutoutRect != cutoutRect;
  }
}

/// Custom painter that draws tactical corner reticles and alignment crosshairs.
class _PdpReticlePainter extends CustomPainter {
  final Color accentColor;
  final bool isAligned;

  _PdpReticlePainter({required this.accentColor, required this.isAligned});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final thinPaint = Paint()
      ..color = accentColor.withAlpha(80)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const cornerLength = 26.0;
    const cornerRadius = 8.0;

    // 1. Draw 4 tactical corner brackets
    // Top-Left
    final tlPath = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, cornerRadius)
      ..arcToPoint(const Offset(cornerRadius, 0), radius: const Radius.circular(cornerRadius))
      ..lineTo(cornerLength, 0);
    canvas.drawPath(tlPath, strokePaint);

    // Top-Right
    final trPath = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - cornerRadius, 0)
      ..arcToPoint(Offset(size.width, cornerRadius), radius: const Radius.circular(cornerRadius))
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(trPath, strokePaint);

    // Bottom-Left
    final blPath = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height - cornerRadius)
      ..arcToPoint(Offset(cornerRadius, size.height), radius: const Radius.circular(cornerRadius))
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(blPath, strokePaint);

    // Bottom-Right
    final brPath = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width - cornerRadius, size.height)
      ..arcToPoint(Offset(size.width, size.height - cornerRadius), radius: const Radius.circular(cornerRadius))
      ..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(brPath, strokePaint);

    // 2. Dashed or thin perimeter
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(cornerRadius)),
      thinPaint,
    );

    // 3. Center alignment crosshair ticks
    final cx = size.width / 2;
    final cy = size.height / 2;
    const tick = 12.0;

    canvas.drawLine(Offset(cx - tick, cy), Offset(cx + tick, cy), strokePaint);
    canvas.drawLine(Offset(cx, cy - tick), Offset(cx, cy + tick), strokePaint);
  }

  @override
  bool shouldRepaint(covariant _PdpReticlePainter oldDelegate) {
    return oldDelegate.accentColor != accentColor || oldDelegate.isAligned != isAligned;
  }
}
