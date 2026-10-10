import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/core/units.dart';

void main() {
  test('feet are only a display conversion', () {
    expect(DisplayUnit.feet.format(3.048), '10.0 ft');
    expect(DisplayUnit.metres.formatSize(1.6, 2.0), '1.6 x 2.0 m');
    expect(DisplayUnit.feet.toMetres(10), closeTo(3.048, 1e-9));
  });
}
