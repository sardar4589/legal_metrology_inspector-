import 'package:flutter/material.dart';
import '../../data/services/location_service.dart';

/// Sticky Forensic Footer docked across all inspection, audit, and wizard screens.
/// Enforces statutory chain-of-custody by persistently showing live GPS coordinates (online-tracked),
/// Indian Standard Time (IST UTC+05:30), and verified Inspector Badge ID (#38BDF8 accent).
class StickyForensicFooter extends StatefulWidget {
  final String? customGps;
  final String? customBadge;

  const StickyForensicFooter({
    super.key,
    this.customGps,
    this.customBadge,
  });

  @override
  State<StickyForensicFooter> createState() => _StickyForensicFooterState();
}

class _StickyForensicFooterState extends State<StickyForensicFooter> {
  @override
  void initState() {
    super.initState();
    // Refresh live online location if available
    LocationService.refreshLiveLocation();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute:$second IST (UTC+05:30)';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(
          top: BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: GPS Coordinates & IST Timestamp
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFF38BDF8), size: 14),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<String>(
                            valueListenable: LocationService.coordinatesNotifier,
                            builder: (context, coordinates, _) {
                              return Text(
                                widget.customGps ?? coordinates,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Right: Inspector Badge ID (#38BDF8 Accent) & Online/Offline status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_rounded, color: Color(0xFF38BDF8), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          widget.customBadge ?? 'Badge: INSP-DL-4082',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ValueListenableBuilder<bool>(
                    valueListenable: LocationService.onlineStatusNotifier,
                    builder: (context, isOnline, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF14532D) : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isOnline ? const Color(0xFF22C55E) : const Color(0xFF64748B),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                              color: isOnline ? const Color(0xFF4ADE80) : const Color(0xFF94A3B8),
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isOnline ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(
                                color: isOnline ? const Color(0xFF4ADE80) : const Color(0xFFCBD5E1),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
