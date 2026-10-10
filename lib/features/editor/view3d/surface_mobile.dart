import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'surface.dart';

Surface3D createPlatformSurface(void Function(String json) onMessage) =>
    _WebViewSurface(onMessage);

/// The bundled page in a WebView; messages arrive on the JavaScript channel
/// named Bridge and go out through window.roomcraft.receive.
class _WebViewSurface implements Surface3D {
  _WebViewSurface(void Function(String) onMessage) {
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) =>
              r.url.startsWith('file:') || r.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..addJavaScriptChannel(
        'Bridge',
        onMessageReceived: (m) => onMessage(m.message),
      );
  }

  final _controller = WebViewController();

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);

  @override
  void post(String json) {
    final literal = jsonEncode(json);
    unawaited(
      _controller
          .runJavaScript(
            'window.roomcraft && window.roomcraft.receive($literal)',
          )
          .catchError((Object e) => debugPrint('bridge send failed: $e')),
    );
  }

  @override
  void load() =>
      unawaited(_controller.loadFlutterAsset('assets/web3d/index.html'));

  @override
  void setBackground(Color color) =>
      unawaited(_controller.setBackgroundColor(color));

  @override
  void dispose() {}
}
