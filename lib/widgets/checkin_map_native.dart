import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Native map widget — dùng WebView để hiển thị Google Maps Embed
Widget buildMapWidget(double lat, double lng) {
  final String mapHtml = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  body { margin: 0; padding: 0; background-color: transparent; }
  iframe { width: 100vw; height: 100vh; border: none; }
</style>
</head>
<body>
  <iframe src="https://maps.google.com/maps?q=$lat,$lng&hl=vi&z=16&output=embed"></iframe>
</body>
</html>
''';

  final controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.transparent)
    ..loadHtmlString(mapHtml);

  return WebViewWidget(controller: controller);
}
