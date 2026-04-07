import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiService {
  static final NetworkInfo _networkInfo = NetworkInfo();

  /// Xin quyền Location (bắt buộc trên Android 8.1+ để đọc SSID/BSSID)
  static Future<bool> _ensureLocationPermission() async {
    var status = await Permission.location.status;
    
    if (status.isGranted) return true;
    
    // Xin quyền runtime
    status = await Permission.location.request();
    
    if (status.isGranted) return true;
    
    // Nếu bị từ chối vĩnh viễn, trả về false
    return false;
  }

  static Future<Map<String, dynamic>> getInfo() async {
    try {
      // Bước 1: Đảm bảo đã có quyền Location
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) {
        return {
          'ssid': '',
          'bssid': '',
          'ip': '',
          'connected': false,
          'error': 'Ứng dụng cần quyền truy cập Vị trí để đọc thông tin WiFi. Vui lòng cấp quyền trong Cài đặt.',
        };
      }

      // Bước 2: Đọc thông tin WiFi
      final ssid = await _networkInfo.getWifiName();
      final bssid = await _networkInfo.getWifiBSSID();
      final ip = await _networkInfo.getWifiIP();

      // network_info_plus returns SSID wrapped in quotes on Android sometimes
      String cleanSsid = ssid ?? '';
      if (cleanSsid.startsWith('"') && cleanSsid.endsWith('"')) {
        cleanSsid = cleanSsid.substring(1, cleanSsid.length - 1);
      }
      
      // Android trả về "<unknown ssid>" khi không có quyền hoặc không kết nối
      if (cleanSsid == '<unknown ssid>' || cleanSsid == '0x') {
        cleanSsid = '';
      }

      return {
        'ssid': cleanSsid,
        'bssid': bssid ?? '',
        'ip': ip ?? '',
        'connected': cleanSsid.isNotEmpty,
      };
    } catch (e) {
      return {
        'ssid': '',
        'bssid': '',
        'ip': '',
        'connected': false,
        'error': e.toString(),
      };
    }
  }

  static Map<String, dynamic> verify(Map<String, dynamic> wifiInfo, Map<String, dynamic> settings) {
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
