import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:io' show Platform;

class DeviceService {
  static Future<Map<String, dynamic>> getInfo() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('device_id');
    
    if (id == null) {
      id = 'FLUTTER-${_generateUUID()}';
      await prefs.setString('device_id', id);
    }

    String os = 'Unknown';
    if (Platform.isAndroid) os = 'Android';
    if (Platform.isIOS) os = 'iOS';

    return {
      'id': id,
      'model': os == 'Android' ? 'Android Device' : 'Apple Device',
      'os': os,
    };
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
