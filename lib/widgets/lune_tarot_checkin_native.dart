import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LuneTarotCheckin extends StatefulWidget {
  const LuneTarotCheckin({
    required this.onCardSelected,
    required this.checkinStatus,
    super.key,
  });

  final ValueChanged<Map<String, dynamic>> onCardSelected;
  final ValueListenable<Map<String, dynamic>?> checkinStatus;

  @override
  State<LuneTarotCheckin> createState() => _LuneTarotCheckinState();
}

class _LuneTarotCheckinState extends State<LuneTarotCheckin> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          'LuneCheckin',
          onMessageReceived: (message) {
            try {
              final payload = jsonDecode(message.message);
              if (payload is Map && payload['type'] == 'lune-card-selected') {
                final card = payload['card'];
                if (card is Map) {
                  widget.onCardSelected(Map<String, dynamic>.from(card));
                }
              }
            } catch (_) {}
          },
        )
        ..loadFlutterAsset('assets/lune/index.html');
      widget.checkinStatus.addListener(_sendCheckinStatus);
    } catch (_) {
      _controller = null;
    }
  }

  void _sendCheckinStatus() {
    final status = widget.checkinStatus.value;
    final controller = _controller;
    if (status == null || controller == null) return;
    final message = jsonEncode({'type': 'lune-checkin-status', ...status});
    controller.runJavaScript(
      'window.postMessage(${jsonEncode(message)}, "*");',
    );
  }

  @override
  void didUpdateWidget(covariant LuneTarotCheckin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkinStatus != widget.checkinStatus) {
      oldWidget.checkinStatus.removeListener(_sendCheckinStatus);
      widget.checkinStatus.addListener(_sendCheckinStatus);
    }
  }

  @override
  void dispose() {
    widget.checkinStatus.removeListener(_sendCheckinStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return ClipRect(child: WebViewWidget(controller: controller));
  }
}
