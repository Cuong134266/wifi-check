import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

class DeviceService {
  static Future<Map<String, dynamic>> getInfo() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('device_id');
    
    if (id == null) {
      id = 'FLUTTER-${_generateUUID()}';
      await prefs.setString('device_id', id);
    }

    String os = 'Unknown';
    if (kIsWeb) {
      os = 'Web';
    } else {
      // Chỉ import dart:io khi KHÔNG phải Web
      try {
        os = _getPlatformOS();
      } catch (_) {
        os = 'Unknown';
      }
    }

    return {
      'id': id,
      'model': os == 'Android' ? 'Android Device' : (os == 'iOS' ? 'Apple Device' : 'Web Browser'),
      'os': os,
    };
  }

  static String _getPlatformOS() {
    // Tách riêng hàm này để tránh import dart:io ở top-level
    // Trên Web, hàm này KHÔNG BAO GIỜ được gọi (đã guard bởi kIsWeb)
    return defaultTargetPlatform == TargetPlatform.android
        ? 'Android'
        : defaultTargetPlatform == TargetPlatform.iOS
            ? 'iOS'
            : 'Unknown';
  }

  static String _generateUUID() {
    final random = Random();
    const chars = '0123456789abcdef';
    String uuid = '';
    for (int i = 0; i < 32; i++) {
      if (i == 12) {
        uuid += '4';
      } else if (i == 16) {
        uuid += chars[random.nextInt(4) + 8];
      } else {
        uuid += chars[random.nextInt(16)];
      }
    }
    return uuid;
  }
}
