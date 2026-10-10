import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Wraps a control that sits over the 3D view. In the browser the 3D view is
/// an iframe, which would otherwise take every click meant for the control;
/// on phones this changes nothing.
class Over3D extends StatelessWidget {
  const Over3D({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      kIsWeb ? PointerInterceptor(child: child) : child;
}
