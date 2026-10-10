import '../../core/strings.dart';
import '../constants.dart';
import '../scene/nodes.dart';
import '../scene/scene.dart';
import 'movement_score.dart';
import 'placement_checker.dart';

/// One AI layout that passed every check.
class LayoutOption {
  const LayoutOption({
    required this.name,
    required this.reason,
    required this.scene,
    required this.score,
    required this.moved,
  });

  final String name;
  final String reason;
  final Scene scene;
  final int score;
  final int moved;
}

sealed class CandidateCheck {
  const CandidateCheck();
}

class CandidateAccepted extends CandidateCheck {
  const CandidateAccepted(this.scene, this.moved);
  final Scene scene;
  final int moved;
}

class CandidateRejected extends CandidateCheck {
  const CandidateRejected(this.reason, {this.problems = const []});
  final String reason;

  /// Every violation found, for feedback to the AI (the reason is the first).
  final List<String> problems;
}

class LayoutEvaluation {
  const LayoutEvaluation({
    required this.currentScore,
    required this.options,
    required this.rejected,
    required this.total,
  });

  final int currentScore;

  /// At most [maxOptions], best movement score first.
  final List<LayoutOption> options;

  /// One plain reason per rejected candidate.
  final List<String> rejected;
  final int total;

  /// Combines two rounds: best options overall, every rejection counted.
  LayoutEvaluation merge(LayoutEvaluation later) {
    final all = [...options, ...later.options]
      ..sort((a, b) => b.score.compareTo(a.score));
    return LayoutEvaluation(
      currentScore: currentScore,
      options: _bestOptions(all),
      rejected: [...rejected, ...later.rejected],
      total: total + later.total,
    );
  }
}

/// Up to [maxOptions] options that place the furniture differently; the AI
/// sometimes repeats a layout, and two identical cards help nobody.
/// How many layouts the panel shows at most.
const maxOptions = 3;

List<LayoutOption> _bestOptions(List<LayoutOption> ranked) {
  final kept = <LayoutOption>[];
  for (final o in ranked) {
    if (kept.length == maxOptions) break;
    if (kept.any((k) => k.scene == o.scene)) continue;
    kept.add(o);
  }
  return kept;
}

/// The AI proposes, this code decides. Nothing reaches the room unless it
/// passes here.
abstract final class LayoutValidator {
  static const allowedRotations = {0, 90, 180, 270};

  static double _snap(double v) =>
      ((v / grid).roundToDouble() * grid * 1000).roundToDouble() / 1000;

  /// Applies one candidate (`{items: [{id, x, z, rotation}]}`) to [current]
  /// and checks it.
  static CandidateCheck check(Scene current, Object? candidate) {
    if (candidate is! Map<String, Object?>) {
      return const CandidateRejected(S.aiBadShape);
    }
    final entries = candidate['items'];
    if (entries is! List<Object?>) return const CandidateRejected(S.aiBadShape);

    final movable = {
      for (final i in current.items)
        if (i.visible && !i.locked) i.id: i,
    };
    final lockedIds = {
      for (final i in current.items)
        if (i.locked) i.id,
    };
    final placed = <String, ItemNode>{};
    for (final e in entries) {
      if (e is! Map<String, Object?>) {
        return const CandidateRejected(S.aiBadShape);
      }
      final id = e['id'];
      if (id is! String) return const CandidateRejected(S.aiBadShape);
      if (lockedIds.contains(id)) continue; // locked items stay untouched
      final original = movable[id];
      if (original == null) return const CandidateRejected(S.aiUnknownItem);
      if (placed.containsKey(id)) {
        return CandidateRejected(S.aiRepeated(current.displayName(id)));
      }
      final x = e['x'], z = e['z'], rotation = e['rotation'];
      if (x is! num || z is! num || !x.isFinite || !z.isFinite) {
        return const CandidateRejected(S.aiBadNumber);
      }
      if (rotation is! num ||
          rotation != rotation.roundToDouble() ||
          !allowedRotations.contains(rotation.toInt())) {
        return const CandidateRejected(S.aiBadRotation);
      }
      placed[id] = original.copyWith(
        x: _snap(x.toDouble()),
        z: _snap(z.toDouble()),
        rotation: rotation.toInt(),
      );
    }
    for (final id in movable.keys) {
      if (!placed.containsKey(id)) {
        return CandidateRejected(S.aiMissing(current.displayName(id)));
      }
    }

    final moved = placed.values.where((n) {
      final o = movable[n.id]!;
      return n.x != o.x || n.z != o.z || n.rotation != o.rotation;
    }).length;
    final scene = current.withNodes(placed.values);
    final report = PlacementChecker.checkScene(scene);
    if (!report.isValid) {
      return CandidateRejected(
        report.violations.first.message,
        problems: [for (final v in report.violations) v.message],
      );
    }
    if (moved == 0) return const CandidateRejected(S.aiNoMove);
    return CandidateAccepted(scene, moved);
  }

  /// Checks every candidate, scores the valid ones and keeps the best.
  /// Lower scores are still shown with their honest change.
  static LayoutEvaluation evaluate(Scene current, List<Object?> candidates) {
    final currentScore = MovementScore.of(current).score;
    final valid = <LayoutOption>[];
    final rejected = <String>[];
    for (final c in candidates) {
      final result = check(current, c);
      switch (result) {
        case CandidateRejected(:final reason):
          rejected.add(reason);
        case CandidateAccepted(:final scene, :final moved):
          final map = c! as Map<String, Object?>;
          valid.add(
            LayoutOption(
              name: _text(map['name'], 40),
              reason: _text(map['reason'], 160),
              scene: scene,
              score: MovementScore.of(scene).score,
              moved: moved,
            ),
          );
      }
    }
    final ranked = [...valid.indexed]
      ..sort((a, b) {
        final byScore = b.$2.score.compareTo(a.$2.score);
        return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
      });
    return LayoutEvaluation(
      currentScore: currentScore,
      options: _bestOptions([for (final r in ranked) r.$2]),
      rejected: rejected,
      total: candidates.length,
    );
  }

  /// What to tell the AI about its rejected layouts so it can fix them.
  static List<Map<String, Object?>> feedback(
    Scene current,
    List<Object?> candidates,
  ) => [
    for (final c in candidates)
      if (check(current, c) case CandidateRejected(
        :final reason,
        :final problems,
      ))
        {
          'candidate': c,
          'problems': problems.isEmpty ? [reason] : problems,
        },
  ];

  static String _text(Object? v, int max) {
    final s = v is String ? v.trim() : '';
    return s.length <= max ? s : s.substring(0, max);
  }
}
