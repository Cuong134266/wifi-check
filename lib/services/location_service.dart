import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  // ── Tọa độ văn phòng (cấu hình mặc định, có thể override từ settings) ──
  static const double defaultOfficeLat = 21.0078017;
  static const double defaultOfficeLng = 105.8071089;
  static const double defaultRadiusMeters = 2000; // Bán kính cho phép (2km)

  /// Kiểm tra & xin quyền location
  static Future<bool> ensurePermission() async {
    try {
      if (kIsWeb) {
        // Trên nền tảng Web (đặc biệt Safari), việc gọi checkPermission hoặc requestPermission 
        // sẽ làm đứt mạch User Gesture (do await Promise bất đồng bộ).
        // Tốt nhất là return true để getCurrentPosition gọi thẳng native browser prompt!
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
      // Bỏ qua lỗi permission API trên Safari web mượn tạm quyền luôn
      if (kIsWeb) return true;
      return false;
    }
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
          double.tryParse(settings?['office_lat']?.toString() ?? '') ?? defaultOfficeLat;
      final officeLng =
          double.tryParse(settings?['office_lng']?.toString() ?? '') ?? defaultOfficeLng;
      final radius =
          double.tryParse(settings?['office_radius']?.toString() ?? '') ??
          defaultRadiusMeters;

      if (debugFakeLocation) {
        await Future.delayed(const Duration(milliseconds: 500));
        final currentLat = officeLat + debugLatOffset;
        final currentLng = officeLng + debugLngOffset;
        final distance = distanceTo(currentLat, currentLng, officeLat, officeLng);
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

      // ═══════════════════════════════════════════════════════════
      // WEB SAFARI/CHROME GESTURE FIX:
      // Trên Web, getCurrentPosition() PHẢI là lệnh await ĐẦU TIÊN
      // trong hàm async này. Bất kỳ await nào trước nó (kể cả
      // ensurePermission() hay Future.delayed()) sẽ làm trình duyệt
      // mất "User Gesture Token" → không bao giờ hiện popup xin quyền!
      // ═══════════════════════════════════════════════════════════
      if (kIsWeb) {
        try {
          final Position? position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 15),
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
          return {
            'available': true,
            'permission_denied': false,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'distance': distance,
            'radius': radius,
            'in_range': distance <= radius,
          };
        } catch (e) {
          // Lỗi GeolocationPositionError code 1 = PERMISSION_DENIED
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

      // --- Native (Android / iOS app) flow ---
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
