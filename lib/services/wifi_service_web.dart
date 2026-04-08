/// Web stub — trình duyệt không thể đọc thông tin WiFi hardware.
/// Trả connected = true để cho phép check-in bằng GPS trên Web.
Future<Map<String, dynamic>> getWifiInfo() async {
  return {
    'ssid': 'Web Browser',
    'bssid': '',
    'ip': '',
    'connected': true,
    'web': true,
  };
}
