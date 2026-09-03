import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  // ── Tọa độ văn phòng (cấu hình mặc định, có thể override từ settings) ──
  static const double defaultOfficeLat = 21.0078017;
  static const double defaultOfficeLng = 105.8071089;
  static const double defaultRadiusMeters = 2000; // Bán kính cho phép (2km)

  static Map<String, dynamic>? _cachedLocation;
  static DateTime? _lastLocationTime;
  static const Duration _locationCacheTtl = Duration(minutes: 2);

  /// Kiểm tra & xin quyền location
  static Future<bool> ensurePermission() async {
    try {
      if (kIsWeb) {
        return true;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;

      return true;
    } catch (e) {
      if (kIsWeb) return true;
      return false;
    }
  }

  /// Lấy vị trí hiện tại nhanh
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await ensurePermission();
      if (!hasPermission) return null;

      // Thử lấy vị trí đã biết gần nhất (đáp ứng 0ms trên Android/iOS)
      if (!kIsWeb) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null &&
              DateTime.now().difference(lastKnown.timestamp) < const Duration(minutes: 3)) {
            return lastKnown;
          }
        } catch (_) {}
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Tính khoảng cách đến văn phòng (mét)
  static double distanceTo(
    double lat,
    double lng,
    double officeLat,
    double officeLng,
  ) {
    return Geolocator.distanceBetween(lat, lng, officeLat, officeLng);
  }

  // --- DEV MODE ---
  static bool debugFakeLocation = false; // TẮT fake → dùng GPS thật
  static double debugLatOffset = 0.0000;
  static double debugLngOffset = 0.0000;

  /// Lấy thông tin location đầy đủ cho check-in (có cache 2 phút để đạt tốc độ 0ms)
  static Future<Map<String, dynamic>> getInfo([
    Map<String, dynamic>? settings,
    bool forceRefresh = false,
  ]) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedLocation != null &&
        _lastLocationTime != null &&
        now.difference(_lastLocationTime!) < _locationCacheTtl) {
      return _cachedLocation!;
    }

    try {
      final officeLat =
          double.tryParse(settings?['office_lat']?.toString() ?? '') ?? defaultOfficeLat;
      final officeLng =
          double.tryParse(settings?['office_lng']?.toString() ?? '') ?? defaultOfficeLng;
      final radius =
          double.tryParse(settings?['office_radius']?.toString() ?? '') ??
          defaultRadiusMeters;

      if (debugFakeLocation) {
        final currentLat = officeLat + debugLatOffset;
        final currentLng = officeLng + debugLngOffset;
        final distance = distanceTo(currentLat, currentLng, officeLat, officeLng);
        final result = {
          'available': true,
          'latitude': currentLat,
          'longitude': currentLng,
          'accuracy': 5.0,
          'distance': distance,
          'radius': radius,
          'in_range': distance <= radius,
          'is_fake': true,
        };
        _cachedLocation = result;
        _lastLocationTime = DateTime.now();
        return result;
      }

      // Web flow
      if (kIsWeb) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
          if (position == null) {
            return {
              'available': false,
              'permission_denied': false,
              'error': 'Không thể lấy vị trí hiện tại.',
            };
          }
          final distance = distanceTo(position.latitude, position.longitude, officeLat, officeLng);
          final result = {
            'available': true,
            'permission_denied': false,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'distance': distance,
            'radius': radius,
            'in_range': distance <= radius,
          };
          _cachedLocation = result;
          _lastLocationTime = DateTime.now();
          return result;
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          final isDenied = errStr.contains('permission') ||
              errStr.contains('denied') ||
              errStr.contains('1');
          return {
            'available': false,
            'permission_denied': isDenied,
            'error': isDenied
                ? 'Quyền Vị trí bị từ chối. Vui lòng bật lại trong cài đặt trình duyệt.'
                : e.toString(),
          };
        }
      }

      // Native flow
      final hasPermission = await ensurePermission();
      if (!hasPermission) {
        return {
          'available': false,
          'error': 'Cần quyền truy cập Vị trí để check-in bằng GPS.',
        };
      }

      final position = await getCurrentPosition();
      if (position == null) {
        return {'available': false, 'error': 'Không thể lấy vị trí hiện tại.'};
      }

      final distance = distanceTo(
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );
      final isInRange = distance <= radius;

      final result = {
        'available': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'distance': distance,
        'radius': radius,
        'in_range': isInRange,
      };
      _cachedLocation = result;
      _lastLocationTime = DateTime.now();
      return result;
    } catch (e) {
      return {'available': false, 'error': e.toString()};
    }
  }
}
