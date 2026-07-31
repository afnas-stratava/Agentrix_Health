import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/choice.dart';
import '../../../features/correlation/engine_context.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/settings_providers.dart';
import 'onboarding_scaffold.dart';

/// Mirrors `app/onboarding/profile.tsx`.
///
/// Asks only what the reference intervals need, and says exactly that. "Prefer
/// not to say" is a real option with a stated consequence rather than a polite
/// dead end — it widens the interval, which is the honest trade.
class SexScreen extends ConsumerStatefulWidget {
  const SexScreen({super.key});

  @override
  ConsumerState<SexScreen> createState() => _SexScreenState();
}

class _SexScreenState extends ConsumerState<SexScreen> {
  BiologicalSex? _selected;

  static const _options = [
    (
      BiologicalSex.female,
      'Female',
      'Applies female intervals for ferritin, haemoglobin, HDL, testosterone '
          'and ALT',
    ),
    (
      BiologicalSex.male,
      'Male',
      'Applies male intervals for ferritin, haemoglobin, HDL, testosterone and '
          'ALT',
    ),
    (
      BiologicalSex.unspecified,
      'Prefer not to say',
      'Uses the wider combined interval — some values may be flagged less '
          'precisely',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final BiologicalSex selected =
        _selected ?? ref.watch(biologicalSexProvider);

    return OnboardingScaffold(
      title: 'Which reference ranges should we use?',
      intro: 'Lab reference intervals differ by biological sex. This is only '
          'used to flag your results correctly — it is stored on your device '
          'and never sent anywhere.',
      onContinue: () {
        ref.read(settingsProvider.notifier).setSex(selected);
        ref.read(appStageProvider.notifier).next();
      },
      children: [
        for (final option in _options)
          ChoiceRow(
            label: option.$2,
            hint: option.$3,
            selected: selected == option.$1,
            onTap: () => setState(() => _selected = option.$1),
          ),
      ],
    );
  }
}
