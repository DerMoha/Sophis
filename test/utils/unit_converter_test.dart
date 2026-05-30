import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/app_settings.dart';
import 'package:sophis/utils/unit_converter.dart';

void main() {
  group('UnitConverter', () {
    test('converted metric and imperial values both directions', () {
      expect(UnitConverter.kgToLb(10), closeTo(22.0462, 0.0001));
      expect(UnitConverter.lbToKg(22.0462), closeTo(10, 0.0001));
      expect(UnitConverter.cmToIn(180), closeTo(70.8662, 0.0001));
      expect(UnitConverter.inToCm(70.8662), closeTo(180, 0.001));
      expect(UnitConverter.mlToOz(500), closeTo(16.907, 0.001));
      expect(UnitConverter.ozToMl(16.907), closeTo(500, 0.01));
    });

    test('returned display and input values for selected unit system', () {
      expect(UnitConverter.displayWeight(80, UnitSystem.metric), 80);
      expect(
        UnitConverter.displayWeight(80, UnitSystem.imperial),
        closeTo(176.3696, 0.0001),
      );
      expect(
        UnitConverter.inputToKg(176.3696, UnitSystem.imperial),
        closeTo(80, 0.001),
      );
      expect(
        UnitConverter.inputToCm(70.8662, UnitSystem.imperial),
        closeTo(180, 0.001),
      );
      expect(
        UnitConverter.inputToMl(16.907, UnitSystem.imperial),
        closeTo(500, 0.01),
      );
    });

    test('formatted localized unit strings', () {
      expect(UnitConverter.formatWeight(80, UnitSystem.metric), '80.0 kg');
      expect(UnitConverter.formatWeight(80, UnitSystem.imperial), '176.4 lb');
      expect(UnitConverter.formatHeight(180, UnitSystem.metric), '180 cm');
      expect(UnitConverter.formatHeight(180, UnitSystem.imperial), '5\' 11"');
      expect(UnitConverter.formatWater(500, UnitSystem.metric), '500 ml');
      expect(UnitConverter.formatWater(1500, UnitSystem.metric), '1.5 L');
      expect(UnitConverter.formatWaterShort(500, UnitSystem.imperial), '17 oz');
      expect(UnitConverter.weightUnit(UnitSystem.imperial), 'lb');
      expect(UnitConverter.heightUnit(UnitSystem.metric), 'cm');
      expect(UnitConverter.waterUnitShort(UnitSystem.metric), 'ml');
    });
  });
}
