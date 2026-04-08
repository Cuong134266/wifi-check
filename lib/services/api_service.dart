import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

class ApiService {
  // Link API đã được tích hợp tĩnh vào ứng dụng
  static final String _baseUrl = 'https://script.google.com/macros/s/AKfycbzj0fQ9y157DNKPHWWLML6KgRciJMpIK1NnxtuW49GhbcbavqRvIgUmNBNkfVQvgfWmug/exec';

  static Future<void> init() async {
    // Link đã là cố định, không cần tải từ SharedPreferences
  }

  static String getUrl() => _baseUrl;

  /// Tạo IOClient không tự động follow redirect
  static IOClient _createClient() {
    final innerClient = HttpClient();
    innerClient.findProxy = null;
    return IOClient(innerClient);
  }

  /// Gửi request tới Google Apps Script với xử lý redirect thủ công.
  /// Google Apps Script luôn trả 302 redirect cho POST requests,
  /// mà thư viện http của Dart không tự follow redirect với POST.
  static Future<Map<String, dynamic>> request(String action, [Map<String, dynamic>? data]) async {
    if (_baseUrl.isEmpty) {
      throw Exception('API URL chưa được cấu hình.');
    }

    final separator = _baseUrl.contains('?') ? '&' : '?';
    final url = '$_baseUrl${separator}action=$action';
    
    final payload = data ?? {};
    payload['action'] = action;

    final client = _createClient();
    try {
      // Bước 1: POST tới Google Apps Script
      final postRequest = Request('POST', Uri.parse(url));
      postRequest.headers['Content-Type'] = 'text/plain';
      postRequest.body = jsonEncode(payload);
      postRequest.followRedirects = false;

      final streamedResponse = await client.send(postRequest);
      var response = await Response.fromStream(streamedResponse);

      // Bước 2: Manually follow 302/303 redirect (tối đa 5 lần)
      int redirectCount = 0;
      while ((response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 303) && redirectCount < 5) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl == null) break;
        
        final getRequest = Request('GET', Uri.parse(redirectUrl));
        getRequest.followRedirects = false;
        final getStreamedResponse = await client.send(getRequest);
        response = await Response.fromStream(getStreamedResponse);
        redirectCount++;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final text = response.body.trim();
        try {
          final result = jsonDecode(text);
          if (result is Map<String, dynamic>) {
            if (result['success'] == false && result['error'] != null) {
              throw Exception(result['error']);
            }
            return result;
          } else {
            throw Exception('Server trả về kiểu dữ liệu không hợp lệ.');
          }
        } on FormatException {
          throw Exception('Server trả về dữ liệu không phải JSON: ${text.length > 200 ? text.substring(0, 200) : text}');
        }
      } else {
        throw Exception('Server lỗi: HTTP ${response.statusCode}');
      }
    } catch (err) {
      if (err is Exception) rethrow;
      throw Exception(err.toString());
    } finally {
      client.close();
    }
  }

  // --- Auth & Initial Sync ---
  static Future<Map<String, dynamic>> loginAndSync(
    String email, 
    String name, 
    String avatar, 
    Map<String, dynamic> deviceData
  ) async {
    return request('login', {
      'email': email,
      'name': name,
      'avatar': avatar,
      'device_id': deviceData['id'] ?? '',
      'device_model': deviceData['model'] ?? '',
      'device_os': deviceData['os'] ?? '',
    });
  }

  // --- Check-in ---
  static Future<Map<String, dynamic>> checkin(
    String email, 
    Map<String, dynamic> wifiData, 
    Map<String, dynamic> deviceData,
    Map<String, dynamic> locationData
  ) async {
    return request('checkin', {
      'email': email,
      'wifi_ssid': wifiData['ssid'] ?? '',
      'wifi_bssid': wifiData['bssid'] ?? '',
      'ip_address': wifiData['ip'] ?? '',
      'signal_strength': wifiData['rssi'] ?? '',
      'device_id': deviceData['id'] ?? '',
      'device_model': deviceData['model'] ?? '',
      'latitude': locationData['latitude']?.toString() ?? '',
      'longitude': locationData['longitude']?.toString() ?? '',
      'gps_distance': locationData['distance']?.toString() ?? '',
      'checkin_method': locationData['checkin_method']?.toString() ?? ''
    });
  }
}
