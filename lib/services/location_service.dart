import 'package:geolocator/geolocator.dart';

class LocationService {
  // ── Tọa độ văn phòng (cấu hình mặc định, có thể override từ settings) ──
  static const double defaultOfficeLat = 21.0285; // Hà Nội mặc định
  static const double defaultOfficeLng = 105.8542;
  static const double defaultRadiusMeters = 200; // Bán kính cho phép (mét)

  /// Kiểm tra & xin quyền location
  static Future<bool> ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// Lấy vị trí hiện tại
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await ensurePermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
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

  /// Lấy thông tin location đầy đủ cho check-in
  static Future<Map<String, dynamic>> getInfo([
    Map<String, dynamic>? settings,
  ]) async {
    try {
      final officeLat =
          (settings?['office_lat'] as num?)?.toDouble() ?? defaultOfficeLat;
      final officeLng =
          (settings?['office_lng'] as num?)?.toDouble() ?? defaultOfficeLng;
      final radius =
          (settings?['office_radius'] as num?)?.toDouble() ??
          defaultRadiusMeters;

      if (debugFakeLocation) {
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Giả lập delay
        final currentLat = officeLat + debugLatOffset;
        final currentLng = officeLng + debugLngOffset;
        final distance = distanceTo(
          currentLat,
          currentLng,
          officeLat,
          officeLng,
        );
        return {
          'available': true,
          'latitude': currentLat,
          'longitude': currentLng,
          'accuracy': 5.0,
          'distance': distance,
          'radius': radius,
          'in_range': distance <= radius,
          'is_fake': true,
        };
      }

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

      // Tọa độ văn phòng đã đọc ở trên

      final distance = distanceTo(
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );
      final isInRange = distance <= radius;

      return {
        'available': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'distance': distance,
        'radius': radius,
        'in_range': isInRange,
      };
    } catch (e) {
      return {'available': false, 'error': e.toString()};
    }
  }
}
