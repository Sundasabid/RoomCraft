import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'messages.dart';

/// Two-way channel to the 3D layer running inside the WebView.
///
/// Outgoing messages wait until the page reports `ready`. `item.preview`
/// messages are coalesced so only the newest per item goes out each frame.
class SceneBridge {
  SceneBridge(this.controller, {required this.onReady}) {
    controller.addJavaScriptChannel('Bridge', onMessageReceived: _receive);
  }

  final WebViewController controller;

  /// Called on every `ready`, including after a reload; the owner answers with
  /// `init`.
  final VoidCallback onReady;

  final _incoming = StreamController<WebMessage>.broadcast();
  final _queue = <Map<String, Object?>>[];
  final _previews = <String, Map<String, Object?>>{};
  bool _ready = false;
  bool _frameScheduled = false;
  int _seq = 0;

  Stream<WebMessage> get messages => _incoming.stream;
  bool get isReady => _ready;

  void send(String type, [Map<String, Object?> payload = const {}]) {
    final message = {'t': type, ...payload};
    if (!_ready) {
      _queue.add(message);
      return;
    }
    _post(message);
  }

  void sendPreview(String id, double x, double z) {
    _previews[id] = {'t': ToWeb.itemPreview, 'id': id, 'x': x, 'z': z};
    if (_frameScheduled || !_ready) return;
    _frameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _frameScheduled = false;
      final pending = _previews.values.toList();
      _previews.clear();
      pending.forEach(_post);
    });
  }

  /// The page is about to reload (context loss); hold messages until it is back.
  void markNotReady() => _ready = false;

  void _post(Map<String, Object?> message) {
    message['seq'] = ++_seq;
    final literal = jsonEncode(jsonEncode(message));
    unawaited(
      controller
          .runJavaScript(
            'window.roomcraft && window.roomcraft.receive($literal)',
          )
          .catchError((Object e) => debugPrint('bridge send failed: $e')),
    );
  }

  void _receive(JavaScriptMessage raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw.message);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, Object?>) return;
    final type = decoded['t'];
    if (type is! String) return;
    if (type == FromWeb.ready) {
      _ready = true;
      onReady();
      final queued = List.of(_queue);
      _queue.clear();
      queued.forEach(_post);
    }
    _incoming.add(WebMessage(type, decoded));
  }

  void dispose() => _incoming.close();
}
