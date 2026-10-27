import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  late final String _viewType;
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _viewType = 'lune-tarot-${identityHashCode(this)}';
    _iframe = html.IFrameElement()
      ..src = 'assets/assets/lune/index.html?v=22-fan-fit'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.background = 'transparent'
      ..setAttribute('title', 'Bộ bài LUNE check-in')
      ..setAttribute('allow', 'autoplay');

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );

    _messageSubscription = html.window.onMessage.listen((event) {
      // Window wrappers from a platform-view iframe are not guaranteed to be
      // referentially equal in compiled Flutter web. Validate the same-origin
      // message instead; otherwise valid card selections are silently dropped.
      if (event.origin != html.window.location.origin ||
          event.data is! String) {
        return;
      }
      try {
        final payload = jsonDecode(event.data as String);
        if (payload is Map && payload['type'] == 'lune-card-selected') {
          final card = payload['card'];
          if (card is Map) {
            widget.onCardSelected(Map<String, dynamic>.from(card));
          }
        }
      } catch (_) {}
    });
    widget.checkinStatus.addListener(_sendCheckinStatus);
  }

  void _sendCheckinStatus() {
    final status = widget.checkinStatus.value;
    if (status == null) return;
    _iframe.contentWindow?.postMessage(
      jsonEncode({'type': 'lune-checkin-status', ...status}),
      html.window.location.origin,
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
    _messageSubscription?.cancel();
    _iframe.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
