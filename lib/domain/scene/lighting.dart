import '../../core/strings.dart';

/// A lighting mood for the whole room. The 3D layer owns the actual light
/// values; this side only names the moods and gives each a swatch colour.
class LightingPreset {
  const LightingPreset({
    required this.id,
    required this.label,
    required this.argb,
  });

  final String id;
  final String label;

  /// Swatch colour that hints at the mood.
  final int argb;
}

abstract final class Lighting {
  static const fallback = 'day';

  static const all = <LightingPreset>[
    LightingPreset(id: 'day', label: S.lightDay, argb: 0xFFFFE9B8),
    LightingPreset(id: 'golden', label: S.lightGolden, argb: 0xFFFFA85C),
    LightingPreset(id: 'evening', label: S.lightEvening, argb: 0xFF39457A),
    LightingPreset(id: 'soft', label: S.lightSoft, argb: 0xFFE4E8E4),
  ];

  static bool has(String id) => all.any((p) => p.id == id);
}
