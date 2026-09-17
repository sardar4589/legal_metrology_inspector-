import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// LocationService tracks live coordinates when online and provides graceful offline fallback.
class LocationService {
  LocationService._();

  static const String fallbackCoordinates = 'GPS: 28.6139° N, 77.2090° E';

  static String _currentCoordinates = fallbackCoordinates;
  static bool _isOnline = false;
  static String? _currentCity;
  static final ValueNotifier<String> coordinatesNotifier = ValueNotifier<String>(fallbackCoordinates);
  static final ValueNotifier<bool> onlineStatusNotifier = ValueNotifier<bool>(false);

  static String get currentCoordinates => _currentCoordinates;
  static bool get isOnline => _isOnline;
  static String? get currentCity => _currentCity;

  /// Fetches live coordinates if internet is reachable.
  static Future<String> refreshLiveLocation() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);

      // Attempt fast IP-based geolocation
      final request = await client.getUrl(Uri.parse('http://ip-api.com/json/?fields=status,message,country,regionName,city,lat,lon'))
          .timeout(const Duration(seconds: 2));
      final response = await request.close().timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;

        if (data['status'] == 'success') {
          final double lat = (data['lat'] as num).toDouble();
          final double lon = (data['lon'] as num).toDouble();
          final String city = data['city'] as String? ?? 'Local Area';

          final latDir = lat >= 0 ? 'N' : 'S';
          final lonDir = lon >= 0 ? 'E' : 'W';
          final formattedGps = 'GPS: ${lat.abs().toStringAsFixed(4)}° $latDir, ${lon.abs().toStringAsFixed(4)}° $lonDir ($city)';

          _currentCoordinates = formattedGps;
          _currentCity = city;
          _isOnline = true;
          coordinatesNotifier.value = _currentCoordinates;
          onlineStatusNotifier.value = true;
          client.close();
          return _currentCoordinates;
        }
      }
      client.close();
    } catch (_) {
      // Offline or network error - fallback gracefully
    }

    _isOnline = false;
    _currentCoordinates = '$fallbackCoordinates (Offline)';
    coordinatesNotifier.value = _currentCoordinates;
    onlineStatusNotifier.value = false;
    return _currentCoordinates;
  }
}
