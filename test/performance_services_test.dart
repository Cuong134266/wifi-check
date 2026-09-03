import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_checkin_flutter/services/public_ip_service.dart';
import 'package:wifi_checkin_flutter/utils/coordinate_utils.dart';

void main() {
  group('PublicIpService Performance & Cache Tests', () {
    test('verify with knownIp uses provided IP without network call', () async {
      final settings = {
        'office_public_ip': '14.161.22.45, 118.70.12.34',
      };

      // Test matching known IP
      final matchResult = await PublicIpService.verify(
        settings,
        knownIp: '14.161.22.45',
      );
      expect(matchResult['verified'], isTrue);
      expect(matchResult['public_ip'], equals('14.161.22.45'));

      // Test IP with space inside and newlines in settings
      final messySettings = {
        'office_public_ip': "113.185.40.104, 113.185.41.1 98,\n113.185.45.22",
      };
      final messyResult = await PublicIpService.verify(
        messySettings,
        knownIp: '113.185.41.198',
      );
      expect(messyResult['verified'], isTrue);

      // Test non-matching known IP
      final nonMatchResult = await PublicIpService.verify(
        settings,
        knownIp: '1.2.3.4',
      );
      expect(nonMatchResult['verified'], isFalse);
      expect(nonMatchResult['public_ip'], equals('1.2.3.4'));
    });

    test('verify skips check when office_public_ip is empty', () async {
      final settings = {'office_public_ip': ''};
      final result = await PublicIpService.verify(settings, knownIp: '1.2.3.4');
      expect(result['verified'], isTrue);
      expect(result['skipped'], isTrue);
    });
  });

  group('CoordinateUtils Tests', () {
    test('distance calculation within office radius', () {
      const officeLat = 21.0078017;
      const officeLng = 105.8071089;

      final distance = CoordinateUtils.distanceMeters(
        officeLat,
        officeLng,
        officeLat + 0.0003,
        officeLng + 0.0003,
      );

      expect(distance, lessThan(2000));
    });
  });
}
