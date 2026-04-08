import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

final NetworkInfo _networkInfo = NetworkInfo();

/// Xin quyền Location (bắt buộc trên Android 8.1+ để đọc SSID/BSSID)
Future<bool> _ensureLocationPermission() async {
  var status = await Permission.location.status;
  if (status.isGranted) return true;
  status = await Permission.location.request();
  if (status.isGranted) return true;
  return false;
}

Future<Map<String, dynamic>> getWifiInfo() async {
  try {
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

    final ssid = await _networkInfo.getWifiName();
    final bssid = await _networkInfo.getWifiBSSID();
    final ip = await _networkInfo.getWifiIP();

    String cleanSsid = ssid ?? '';
    if (cleanSsid.startsWith('"') && cleanSsid.endsWith('"')) {
      cleanSsid = cleanSsid.substring(1, cleanSsid.length - 1);
    }
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
