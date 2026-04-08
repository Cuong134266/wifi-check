import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Web map widget — dùng HtmlElementView + iframe vì WebView không chạy trên Web
Widget buildMapWidget(double lat, double lng) {
  final String viewType = 'google-map-$lat-$lng';
  
  // Đăng ký platform view factory cho iframe
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..src = 'https://maps.google.com/maps?q=$lat,$lng&hl=vi&z=16&output=embed'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'fullscreen';
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
