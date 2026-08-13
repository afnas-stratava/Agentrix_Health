/// US-display conversions. The app's own data — [UserProfile], [Restaurant],
/// the BMR/macro formulas in `targets.dart` — stays in metric throughout;
/// these exist only to convert at the UI boundary (Steppers, labels), never
/// to change what gets stored or computed.
library;

const double _kgPerLb = 0.45359237;
const double _cmPerInch = 2.54;
const double _metresPerMile = 1609.344;

double kgToLb(double kg) => kg / _kgPerLb;

double lbToKg(double lb) => lb * _kgPerLb;

double cmToInches(double cm) => cm / _cmPerInch;

double inchesToCm(double inches) => inches * _cmPerInch;

double metresToMiles(double metres) => metres / _metresPerMile;

double metresToFeet(double metres) => cmToInches(metres * 100) / 12;

/// "5'10"" — the conventional US height format. [totalInches] is expected to
/// already be rounded to a whole inch, which is the precision the height
/// [Stepper] steps in.
String formatFeetInches(double totalInches) {
  final whole = totalInches.round();
  final feet = whole ~/ 12;
  final inches = whole % 12;
  return '$feet\'$inches"';
}
