import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentrix_health/domain/entities/labs/biomarker.dart';
import 'package:agentrix_health/presentation/widgets/labs/biomarker_range_row.dart';

Biomarker _marker({
  required String name,
  required double value,
  required String unit,
  double? low,
  double? high,
  double? optimalLow,
  double? optimalHigh,
  required BiomarkerFlag flag,
}) => Biomarker(
  code: null,
  rawName: name,
  displayName: name,
  value: value,
  unit: unit,
  range: ReferenceRange(
    low: low,
    high: high,
    optimalLow: optimalLow,
    optimalHigh: optimalHigh,
  ),
  flag: flag,
);

void main() {
  testWidgets('flagged rows render without overflow', (tester) async {
    final rows = [
      _marker(
        name: 'Transferrin Saturation',
        value: 18,
        unit: '%',
        low: 20,
        high: 50,
        optimalLow: 30,
        optimalHigh: 40,
        flag: BiomarkerFlag.low,
      ),
      _marker(
        name: 'hs-CRP',
        value: 3.4,
        unit: 'mg/L',
        high: 3,
        optimalHigh: 1,
        flag: BiomarkerFlag.high,
      ),
      _marker(
        name: 'Ferritin',
        value: 21,
        unit: 'ng/mL',
        low: 15,
        high: 300,
        optimalLow: 50,
        optimalHigh: 150,
        flag: BiomarkerFlag.borderlineLow,
      ),
      // No interval at all — the bar has to be dropped, not divided by zero.
      _marker(
        name: 'Some Very Long Analyte Name Indeed',
        value: 1.25,
        unit: 'mmol/L',
        flag: BiomarkerFlag.unknown,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: Column(
              children: [
                for (final row in rows)
                  BiomarkerRangeRow(biomarker: row, isLast: row == rows.last),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('20–50 %'), findsOneWidget);
    expect(find.text('< 3 mg/L'), findsOneWidget);
    expect(find.text('Below optimal'), findsOneWidget);
  });
}
