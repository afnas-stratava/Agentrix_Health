import '../../domain/entities/gender.dart';
import '../../domain/entities/labs/biomarker.dart';

/// App-side reference table. Ported from
/// `src/features/labs/reference-ranges.ts`.
///
/// [low]/[high] mirror the conventional laboratory interval; [optimalLow]/
/// [optimalHigh] encode the tighter band associated with better outcomes in the
/// literature. The gap between them is where this product does its work — a
/// ferritin of 22 ng/mL is "normal" on every lab report in the world and is
/// still a plausible cause of suppressed HRV in an endurance athlete.
///
/// These are population defaults for adults. They are NOT a diagnosis, and
/// sex-specific intervals are applied in [resolveRange] where they matter.
class ReferenceDefinition {
  const ReferenceDefinition({
    required this.displayName,
    required this.category,
    required this.canonicalUnit,
    this.low,
    this.high,
    this.optimalLow,
    this.optimalHigh,
    this.female,
    this.unitConversions = const {},
  });

  final String displayName;
  final BiomarkerCategory category;
  final String canonicalUnit;
  final double? low;
  final double? high;
  final double? optimalLow;
  final double? optimalHigh;

  /// Female-specific overrides, applied when the profile declares one.
  final ReferenceOverride? female;

  /// Multipliers converting other common units into [canonicalUnit].
  final Map<String, double> unitConversions;
}

class ReferenceOverride {
  const ReferenceOverride({
    this.low,
    this.high,
    this.optimalLow,
    this.optimalHigh,
  });

  final double? low;
  final double? high;
  final double? optimalLow;
  final double? optimalHigh;
}

