import 'package:flutter/foundation.dart';

// Conditional import: native dùng _native.dart, web dùng _web.dart
import 'wifi_service_native.dart' if (dart.library.html) 'wifi_service_web.dart' as platform;

class WifiService {
  static Future<Map<String, dynamic>> getInfo() => platform.getWifiInfo();

  static Map<String, dynamic> verify(Map<String, dynamic> wifiInfo, Map<String, dynamic> settings) {
    if (kIsWeb) {
      // Web không thể đọc WiFi hardware → bỏ qua verify, chấp nhận GPS-only
      return {
        'verified': true,
        'reasons': [],
      };
    }

    bool verified = true;
    List<String> reasons = [];

    final String officeSsid = settings['office_wifi_ssid'] ?? '';
    final String officeBssid = settings['office_wifi_bssid'] ?? '';
    final String officeIpPrefix = settings['office_ip_prefix'] ?? '';

    if (officeSsid.isNotEmpty) {
      final validSsids = officeSsid.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (validSsids.isNotEmpty && !validSsids.contains(wifiInfo['ssid'])) {
        verified = false;
        reasons.add('WiFi sai (${wifiInfo['ssid']})');
      }
    }

    if (officeBssid.isNotEmpty && wifiInfo['bssid'] != '') {
      final currentBssid = wifiInfo['bssid'].toString().toLowerCase();
      final validBssids = officeBssid.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
      if (validBssids.isNotEmpty && !validBssids.contains(currentBssid)) {
        verified = false;
        reasons.add('BSSID router không khớp');
      }
    }

    if (officeIpPrefix.isNotEmpty && wifiInfo['ip'] != '') {
      final currentIp = wifiInfo['ip'].toString();
      final validIpPrefixes = officeIpPrefix.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (validIpPrefixes.isNotEmpty && !validIpPrefixes.any((prefix) => currentIp.startsWith(prefix))) {
        verified = false;
        reasons.add('Lớp mạng IP sai');
      }
    }

    return {
      'verified': verified,
      'reasons': reasons,
    };
  }
}
