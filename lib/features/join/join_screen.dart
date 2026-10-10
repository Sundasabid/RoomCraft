import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics.dart';
import '../../core/strings.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/supabase_client.dart';
import '../../domain/share/share_code.dart';
import '../../state/connectivity_provider.dart';
import '../../widgets/buttons.dart';
import '../../widgets/motion.dart';
import '../../widgets/steps.dart';
import '../onboarding/onboarding_art.dart';

/// Six boxes for a share code. One hidden field drives them, so typing,
/// backspace and paste all behave like a normal text field.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({this.error, super.key});

  /// A message carried back from the viewer, such as "No live room".
  final String? error;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen>
    with SingleTickerProviderStateMixin {
  final _text = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: Motion.medium,
  );
  String? _error;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _error = widget.error;
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _badLetters() {
    setState(() => _error = S.badLetters);
  }

  void _changed(String v) {
    if (_error == S.noRoom) setState(() => _error = null);
    if (v.length == shareCodeLength) unawaited(_join());
  }

  Future<void> _join() async {
    final code = _text.text;
    if (!isShareCode(code) || _joining) return;
    final service = ref.read(shareServiceProvider);
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final row = await service?.fetch(code);
      if (!mounted) return;
      if (row == null) {
        setState(() => _error = S.noRoom);
        _shake.duration = motion(context, Motion.medium);
        unawaited(_shake.forward(from: 0));
        return;
      }
      unawaited(Haptics.lightImpact());
      // Pushed, so the back key returns here rather than closing the app.
      unawaited(context.push('/viewer/$code'));
    } on Exception {
      if (mounted) setState(() => _error = S.genericError);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final online = ref.watch(isOnlineProvider);
    final code = _text.text;
    final side = MediaQuery.sizeOf(context).width >= Sizes.tabletBreakpoint
        ? Space.xl
        : Space.lg;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: side,
        toolbarHeight: Sizes.tabBar,
        title: Text(
          S.liveTitle,
          style: RoomCraftTheme.heading(context.colors, TypeScale.display),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.maxFormWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(side, Space.sm, side, Space.xl),
              children: [
                const _Hero(),
                const SizedBox(height: Space.xl),
                Text(S.liveCodeLabel, style: text.titleMedium),
                const SizedBox(height: Space.md),
                // The real input: invisible, but focused and pasteable.
                SizedBox(
                  height: 0,
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      enabled: online,
                      maxLength: shareCodeLength,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      keyboardType: TextInputType.visiblePassword,
                      inputFormatters: [_CodeFormatter(onRefused: _badLetters)],
                      onChanged: _changed,
                      onSubmitted: (_) => _join(),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      math.sin(_shake.value * math.pi * 4) *
                          8 *
                          (1 - _shake.value),
                      0,
                    ),
                    child: child,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      _focus.requestFocus();
                      SystemChannels.textInput.invokeMethod<void>(
                        'TextInput.show',
                      );
                    },
                    child: Semantics(
                      label: '${S.liveCodeLabel}: ${code.split('').join(' ')}',
                      textField: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < shareCodeLength; i++) ...[
                            if (i > 0) const SizedBox(width: Space.sm),
                            Flexible(
                              child: _Box(
                                char: i < code.length ? code[i] : '',
                                active:
                                    _focus.hasFocus &&
                                    i ==
                                        math.min(
                                          code.length,
                                          shareCodeLength - 1,
                                        ),
                                error: _error == S.noRoom,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: motion(context, Motion.fast),
                  child: (!online || _error != null)
                      ? Padding(
                          padding: const EdgeInsets.only(top: Space.md),
                          child: Text(
                            !online ? S.offlineJoin : _error!,
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(
                              color: online ? c.warningText : c.textSecondary,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: Space.lg),
                PrimaryButton(
                  label: S.joinRoom,
                  icon: Icons.visibility_rounded,
                  loading: _joining,
                  onPressed: online && isShareCode(code) ? _join : null,
                ),
                const SizedBox(height: Space.xxl),
                Text(S.howItWorks, style: text.titleMedium),
                const SizedBox(height: Space.md),
                NumberedStep(
                  number: 1,
                  color: c.primaryAction,
                  ink: c.onPrimaryAction,
                  text: S.liveStep1,
                ),
                NumberedStep(
                  number: 2,
                  color: c.coral,
                  ink: c.onAccent,
                  text: S.liveStep2,
                ),
                NumberedStep(
                  number: 3,
                  color: c.sunflower,
                  ink: c.onAccent,
                  text: S.liveStep3,
                ),
                const SizedBox(height: Space.lg),
                Container(
                  padding: const EdgeInsets.all(Space.lg),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(Radii.card),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sensors_rounded, color: c.primary),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Text(S.liveOwnRoom, style: text.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.char, required this.active, required this.error});

  final String char;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: motion(context, Motion.fast),
      // Six boxes shrink together on the narrowest phones.
      constraints: const BoxConstraints(maxWidth: Sizes.touch),
      height: Sizes.field,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(
          color: error
              ? c.warning
              : active
              ? c.primary
              : c.fieldBorder,
          width: error || active ? 2 : 1,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          char,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Uppercases and keeps only letters from the code alphabet; reports when
/// something was refused.
class _CodeFormatter extends TextInputFormatter {
  _CodeFormatter({required this.onRefused});

  final VoidCallback onRefused;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = normaliseCode(newValue.text);
    final kept = cleaned
        .split('')
        .where(shareAlphabet.contains)
        .take(shareCodeLength)
        .join();
    if (kept.length < cleaned.length && kept.length < shareCodeLength) {
      onRefused();
    }
    return TextEditingValue(
      text: kept,
      selection: TextSelection.collapsed(offset: kept.length),
    );
  }
}

/// A solid sky card that says in one line what watching live means.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.sky,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: LiveArt(c, 0.25, code: 'ABC234', live: S.live),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Text(
            S.liveHero,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: c.highlight),
          ),
        ],
      ),
    );
  }
}