const Map<BiomarkerCode, ReferenceDefinition> referenceTable = {
  BiomarkerCode.ferritin: ReferenceDefinition(
    displayName: 'Ferritin',
    category: BiomarkerCategory.iron,
    canonicalUnit: 'ng/mL',
    low: 15,
    high: 300,
    optimalLow: 50,
    optimalHigh: 150,
    female: ReferenceOverride(high: 200, optimalLow: 40, optimalHigh: 120),
    unitConversions: {'µg/L': 1, 'ug/L': 1, 'mcg/L': 1},
  ),
  BiomarkerCode.hemoglobin: ReferenceDefinition(
    displayName: 'Haemoglobin',
    category: BiomarkerCategory.iron,
    canonicalUnit: 'g/dL',
    low: 13.5,
    high: 17.5,
    optimalLow: 14,
    optimalHigh: 16.5,
    female: ReferenceOverride(
      low: 12,
      high: 15.5,
      optimalLow: 12.5,
      optimalHigh: 15,
    ),
    unitConversions: {'g/L': 0.1},
  ),
  BiomarkerCode.transferrinSaturation: ReferenceDefinition(
    displayName: 'Transferrin Saturation',
    category: BiomarkerCategory.iron,
    canonicalUnit: '%',
    low: 20,
    high: 50,
    optimalLow: 25,
    optimalHigh: 40,
  ),
  BiomarkerCode.hsCrp: ReferenceDefinition(
    displayName: 'hs-CRP',
    category: BiomarkerCategory.inflammation,
    canonicalUnit: 'mg/L',
    high: 3,
    optimalHigh: 1,
    unitConversions: {'mg/dL': 10},
  ),
  BiomarkerCode.esr: ReferenceDefinition(
    displayName: 'ESR',
    category: BiomarkerCategory.inflammation,
    canonicalUnit: 'mm/hr',
    high: 20,
    optimalHigh: 10,
  ),
  BiomarkerCode.hba1c: ReferenceDefinition(
    displayName: 'HbA1c',
    category: BiomarkerCategory.glycemic,
    canonicalUnit: '%',
    low: 4,
    high: 5.7,
    optimalLow: 4.6,
    optimalHigh: 5.4,
    unitConversions: {'mmol/mol': 0.0915},
  ),
  BiomarkerCode.fastingGlucose: ReferenceDefinition(
    displayName: 'Fasting Glucose',
    category: BiomarkerCategory.glycemic,
    canonicalUnit: 'mg/dL',
    low: 70,
    high: 99,
    optimalLow: 75,
    optimalHigh: 89,
    unitConversions: {'mmol/L': 18.0182},
  ),
  BiomarkerCode.fastingInsulin: ReferenceDefinition(
    displayName: 'Fasting Insulin',
    category: BiomarkerCategory.glycemic,
    canonicalUnit: 'µIU/mL',
    low: 2,
    high: 19.6,
    optimalLow: 2,
    optimalHigh: 6,
    unitConversions: {'uIU/mL': 1, 'mIU/L': 1, 'pmol/L': 0.1443},
  ),
  BiomarkerCode.totalCholesterol: ReferenceDefinition(
    displayName: 'Total Cholesterol',
    category: BiomarkerCategory.lipids,
    canonicalUnit: 'mg/dL',
    high: 200,
    optimalLow: 140,
    optimalHigh: 180,
    unitConversions: {'mmol/L': 38.67},
  ),
  BiomarkerCode.ldl: ReferenceDefinition(
    displayName: 'LDL Cholesterol',
    category: BiomarkerCategory.lipids,
    canonicalUnit: 'mg/dL',
    high: 100,
    optimalHigh: 80,
    unitConversions: {'mmol/L': 38.67},
  ),
  BiomarkerCode.hdl: ReferenceDefinition(
    displayName: 'HDL Cholesterol',
    category: BiomarkerCategory.lipids,
    canonicalUnit: 'mg/dL',
    low: 40,
    optimalLow: 55,
    female: ReferenceOverride(low: 50, optimalLow: 65),
    unitConversions: {'mmol/L': 38.67},
  ),
  BiomarkerCode.triglycerides: ReferenceDefinition(
    displayName: 'Triglycerides',
    category: BiomarkerCategory.lipids,
    canonicalUnit: 'mg/dL',
    high: 150,
    optimalHigh: 90,
    unitConversions: {'mmol/L': 88.57},
  ),
  BiomarkerCode.apoB: ReferenceDefinition(
    displayName: 'Apolipoprotein B',
    category: BiomarkerCategory.lipids,
    canonicalUnit: 'mg/dL',
    high: 100,
    optimalHigh: 80,
  ),
  BiomarkerCode.tsh: ReferenceDefinition(
    displayName: 'TSH',
    category: BiomarkerCategory.thyroid,
    canonicalUnit: 'mIU/L',
    low: 0.45,
    high: 4.5,
    optimalLow: 0.8,
    optimalHigh: 2.5,
    unitConversions: {'µIU/mL': 1, 'uIU/mL': 1},
  ),
  BiomarkerCode.freeT3: ReferenceDefinition(
    displayName: 'Free T3',
    category: BiomarkerCategory.thyroid,
    canonicalUnit: 'pg/mL',
    low: 2.3,
    high: 4.2,
    optimalLow: 3,
    optimalHigh: 4,
  ),
  BiomarkerCode.freeT4: ReferenceDefinition(
    displayName: 'Free T4',
    category: BiomarkerCategory.thyroid,
    canonicalUnit: 'ng/dL',
    low: 0.8,
    high: 1.8,
    optimalLow: 1.1,
    optimalHigh: 1.6,
  ),
  BiomarkerCode.vitaminD: ReferenceDefinition(
    displayName: 'Vitamin D (25-OH)',
    category: BiomarkerCategory.micronutrient,
    canonicalUnit: 'ng/mL',
    low: 30,
    high: 100,
    optimalLow: 40,
    optimalHigh: 60,
    unitConversions: {'nmol/L': 0.4006},
  ),
  BiomarkerCode.vitaminB12: ReferenceDefinition(
    displayName: 'Vitamin B12',
    category: BiomarkerCategory.micronutrient,
    canonicalUnit: 'pg/mL',
    low: 200,
    high: 900,
    optimalLow: 500,
    optimalHigh: 800,
    unitConversions: {'pmol/L': 1.355},
  ),
  BiomarkerCode.folate: ReferenceDefinition(
    displayName: 'Folate',
    category: BiomarkerCategory.micronutrient,
    canonicalUnit: 'ng/mL',
    low: 3,
    high: 20,
    optimalLow: 10,
    optimalHigh: 20,
  ),
  BiomarkerCode.magnesium: ReferenceDefinition(
    displayName: 'Magnesium (RBC)',
    category: BiomarkerCategory.micronutrient,
    canonicalUnit: 'mg/dL',
    low: 4.2,
    high: 6.8,
    optimalLow: 5.4,
    optimalHigh: 6.8,
  ),
  BiomarkerCode.alt: ReferenceDefinition(
    displayName: 'ALT',
    category: BiomarkerCategory.organ,
    canonicalUnit: 'U/L',
    high: 40,
    optimalHigh: 25,
    female: ReferenceOverride(high: 33, optimalHigh: 20),
  ),
  BiomarkerCode.ast: ReferenceDefinition(
    displayName: 'AST',
    category: BiomarkerCategory.organ,
    canonicalUnit: 'U/L',
    high: 40,
    optimalHigh: 26,
  ),
  BiomarkerCode.ggt: ReferenceDefinition(
    displayName: 'GGT',
    category: BiomarkerCategory.organ,
    canonicalUnit: 'U/L',
    high: 55,
    optimalHigh: 25,
  ),
  BiomarkerCode.creatinine: ReferenceDefinition(
    displayName: 'Creatinine',
    category: BiomarkerCategory.organ,
    canonicalUnit: 'mg/dL',
    low: 0.7,
    high: 1.3,
    optimalLow: 0.8,
    optimalHigh: 1.1,
    female: ReferenceOverride(low: 0.6, high: 1.1),
    unitConversions: {'µmol/L': 0.0113, 'umol/L': 0.0113},
  ),
  BiomarkerCode.egfr: ReferenceDefinition(
    displayName: 'eGFR',
    category: BiomarkerCategory.organ,
    canonicalUnit: 'mL/min/1.73m²',
    low: 60,
    optimalLow: 90,
  ),
  BiomarkerCode.uricAcid: ReferenceDefinition(
    displayName: 'Uric Acid',
    category: BiomarkerCategory.organ,
    canonicalUnit: 'mg/dL',
    low: 3.5,
    high: 7.2,
    optimalLow: 3.5,
    optimalHigh: 5.5,
    female: ReferenceOverride(high: 6),
  ),
  BiomarkerCode.testosterone: ReferenceDefinition(
    displayName: 'Total Testosterone',
    category: BiomarkerCategory.endocrine,
    canonicalUnit: 'ng/dL',
    low: 300,
    high: 1000,
    optimalLow: 500,
    optimalHigh: 900,
    female: ReferenceOverride(
      low: 15,
      high: 70,
      optimalLow: 25,
      optimalHigh: 60,
    ),
    unitConversions: {'nmol/L': 28.84},
  ),
  BiomarkerCode.cortisolAm: ReferenceDefinition(
    displayName: 'Cortisol (AM)',
    category: BiomarkerCategory.endocrine,
    canonicalUnit: 'µg/dL',
    low: 6,
    high: 18.4,
    optimalLow: 10,
    optimalHigh: 15,
    unitConversions: {'nmol/L': 0.03625},
  ),
  BiomarkerCode.wbc: ReferenceDefinition(
    displayName: 'White Blood Cells',
    category: BiomarkerCategory.hematology,
    canonicalUnit: '10³/µL',
    low: 4,
    high: 11,
    optimalLow: 4.5,
    optimalHigh: 8,
  ),
  BiomarkerCode.plateletCount: ReferenceDefinition(
    displayName: 'Platelets',
    category: BiomarkerCategory.hematology,
    canonicalUnit: '10³/µL',
    low: 150,
    high: 400,
    optimalLow: 200,
    optimalHigh: 350,
  ),
};

