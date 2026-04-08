import 'dart:math';

/// Tiện ích quy đổi tọa độ GPS
class CoordinateUtils {

  // =============================================
  // 1. Chuyển Decimal Degrees → DMS (Độ/Phút/Giây)
  //    Ví dụ: 21.0078516 → 21°0'28.3"N
  // =============================================
  static String toDMS(double decimal, {bool isLatitude = true}) {
    final direction = isLatitude
        ? (decimal >= 0 ? 'N' : 'S')
        : (decimal >= 0 ? 'E' : 'W');
    final abs = decimal.abs();
    final degrees = abs.floor();
    final minutesDecimal = (abs - degrees) * 60;
    final minutes = minutesDecimal.floor();
    final seconds = ((minutesDecimal - minutes) * 60);

    return '$degrees°$minutes\'${seconds.toStringAsFixed(1)}"$direction';
  }

  /// Format cả cặp tọa độ thành DMS
  /// Ví dụ: "21°0'28.3\"N, 105°48'25.6\"E"
  static String toDMSPair(double lat, double lng) {
    return '${toDMS(lat, isLatitude: true)}, ${toDMS(lng, isLatitude: false)}';
  }

  // =============================================
  // 2. Chuyển DMS → Decimal Degrees
  //    Ví dụ: 21°0'28.3"N → 21.0078611
  // =============================================
  static double fromDMS(int degrees, int minutes, double seconds, String direction) {
    double decimal = degrees + (minutes / 60.0) + (seconds / 3600.0);
    if (direction == 'S' || direction == 'W') {
      decimal = -decimal;
    }
    return decimal;
  }

  // =============================================
  // 3. Tạo Google Maps URL từ tọa độ
  //    Mở trình duyệt → hiển thị vị trí trên Google Maps
  // =============================================
  static String toGoogleMapsUrl(double lat, double lng, {int zoom = 17}) {
    return 'https://www.google.com/maps?q=$lat,$lng&z=$zoom';
  }

  // =============================================
  // 4. Tính khoảng cách giữa 2 điểm (Haversine) — đơn vị: mét
  //    Ví dụ: distanceMeters(21.0078, 105.8071, 21.0285, 105.8542)
  // =============================================
  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0; // bán kính Trái đất (mét)
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Khoảng cách hiển thị dạng text  
  /// Ví dụ: "5.4 km" hoặc "120 m"
  static String distanceText(double lat1, double lng1, double lat2, double lng2) {
    final d = distanceMeters(lat1, lng1, lat2, lng2);
    if (d >= 1000) {
      return '${(d / 1000).toStringAsFixed(1)} km';
    }
    return '${d.round()} m';
  }

  // =============================================
  // 5. Format tọa độ đẹp cho hiển thị UI
  // =============================================
  /// "21.007852, 105.807100"
  static String toDecimalString(double lat, double lng, {int precision = 6}) {
    return '${lat.toStringAsFixed(precision)}, ${lng.toStringAsFixed(precision)}';
  }

  /// Parse chuỗi tọa độ "21.007852, 105.807100" thành [lat, lng]
  static List<double>? parseDecimalString(String coordString) {
    try {
      final parts = coordString.split(',').map((s) => s.trim()).toList();
      if (parts.length != 2) return null;
      return [double.parse(parts[0]), double.parse(parts[1])];
    } catch (_) {
      return null;
    }
  }

  static double _toRadians(double deg) => deg * (pi / 180);
}
