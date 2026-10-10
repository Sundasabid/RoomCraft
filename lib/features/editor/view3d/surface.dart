import 'package:flutter/widgets.dart';

import 'surface_mobile.dart' if (dart.library.js_interop) 'surface_web.dart';

/// Where the 3D page runs: a WebView on phones, an iframe in the browser.
/// The rest of the app only sees these few calls.
abstract class Surface3D {
  /// Shows the page.
  Widget build(BuildContext context);

  /// Delivers one JSON message to the page.
  void post(String json);

  /// Loads the page, or loads it again after a failure.
  void load();

  void setBackground(Color color);

  void dispose();
}

/// Creates the right surface for this platform. [onMessage] receives every
/// JSON message the page sends.
Surface3D createSurface(void Function(String json) onMessage) =>
    createPlatformSurface(onMessage);