ReferenceRange resolveRange(BiomarkerCode code, Gender gender) {
  final base = referenceTable[code]!;
  final override = gender == Gender.female ? base.female : null;

  return ReferenceRange(
    low: override?.low ?? base.low,
    high: override?.high ?? base.high,
    optimalLow: override?.optimalLow ?? base.optimalLow,
    optimalHigh: override?.optimalHigh ?? base.optimalHigh,
    source: ReferenceSource.app,
  );
}

/// Converts a printed value into the app's canonical unit for a biomarker.
///
/// Returns null when the unit is unrecognised — silently assuming the units
/// match would turn a 5.4 mmol/L glucose into a hypoglycaemia alert.
({double value, String unit})? toCanonicalUnit(
  BiomarkerCode code,
  double value,
  String unit,
) {
  final definition = referenceTable[code]!;
  final normalised = unit.trim();

  if (normalised.toLowerCase() == definition.canonicalUnit.toLowerCase()) {
    return (value: value, unit: definition.canonicalUnit);
  }

  final exact = definition.unitConversions[normalised];
  if (exact != null) {
    return (value: value * exact, unit: definition.canonicalUnit);
  }

  for (final entry in definition.unitConversions.entries) {
    if (entry.key.toLowerCase() == normalised.toLowerCase()) {
      return (value: value * entry.value, unit: definition.canonicalUnit);
    }
  }

  return null;
}

