import 'package:flutter/widgets.dart';

/// [d], or zero when the system asks for reduced motion.
Duration motion(BuildContext context, Duration d) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
