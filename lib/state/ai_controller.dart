import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_service.dart';
import '../data/supabase_client.dart';
import '../domain/ai/ai_input_builder.dart';
import '../domain/checks/layout_validator.dart';
import '../domain/scene/scene.dart';

/// The three real stages, shown in turn while working.
enum AiStage { reading, asking, checking }

sealed class AiState {
  const AiState();
}

class AiIdle extends AiState {
  const AiIdle();
}

class AiWorking extends AiState {
  const AiWorking(this.stage);
  final AiStage stage;
}

class AiResults extends AiState {
  const AiResults(this.evaluation);
  final LayoutEvaluation evaluation;
}

class AiFailed extends AiState {
  const AiFailed(this.error);
  final AiError error;
}

/// Runs one suggestion request. Each stage starts only when the previous one
/// has actually finished; nothing is timed for show.
class AiController extends Notifier<AiState> {
  int _run = 0;

  @override
  AiState build() => const AiIdle();

  /// Starts a request for [scene]. A newer request or [cancel] makes any
  /// earlier one drop its result.
  Future<void> suggest(Scene scene, String goal) async {
    final run = ++_run;
    final service = ref.read(aiServiceProvider);
    state = const AiWorking(AiStage.reading);
    final input = AiInputBuilder.build(scene);
    if (service == null) {
      state = const AiFailed(AiError.unavailable);
      return;
    }
    await Future<void>.delayed(Duration.zero); // lets the first stage paint
    if (run != _run) return;
    state = const AiWorking(AiStage.asking);
    LayoutEvaluation? evaluation;
    var feedback = const <Map<String, Object?>>[];
    // Up to two rounds: if fewer than two layouts pass, the app's reasons go
    // back to the AI once so it can correct them.
    for (var round = 0; round < 2; round++) {
      final List<Object?> candidates;
      try {
        candidates = await service.suggest(
          goal: goal,
          input: input.json,
          feedback: feedback,
        );
      } on AiFailure catch (e) {
        if (run != _run) return;
        if (evaluation != null) break; // keep what the first round found
        state = AiFailed(e.error);
        return;
      } on Exception {
        if (run != _run) return;
        if (evaluation != null) break;
        state = const AiFailed(AiError.unavailable);
        return;
      }
      if (run != _run) return;
      state = const AiWorking(AiStage.checking);
      await Future<void>.delayed(Duration.zero); // lets "Checking" paint first
      if (run != _run) return;
      final checked = LayoutValidator.evaluate(scene, candidates);
      evaluation = evaluation == null ? checked : evaluation.merge(checked);
      if (evaluation.options.length >= 2) break;
      feedback = LayoutValidator.feedback(scene, candidates);
      if (feedback.isEmpty || round == 1) break;
      state = const AiWorking(AiStage.asking);
    }
    state = AiResults(evaluation!);
  }

  void cancel() {
    _run++;
    state = const AiIdle();
  }

  /// Back to Ask without losing results that the user wants to reopen.
  void reset() => state = const AiIdle();
}

final aiControllerProvider =
    NotifierProvider.autoDispose<AiController, AiState>(AiController.new);
