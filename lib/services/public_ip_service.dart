import 'dart:convert';
import 'package:http/http.dart' as http;

class PublicIpService {
  static String _cachedIp = '';
  static DateTime? _lastFetchTime;
  static const Duration _cacheTtl = Duration(minutes: 2);

  static final Map<String, String> _ddnsCache = {};
  static final Map<String, DateTime> _ddnsCacheTime = {};

  /// Phân giải DNS hostname (ví dụ: uxteam-office.ddns.net) ra IP qua DNS-over-HTTPS (DoH) của Google
  static Future<String?> resolveDdns(String hostname, {bool forceRefresh = false}) async {
    final cleanHost = hostname.trim().toLowerCase();
    final now = DateTime.now();
    if (!forceRefresh &&
        _ddnsCache.containsKey(cleanHost) &&
        _ddnsCacheTime.containsKey(cleanHost) &&
        now.difference(_ddnsCacheTime[cleanHost]!) < const Duration(minutes: 2)) {
      return _ddnsCache[cleanHost];
    }

    try {
      final uri = Uri.parse('https://dns.google/resolve?name=$cleanHost&type=A');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['Answer'] is List && (data['Answer'] as List).isNotEmpty) {
          for (final ans in data['Answer']) {
            if (ans['type'] == 1 && ans['data'] != null) {
              final resolvedIp = ans['data'].toString().trim();
              if (resolvedIp.isNotEmpty) {
                _ddnsCache[cleanHost] = resolvedIp;
                _ddnsCacheTime[cleanHost] = now;
                return resolvedIp;
              }
            }
          }
        }
      }
    } catch (_) {}
    return _ddnsCache[cleanHost];
  }

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

  /// So sánh Public IP với IP công ty trong settings (hỗ trợ cả IP số, Wildcard và DDNS Hostname)
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

    bool matched = validIps.any((ipPattern) {
      if (ipPattern.endsWith('*')) {
        final prefix = ipPattern.substring(0, ipPattern.length - 1);
        return cleanCurrentIp.startsWith(prefix);
      }
      return ipPattern == cleanCurrentIp;
    });

    // Nếu chưa khớp trực tiếp, kiểm tra xem có Hostname / DDNS (ví dụ: uxteam-office.ddns.net) không
    if (!matched) {
      for (final pattern in validIps) {
        if (RegExp(r'[a-zA-Z]').hasMatch(pattern)) {
          final resolvedIp = await resolveDdns(pattern);
          if (resolvedIp != null && resolvedIp.isNotEmpty) {
            if (cleanCurrentIp == resolvedIp) {
              matched = true;
              return {
                'verified': true,
                'public_ip': currentIp,
                'office_ip': officeIp,
                'reason': 'IP khớp với No-IP DDNS ($pattern -> $resolvedIp)',
              };
            }
          }
        }
      }
    }

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
