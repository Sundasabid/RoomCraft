import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'surface.dart';

Surface3D createPlatformSurface(void Function(String json) onMessage) =>
    _IFrameSurface(onMessage);

/// The bundled page in a same-origin iframe. Both directions use
/// postMessage: the page sends {roomcraft: json}, and receives
/// {roomcraftIn: json}.
class _IFrameSurface implements Surface3D {
  _IFrameSurface(this._onMessage) {
    _frame.style
      ..border = 'none'
      ..width = '100%'
      ..height = '100%'
      ..display = 'block';
    _frame.setAttribute('title', '3D room');
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _frame,
    );
    _listener = ((web.MessageEvent e) {
      if (e.source != _frame.contentWindow) return;
      final data = e.data.dartify();
      if (data is Map && data['roomcraft'] is String) {
        _onMessage(data['roomcraft'] as String);
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  static int _count = 0;
  final void Function(String) _onMessage;
  final _frame = web.HTMLIFrameElement();
  late final String _viewType = 'roomcraft-3d-${_count++}';
  late final JSFunction _listener;
  int _loads = 0;

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);

  @override
  void post(String json) => _frame.contentWindow?.postMessage(
    {'roomcraftIn': json}.jsify(),
    '*'.toJS,
  );

  @override
  void load() {
    final url = ui_web.assetManager.getAssetUrl('assets/web3d/index.html');
    _frame.src = '$url?load=${_loads++}';
  }

  @override
  void setBackground(Color color) {
    final rgb = (color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    _frame.style.background = '#$rgb';
  }

  @override
  void dispose() => web.window.removeEventListener('message', _listener);
}
