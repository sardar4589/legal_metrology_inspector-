import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/inspection_item.dart';
import 'status_badge.dart';

/// InspectionCard displays an inspection log record, prominently featuring
/// the actual photo uploaded by the officer, compliance status, and case metadata.
class InspectionCard extends StatelessWidget {
  final InspectionItem item;
  final VoidCallback onTap;
  final VoidCallback? onPdfTap;

  const InspectionCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onPdfTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isViolation
              ? AppTheme.violationBorder
              : (item.isPass ? AppTheme.passBorder : AppTheme.neutralBorder),
          width: 2.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Image Thumbnail + Product Info + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Captured Photo Thumbnail
                  _buildPackageThumbnail(),
                  const SizedBox(width: 12),

                  // Commodity Name, Shop, & Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.productName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            StatusBadge(status: item.status),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Business Name
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 15,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                item.businessName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Statutory Category Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryNavy.withAlpha(15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.primaryNavy.withAlpha(30)),
                          ),
                          child: Text(
                            item.category,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Violation Reason Callout (if violation)
              if (item.isViolation && item.violationReason != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.violationBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.violationRed.withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 14, color: AppTheme.violationRed),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Issue: ${item.violationReason}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.violationText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Divider
              const Divider(height: 1, color: AppTheme.borderLight),
              const SizedBox(height: 8),

              // Footer: Timestamp + Case ID + PDF Icon indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.formattedTime,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy.withAlpha(15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, size: 12, color: AppTheme.primaryNavy),
                            const SizedBox(width: 3),
                            Text(
                              'PDF #${item.id}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.primaryNavy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageThumbnail() {
    Widget imageWidget;

    if (item.imageBytes != null && item.imageBytes!.isNotEmpty) {
      imageWidget = Image.memory(
        item.imageBytes!,
        fit: BoxFit.cover,
        width: 72,
        height: 72,
      );
    } else if (item.imagePath != null && item.imagePath!.isNotEmpty && !kIsWeb) {
      final file = File(item.imagePath!);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.cover,
          width: 72,
          height: 72,
        );
      } else {
        imageWidget = _buildPlaceholder();
      }
    } else {
      imageWidget = _buildPlaceholder();
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFFEF3C7),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, size: 28, color: Color(0xFFD97706)),
            SizedBox(height: 2),
            Text(
              'PHOTO',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF78350F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
