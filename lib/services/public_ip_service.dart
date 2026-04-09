import 'package:http/http.dart' as http;

class PublicIpService {
  static String _cachedIp = '';

  /// Lấy Public IP của thiết bị từ api.ipify.org
  /// Trả về chuỗi IP (ví dụ: "14.161.22.45") hoặc rỗng nếu lỗi
  static Future<String> getPublicIp({bool forceRefresh = false}) async {
    if (_cachedIp.isNotEmpty && !forceRefresh) return _cachedIp;

    try {
      final response = await http.get(
        Uri.parse('https://api.ipify.org'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        _cachedIp = response.body.trim();
        return _cachedIp;
      }
    } catch (_) {}

    // Fallback: thử nguồn khác nếu ipify bị chặn
    try {
      final response = await http.get(
        Uri.parse('https://icanhazip.com'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _cachedIp = response.body.trim();
        return _cachedIp;
      }
    } catch (_) {}

    return '';
  }

  /// So sánh Public IP hiện tại với IP công ty trong settings
  static Future<Map<String, dynamic>> verify(Map<String, dynamic> settings) async {
    final officeIp = (settings['office_public_ip'] ?? '').toString().trim();
    
    // Nếu chưa cấu hình office_public_ip → bỏ qua check, cho qua
    if (officeIp.isEmpty) {
      return {
        'verified': true,
        'public_ip': _cachedIp,
        'reason': 'Chưa cấu hình IP công ty',
        'skipped': true,
      };
    }

    final currentIp = await getPublicIp(forceRefresh: true);
    
    if (currentIp.isEmpty) {
      return {
        'verified': false,
        'public_ip': '',
        'reason': 'Không thể xác định địa chỉ IP mạng',
      };
    }

    final matched = currentIp == officeIp;
    return {
      'verified': matched,
      'public_ip': currentIp,
      'office_ip': officeIp,
      'reason': matched 
          ? 'IP khớp với mạng công ty' 
          : 'IP không khớp ($currentIp ≠ $officeIp)',
    };
  }
}
