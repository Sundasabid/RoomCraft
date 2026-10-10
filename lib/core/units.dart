/// Metres are stored everywhere; feet exist only on screen.
enum DisplayUnit { metres, feet }

const double metresPerFoot = 0.3048;

extension DisplayUnitFormat on DisplayUnit {
  String get symbol => this == DisplayUnit.feet ? 'ft' : 'm';

  double fromMetres(double m) =>
      this == DisplayUnit.feet ? m / metresPerFoot : m;

  double toMetres(double v) => this == DisplayUnit.feet ? v * metresPerFoot : v;

  /// "4.2 m" or "13.8 ft". One decimal is enough for room planning.
  String format(double metres, {int decimals = 1}) =>
      '${fromMetres(metres).toStringAsFixed(decimals)} $symbol';

  /// "1.6 x 2.0 m": the unit is written once.
  String formatSize(double w, double d) =>
      '${fromMetres(w).toStringAsFixed(1)} x ${fromMetres(d).toStringAsFixed(1)} $symbol';
}
