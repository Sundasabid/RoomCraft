import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../state/settings_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/motion.dart';
import 'onboarding_art.dart';

/// One welcome page: a solid colour, its ink, the button colours and art.
class _Page {
  const _Page({
    required this.title,
    required this.body,
    required this.bg,
    required this.fg,
    required this.buttonFill,
    required this.buttonText,
    required this.art,
  });

  final String title;
  final String body;
  final Color bg;
  final Color fg;
  final Color buttonFill;
  final Color buttonText;
  final CustomPainter Function(double t) art;
}

/// Three solid-colour pages shown on first launch and from Settings.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  double _position = 0;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() => setState(() => _position = _pages.page ?? 0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Gentle floating art, still when the phone asks for less motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _float
        ..stop()
        ..value = 0;
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _float.dispose();
    super.dispose();
  }

  List<_Page> _content(RoomCraftColors c) => [
    _Page(
      title: S.onboardDesignTitle,
      body: S.onboardDesignBody,
      bg: c.primaryAction,
      fg: c.onPrimaryAction,
      buttonFill: c.sunflower,
      buttonText: c.onAccent,
      art: (t) => DesignArt(c, t),
    ),
    _Page(
      title: S.onboard3dTitle,
      body: S.onboard3dBody,
      bg: c.coral,
      fg: c.onAccent,
      buttonFill: c.onAccent,
      buttonText: c.highlight,
      art: (t) => ThreeDArt(c, t),
    ),
    _Page(
      title: S.onboardLiveTitle,
      body: S.onboardLiveBody,
      bg: c.sky,
      fg: c.highlight,
      buttonFill: c.sunflower,
      buttonText: c.onAccent,
      art: (t) => LiveArt(c, t, code: 'ABC234', live: S.live),
    ),
  ];

  void _finish() {
    ref.read(settingsProvider.notifier).setOnboarded(true);
    context.go('/rooms');
  }

  void _next(int index, int count) {
    if (index >= count - 1) {
      _finish();
      return;
    }
    _pages.nextPage(
      duration: motion(context, Motion.sheet),
      curve: Motion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pages = _content(c);
    final index = _position.round().clamp(0, pages.length - 1);
    final page = pages[index];
    // The background blends between pages as you swipe.
    final i = _position.floor().clamp(0, pages.length - 1);
    final j = (i + 1).clamp(0, pages.length - 1);
    final bg = Color.lerp(pages[i].bg, pages[j].bg, _position - i)!;
    final fg = page.fg;
    final last = index == pages.length - 1;
    final darkInk = fg.computeLuminance() < 0.5;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkInk ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Sizes.maxFormWidth),
              child: Column(
                children: [
                  SizedBox(
                    height: Sizes.appBar,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedOpacity(
                        opacity: last ? 0 : 1,
                        duration: motion(context, Motion.fast),
                        child: RoomCraftTextButton(
                          label: S.skip,
                          color: fg,
                          onPressed: last ? null : _finish,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: pages.length,
                      itemBuilder: (context, n) => _PageBody(
                        page: pages[n],
                        float: _float,
                        label: S.pageOf(n + 1, pages.length),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  _Dots(count: pages.length, position: _position, color: fg),
                  Padding(
                    padding: const EdgeInsets.all(Space.xl),
                    child: PrimaryButton(
                      label: last ? S.getStarted : S.next,
                      fill: page.buttonFill,
                      foreground: page.buttonText,
                      onPressed: () => _next(index, pages.length),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.page,
    required this.float,
    required this.label,
  });

  final _Page page;
  final Animation<double> float;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: label,
      child: LayoutBuilder(
        builder: (context, box) {
          // The art takes what the text leaves; short screens scroll.
          final art = (box.maxHeight * 0.6).clamp(0.0, 360.0);
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: art,
                      width: double.infinity,
                      child: ExcludeSemantics(
                        child: AnimatedBuilder(
                          animation: float,
                          builder: (context, _) =>
                              CustomPaint(painter: page.art(float.value)),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    Text(
                      page.title,
                      textAlign: TextAlign.center,
                      style: RoomCraftTheme.heading(
                        c,
                        TypeScale.onboarding,
                      ).copyWith(color: page.fg),
                    ),
                    const SizedBox(height: Space.md),
                    Text(
                      page.body,
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(color: page.fg),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Page dots; the current one stretches into a pill.
class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.position,
    required this.color,
  });

  final int count;
  final double position;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Builder(
            builder: (context) {
              final near = (1 - (position - i).abs()).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: Space.xs),
                width: Space.sm + Space.lg * near,
                height: Space.sm,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.4 + 0.6 * near),
                  borderRadius: BorderRadius.circular(Radii.round),
                ),
              );
            },
          ),
      ],
    ),
  );
}
