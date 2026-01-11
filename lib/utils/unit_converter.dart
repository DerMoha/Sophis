import '../models/app_settings.dart';

/// Utility class for converting between metric and imperial units.
/// All data is stored in metric internally; this class converts for display.
class UnitConverter {
  // Conversion constants
  static const double kgToLbs = 2.20462;
  static const double cmToInches = 0.393701;
  static const double mlToFlOz = 0.033814;

  // Weight conversions
  static double kgToLb(double kg) => kg * kgToLbs;
  static double lbToKg(double lb) => lb / kgToLbs;

  // Height conversions
  static double cmToIn(double cm) => cm * cmToInches;
  static double inToCm(double inches) => inches / cmToInches;

  // Water conversions
  static double mlToOz(double ml) => ml * mlToFlOz;
  static double ozToMl(double oz) => oz / mlToFlOz;

  // Display value based on unit system (for inputs/display)
  static double displayWeight(double kg, UnitSystem system) {
    return system == UnitSystem.imperial ? kgToLb(kg) : kg;
  }

  static double displayHeight(double cm, UnitSystem system) {
    return system == UnitSystem.imperial ? cmToIn(cm) : cm;
  }

  static double displayWater(double ml, UnitSystem system) {
    return system == UnitSystem.imperial ? mlToOz(ml) : ml;
  }

  // Convert input back to metric for storage
  static double inputToKg(double value, UnitSystem system) {
    return system == UnitSystem.imperial ? lbToKg(value) : value;
  }

  static double inputToCm(double value, UnitSystem system) {
    return system == UnitSystem.imperial ? inToCm(value) : value;
  }

  static double inputToMl(double value, UnitSystem system) {
    return system == UnitSystem.imperial ? ozToMl(value) : value;
  }

  // Formatted display strings
  static String formatWeight(double kg, UnitSystem system, {int decimals = 1}) {
    if (system == UnitSystem.imperial) {
      return '${kgToLb(kg).toStringAsFixed(decimals)} lb';
    }
    return '${kg.toStringAsFixed(decimals)} kg';
  }

  static String formatHeight(double cm, UnitSystem system) {
    if (system == UnitSystem.imperial) {
      final totalInches = cmToIn(cm);
      final feet = (totalInches / 12).floor();
      final inches = (totalInches % 12).round();
      return '$feet\' $inches"';
    }
    return '${cm.toStringAsFixed(0)} cm';
  }

  static String formatWater(double ml, UnitSystem system) {
    if (system == UnitSystem.imperial) {
      return '${mlToOz(ml).toStringAsFixed(1)} fl oz';
    }
    // Show in liters if >= 1000ml
    if (ml >= 1000) {
      return '${(ml / 1000).toStringAsFixed(1)} L';
    }
    return '${ml.toStringAsFixed(0)} ml';
  }

  static String formatWaterShort(double ml, UnitSystem system) {
    if (system == UnitSystem.imperial) {
      return '${mlToOz(ml).toStringAsFixed(0)} oz';
    }
    return '${ml.toStringAsFixed(0)} ml';
  }

  // Unit labels
  static String weightUnit(UnitSystem system) =>
      system == UnitSystem.imperial ? 'lb' : 'kg';

  static String heightUnit(UnitSystem system) =>
      system == UnitSystem.imperial ? 'in' : 'cm';

  static String waterUnit(UnitSystem system) =>
      system == UnitSystem.imperial ? 'fl oz' : 'ml';

  static String waterUnitShort(UnitSystem system) =>
      system == UnitSystem.imperial ? 'oz' : 'ml';
}
