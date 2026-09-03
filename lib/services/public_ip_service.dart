import 'package:http/http.dart' as http;

class PublicIpService {
  static String _cachedIp = '';
  static DateTime? _lastFetchTime;
  static const Duration _cacheTtl = Duration(minutes: 2);

  /// Lấy Public IP của thiết bị từ api.ipify.org (với fallback sang icanhazip)
  /// Có bộ nhớ đệm TTL 2 phút để tránh lãng phí mạng
  static Future<String> getPublicIp({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (_cachedIp.isNotEmpty &&
        !forceRefresh &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < _cacheTtl) {
      return _cachedIp;
    }

    // Nếu vừa mới lấy trong vòng 10 giây thì dùng lại kể cả forceRefresh để tránh spam
    if (_cachedIp.isNotEmpty &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < const Duration(seconds: 10)) {
      return _cachedIp;
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.ipify.org'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        _cachedIp = response.body.trim();
        _lastFetchTime = DateTime.now();
        return _cachedIp;
      }
    } catch (_) {}

    // Fallback: thử nguồn khác nếu ipify bị chặn hoặc timeout
    try {
      final response = await http.get(
        Uri.parse('https://icanhazip.com'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        _cachedIp = response.body.trim();
        _lastFetchTime = DateTime.now();
        return _cachedIp;
      }
    } catch (_) {}

    return _cachedIp; // Nếu lỗi mạng, trả về cache trước đó thay vì rỗng
  }

  /// So sánh Public IP với IP công ty trong settings
  /// Hỗ trợ truyền `knownIp` sẵn có để không phải gọi mạng lại
  static Future<Map<String, dynamic>> verify(
    Map<String, dynamic> settings, {
    String? knownIp,
    bool forceRefresh = false,
  }) async {
    final officeIp = (settings['office_public_ip'] ?? '').toString().trim();
    
    // Nếu chưa cấu hình office_public_ip → bỏ qua check, cho qua
    if (officeIp.isEmpty) {
      return {
        'verified': true,
        'public_ip': knownIp ?? _cachedIp,
        'reason': 'Chưa cấu hình IP công ty',
        'skipped': true,
      };
    }

    final currentIp = (knownIp != null && knownIp.isNotEmpty)
        ? knownIp
        : await getPublicIp(forceRefresh: forceRefresh);
    
    if (currentIp.isEmpty) {
      return {
        'verified': false,
        'public_ip': '',
        'reason': 'Không thể xác định địa chỉ IP mạng',
      };
    }

    final cleanCurrentIp = currentIp.trim().replaceAll(RegExp(r'\s+'), '');
    final validIps = officeIp
        .split(RegExp(r'[,;\n\r]+'))
        .map((e) => e.replaceAll(RegExp(r'\s+'), '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final matched = validIps.contains(cleanCurrentIp);
    return {
      'verified': matched,
      'public_ip': currentIp,
      'office_ip': officeIp,
      'reason': matched 
          ? 'IP khớp với mạng công ty' 
          : 'IP không khớp ($currentIp không nằm trong $officeIp)',
    };
  }
}
