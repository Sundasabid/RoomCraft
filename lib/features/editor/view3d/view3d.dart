import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../bridge/messages.dart';
import '../../../bridge/scene_bridge.dart';
import '../../../core/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../widgets/surfaces.dart';

/// False in widget tests, where no WebView exists.
final view3dEnabledProvider = Provider<bool>((ref) => true);

enum _Status { loading, ready, reloading, unavailable }

/// Hosts the 3D layer. It shows a calm placeholder until the page is ready,
/// reloads once after a WebGL failure, and falls back to a message if the
/// phone cannot show 3D at all.
class View3D extends ConsumerStatefulWidget {
  const View3D({
    required this.buildInit,
    required this.onReady,
    required this.onMessage,
    super.key,
  });

  /// Payload for `init`, built fresh on every `ready` (also after a reload).
  final Map<String, Object?> Function(SceneBridge bridge) buildInit;

  /// The page is ready and has its scene; send any states now.
  final void Function(SceneBridge bridge) onReady;
  final void Function(WebMessage message) onMessage;

  @override
  ConsumerState<View3D> createState() => _View3DState();
}

class _View3DState extends ConsumerState<View3D> {
  WebViewController? _controller;
  SceneBridge? _bridge;
  StreamSubscription<WebMessage>? _sub;
  _Status _status = _Status.loading;
  int _reloads = 0;
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    if (!ref.read(view3dEnabledProvider)) {
      _status = _Status.unavailable;
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) =>
              r.url.startsWith('file:') || r.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
    final bridge = SceneBridge(
      controller,
      onReady: () {
        _watchdog?.cancel();
        _bridge!.send(ToWeb.init, widget.buildInit(_bridge!));
        widget.onReady(_bridge!);
        if (mounted) setState(() => _status = _Status.ready);
      },
    );
    _sub = bridge.messages.listen(_onMessage);
    _controller = controller;
    _bridge = bridge;
    _load();
  }

  void _load() {
    _watchdog?.cancel();
    // A page that never reports ready cannot draw 3D here.
    _watchdog = Timer(const Duration(seconds: 12), () {
      if (mounted && _status != _Status.ready) {
        setState(() => _status = _Status.unavailable);
      }
    });
    unawaited(_controller!.loadFlutterAsset('assets/web3d/index.html'));
  }

  void _onMessage(WebMessage m) {
    if (m.type != FromWeb.error) {
      widget.onMessage(m);
      return;
    }
    if (m.data['fatal'] == true || _reloads >= 1) {
      setState(() => _status = _Status.unavailable);
      return;
    }
    _reloads++;
    _bridge!.markNotReady();
    setState(() => _status = _Status.reloading);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_controller?.setBackgroundColor(context.colors.background));
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    unawaited(_sub?.cancel());
    _bridge?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final controller = _controller;
    return Semantics(
      label: S.view3dLabel,
      container: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && _status != _Status.unavailable)
            ExcludeSemantics(child: WebViewWidget(controller: controller)),
          if (_status == _Status.unavailable)
            ColoredBox(
              color: c.surfaceAlt,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.all(Space.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.view_in_ar_outlined,
                        color: c.textSecondary,
                        size: 32,
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        S.view3dUnavailable,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_status == _Status.loading)
            ColoredBox(
              color: c.surfaceAlt,
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.primary,
                  ),
                ),
              ),
            ),
          if (_status == _Status.reloading)
            const Positioned(
              left: Space.md,
              right: Space.md,
              bottom: Space.md,
              child: RoomCraftBanner(
                message: S.view3dReloading,
                tone: BannerTone.info,
                icon: Icons.refresh_rounded,
              ),
            ),
        ],
      ),
    );
  }
}
