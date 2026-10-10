import '../../core/strings.dart';

enum FinishTarget { item, floor, wall }

class Finish {
  const Finish({
    required this.id,
    required this.label,
    required this.argb,
    required this.roughness,
    required this.appliesTo,
  });

  final String id;
  final String label;

  /// 0xAARRGGBB, kept as an int so the domain stays free of Flutter.
  final int argb;
  final double roughness;
  final Set<FinishTarget> appliesTo;

  String get hex => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'hex': hex,
    'roughness': roughness,
    'appliesTo': [for (final t in appliesTo) t.name],
  };
}

abstract final class Finishes {
  static const all = <Finish>[
    Finish(
      id: 'oak',
      label: S.finishOak,
      argb: 0xFFB98B5E,
      roughness: 0.60,
      appliesTo: {FinishTarget.item, FinishTarget.floor},
    ),
    Finish(
      id: 'walnut',
      label: S.finishWalnut,
      argb: 0xFF7A5230,
      roughness: 0.55,
      appliesTo: {FinishTarget.item, FinishTarget.floor},
    ),
    Finish(
      id: 'white_lacquer',
      label: S.finishWhiteLacquer,
      argb: 0xFFF4F1EA,
      roughness: 0.25,
      appliesTo: {FinishTarget.item},
    ),
    Finish(
      id: 'sage_fabric',
      label: S.finishSageFabric,
      argb: 0xFF6B8F71,
      roughness: 0.95,
      appliesTo: {FinishTarget.item},
    ),
    Finish(
      id: 'beige_linen',
      label: S.finishBeigeLinen,
      argb: 0xFFD9C8AA,
      roughness: 0.95,
      appliesTo: {FinishTarget.item},
    ),
    Finish(
      id: 'light_oak',
      label: S.finishLightOak,
      argb: 0xFFD2B48C,
      roughness: 0.60,
      appliesTo: {FinishTarget.floor},
    ),
    Finish(
      id: 'warm_white',
      label: S.finishWarmWhite,
      argb: 0xFFF7F3EC,
      roughness: 0.90,
      appliesTo: {FinishTarget.wall},
    ),
    Finish(
      id: 'sand',
      label: S.finishSand,
      argb: 0xFFE6D9C3,
      roughness: 0.90,
      appliesTo: {FinishTarget.wall},
    ),
    Finish(
      id: 'sage_wall',
      label: S.finishSage,
      argb: 0xFFA9BFA9,
      roughness: 0.90,
      appliesTo: {FinishTarget.wall},
    ),
  ];

  static final Map<String, Finish> _byId = {for (final f in all) f.id: f};

  static Finish byId(String id) =>
      _byId[id] ?? (throw ArgumentError.value(id, 'finish', 'unknown'));

  static bool has(String id) => _byId.containsKey(id);

  static List<Finish> forTarget(FinishTarget t) => [
    for (final f in all)
      if (f.appliesTo.contains(t)) f,
  ];
}
