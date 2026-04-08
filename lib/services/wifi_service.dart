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
      if (wifiInfo['ssid'] != officeSsid) {
        verified = false;
        reasons.add('WiFi sai (${wifiInfo['ssid']})');
      }
    }

    if (officeBssid.isNotEmpty && wifiInfo['bssid'] != '') {
      if (wifiInfo['bssid'].toString().toLowerCase() != officeBssid.toLowerCase()) {
        verified = false;
        reasons.add('BSSID router không khớp');
      }
    }

    if (officeIpPrefix.isNotEmpty && wifiInfo['ip'] != '') {
      if (!wifiInfo['ip'].toString().startsWith(officeIpPrefix)) {
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