/// How far outside the conventional interval counts as `critical`.
const double _criticalMultiplier = 1.5;

BiomarkerFlag classifyValue(double value, ReferenceRange range) {
  final low = range.low;
  final high = range.high;

  if (low != null && value < low) {
    return value < low / _criticalMultiplier
        ? BiomarkerFlag.criticalLow
        : BiomarkerFlag.low;
  }
  if (high != null && value > high) {
    return value > high * _criticalMultiplier
        ? BiomarkerFlag.criticalHigh
        : BiomarkerFlag.high;
  }

  // Inside the lab range — is it inside the tighter optimal band?
  final optimalLow = range.optimalLow;
  final optimalHigh = range.optimalHigh;
  if (optimalLow != null && value < optimalLow) {
    return BiomarkerFlag.borderlineLow;
  }
  if (optimalHigh != null && value > optimalHigh) {
    return BiomarkerFlag.borderlineHigh;
  }
  if (optimalLow != null || optimalHigh != null) return BiomarkerFlag.optimal;

  return BiomarkerFlag.normal;
}

/// Re-flags a parsed biomarker against the app's reference table.
///
/// Prefers the lab's own printed interval where it exists — labs calibrate
/// per-assay — but always layers our optimal band on top of it.
Biomarker enrichBiomarker(Biomarker biomarker, Gender gender) {
  final code = biomarker.code;
  if (code == null) return biomarker.copyWith(flag: BiomarkerFlag.unknown);

  final appRange = resolveRange(code, gender);
  final converted = toCanonicalUnit(code, biomarker.value, biomarker.unit);

  if (converted == null) {
    // Unknown unit: keep the value verbatim and trust only the lab's own range.
    final labRange = biomarker.range;
    final usable = labRange.low != null || labRange.high != null;
    return biomarker.copyWith(
      flag: usable
          ? classifyValue(biomarker.value, labRange)
          : BiomarkerFlag.unknown,
      confidence: biomarker.confidence < 0.6 ? biomarker.confidence : 0.6,
    );
  }

  final hasLabInterval =
      biomarker.range.low != null || biomarker.range.high != null;

  final range = ReferenceRange(
    low: biomarker.range.low ?? appRange.low,
    high: biomarker.range.high ?? appRange.high,
    optimalLow: appRange.optimalLow,
    optimalHigh: appRange.optimalHigh,
    // Provenance must survive re-enrichment. Deriving it purely from "does the
    // range have numbers in it" would relabel an app-supplied interval as the
    // lab's own on the second pass — and this runs again on every render.
    source: biomarker.range.source == ReferenceSource.app
        ? ReferenceSource.app
        : (hasLabInterval ? ReferenceSource.lab : ReferenceSource.app),
  );

  final definition = referenceTable[code]!;

  return biomarker.copyWith(
    value: (converted.value * 1000).round() / 1000,
    unit: converted.unit,
    category: definition.category,
    displayName: definition.displayName,
    range: range,
    flag: classifyValue(converted.value, range),
  );
}
