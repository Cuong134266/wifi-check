import 'dart:convert';

import 'api_service.dart';

class QrCheckinService {
  static Future<Map<String, dynamic>> createSession({
    required String email,
    required String name,
    required String deviceId,
  }) {
    return ApiService.request('createQrSession', {
      'email': email,
      'name': name,
      'device_id': deviceId,
    });
  }

  static Future<Map<String, dynamic>> checkinByQr({
    required String email,
    required String qrPayload,
    required Map<String, dynamic> wifiInfo,
    required Map<String, dynamic> deviceInfo,
    required Map<String, dynamic> locationInfo,
    required String publicIp,
  }) {
    final token = extractToken(qrPayload);
    if (token == null || token.isEmpty) {
      throw Exception('QR không đúng định dạng check-in.');
    }

    return ApiService.request('checkinByQr', {
      'email': email,
      'qr_token': token,
      'wifi_ssid': wifiInfo['ssid'] ?? '',
      'wifi_bssid': wifiInfo['bssid'] ?? '',
      'ip_address': wifiInfo['ip'] ?? '',
      'signal_strength': wifiInfo['rssi'] ?? '',
      'device_id': deviceInfo['id'] ?? '',
      'device_model': deviceInfo['model'] ?? '',
      'latitude': locationInfo['latitude']?.toString() ?? '',
      'longitude': locationInfo['longitude']?.toString() ?? '',
      'gps_distance': locationInfo['distance']?.toString() ?? '',
      'public_ip': publicIp,
      'checkin_method': 'gps+qr',
    });
  }

  static String? extractToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded['type'] == 'ux_checkin_qr') {
        return decoded['token']?.toString();
      }
      if (decoded is Map && decoded['token'] != null) {
        return decoded['token'].toString();
      }
    } catch (_) {}

    return trimmed;
  }
}
