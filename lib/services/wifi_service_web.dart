import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation: dùng WebRTC để lấy local IP (192.168.x.x)
Future<Map<String, dynamic>> getWifiInfo() async {
  final localIp = await _getLocalIPViaWebRTC();
  return {
    'ssid': 'Web Browser',
    'bssid': '',
    'ip': localIp ?? '',
    'connected': true,
    'web': true,
    'webrtc_ip': localIp ?? '',
  };
}

/// Lấy local IP qua WebRTC ICE candidate.
/// Trả null nếu trình duyệt chặn (Firefox strict mode, Brave, v.v.)
Future<String?> _getLocalIPViaWebRTC() async {
  final completer = Completer<String?>();

  try {
    final pc = html.RtcPeerConnection({'iceServers': []});

    // Cần tạo data channel để ICE gathering chạy
    pc.createDataChannel('probe');

    final offer = await pc.createOffer();
    final desc = offer as html.RtcSessionDescription;
    await pc.setLocalDescription({'type': desc.type, 'sdp': desc.sdp});

    // Lắng nghe ICE candidates, parse IP private từ SDP candidate string
    pc.onIceCandidate.listen((html.RtcPeerConnectionIceEvent event) {
      final candidate = event.candidate?.candidate ?? '';
      if (candidate.isEmpty) return;

      // Tìm private IP range: 192.168.x.x, 10.x.x.x, 172.16-31.x.x
      final match = RegExp(
        r'(192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})',
      ).firstMatch(candidate);

      if (match != null && !completer.isCompleted) {
        completer.complete(match.group(0));
        try { pc.close(); } catch (_) {}
      }
    });

    // Timeout 3s — nếu không lấy được thì trả null (chỉ dùng GPS)
    Future.delayed(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.complete(null);
        try { pc.close(); } catch (_) {}
      }
    });
  } catch (_) {
    if (!completer.isCompleted) completer.complete(null);
  }

  return completer.future;
}
