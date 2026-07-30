import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/iso_day.dart';
import '../../../core/widgets/charts/cycle_ring.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/gender.dart';
import '../../../features/cycle/menstrual_phase.dart';
import '../../providers/cycle_phase_provider.dart';
import '../../providers/cycle_view_provider.dart';
import '../../providers/repository_providers.dart';
import 'main_shell.dart';

/// Cycle tracker, built on the ported `computeMenstrualPhase` model.
///
/// Everything on screen derives from one phase object, so the ring, the
/// countdowns and the copy cannot disagree. Notably the model *declines* to
/// answer in several situations — no logs, a stale log, hormonal contraception —
/// and this screen surfaces that instead of papering over it with a number.
class CycleWellnessScreen extends ConsumerStatefulWidget {
  const CycleWellnessScreen({super.key});

  @override
  ConsumerState<CycleWellnessScreen> createState() =>
      _CycleWellnessScreenState();
}

class _CycleWellnessScreenState extends ConsumerState<CycleWellnessScreen> {
  /// Null follows today; set by tapping a day on the ring.
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final cycleView = ref.watch(cycleViewProvider);
    final isFemaleView = cycleView == Gender.female;
    final phase = ref.watch(menstrualPhaseProvider);
    final profile = ref.watch(effectiveCycleProfileProvider);
    final regularity = ref.watch(cycleRegularityProvider);

    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.space1,
        bottom: MainShell.bottomInsetFor(context),
      ),
      children: [
        _Header(
          title: isFemaleView ? 'Your cycle' : 'Wellness',
          date: DateFormat('EEEE, MMMM d').format(DateTime.now()),
          view: cycleView,
          onView: (g) => g == Gender.female
              ? ref.read(cycleViewProvider.notifier).setFemale()
              : ref.read(cycleViewProvider.notifier).setMale(),
        ),

        if (!isFemaleView)
          const _Gutter(delay: 40, child: _WellnessView())
        else if (phase == null)
          const _Gutter(delay: 40, child: _NoCycleData())
        else ...[
          _Gutter(
            delay: 40,
            child: Center(
              child: CycleRing(
                phase: phase,
                periodDays: profile.averagePeriodDays,
                selectedDay: _selectedDay,
                onSelectDay: (day) => setState(() => _selectedDay = day),
              ),
            ),
          ),

          // A legend is always present: four phases means identity can never
          // rest on colour alone.
          const _Gutter(delay: 60, child: _PhaseLegend()),

          if (_selectedDay != null && _selectedDay != phase.dayOfCycle)
            _Gutter(
              child: _SelectedDayNote(
                day: _selectedDay!,
                phase: phase,
                periodDays: profile.averagePeriodDays,
                onClear: () => setState(() => _selectedDay = null),
              ),
            ),

          _Gutter(delay: 80, child: _Countdowns(phase: phase)),
          _Gutter(delay: 100, child: _PhaseCard(phase: phase)),
          _Gutter(
            delay: 120,
            child: _CycleStats(
              cycleDays: phase.cycleLengthDays,
              isMeasured: phase.isMeasuredLength,
              periodDays: profile.averagePeriodDays,
              regularity: regularity,
            ),
          ),
          _Gutter(delay: 140, child: _GuidanceCard(phase: phase)),
        ],

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space8,
            AppSpacing.space6,
            AppSpacing.space8,
            0,
          ),
          child: Text(
            'Phase is calculated from the periods you log — not measured from '
            'your wearable, and not a contraceptive method.',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardMeta.copyWith(fontSize: 10, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _Gutter extends StatelessWidget {
  const _Gutter({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space5,
        AppSpacing.space5,
        0,
      ),
      child: FadeIn(delay: Duration(milliseconds: delay), child: child),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.date,
    required this.view,
    required this.onView,
  });

  final String title;
  final String date;
  final Gender view;
  final ValueChanged<Gender> onView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenBackButton(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(title, style: AppTextStyles.h3.copyWith(fontSize: 25)),
              ],
            ),
          ),
          // Demo affordance, not a product control — the RN build ships the
          // same switch so the non-cycle view is reviewable on one device.
          _ViewToggle(view: view, onView: onView),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onView});

  final Gender view;
  final ValueChanged<Gender> onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final option in Gender.values)
            Material(
              color: option == view ? AppColors.brand : Colors.transparent,
              child: InkWell(
                onTap: () => onView(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    option == Gender.female ? 'Cycle' : 'General',
                    style: AppTextStyles.tag.copyWith(
                      fontSize: 11,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w700,
                      color: option == view
                          ? AppColors.onBrand
                          : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhaseLegend extends StatelessWidget {
  const _PhaseLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space4,
      runSpacing: AppSpacing.space2,
      alignment: WrapAlignment.center,
      children: [
        for (final name in MenstrualPhaseName.values)
          _LegendKey(
            label: cyclePhaseShortLabel[name]!,
            colour: cyclePhaseColor[name]!,
          ),
        // Ovulation rides a shape rather than a hue, so it needs its own key.
        const _LegendKey(label: 'Ovulation', colour: null),
      ],
    );
  }
}

class _LegendKey extends StatelessWidget {
  const _LegendKey({required this.label, required this.colour});

  /// Null draws the hollow ovulation marker instead of a filled dot.
  final Color? colour;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            border: colour == null
                ? Border.all(color: AppColors.brand700, width: 1.5)
                : null,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.cardMeta.copyWith(
            fontSize: 11,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _SelectedDayNote extends StatelessWidget {
  const _SelectedDayNote({
    required this.day,
    required this.phase,
    required this.periodDays,
    required this.onClear,
  });

  final int day;
  final MenstrualPhase phase;
  final int periodDays;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final name = phaseForCycleDay(
      day: day,
      ovulationDay: phase.ovulationDay,
      periodDays: periodDays,
    );
    final offset = day - phase.dayOfCycle;
    final magnitude = offset.abs();
    final plural = magnitude == 1 ? 'day' : 'days';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.brand50,
        border: Border.all(color: AppColors.brand200),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        spacing: AppSpacing.space2,
        children: [
          Expanded(
            child: Text(
              'Day $day · ${cyclePhaseShortLabel[name]} — '
              '${offset > 0 ? 'in $magnitude $plural' : '$magnitude $plural ago'}',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.brand800,
              ),
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                'Back to today',
                style: AppTextStyles.tag.copyWith(
                  fontSize: 11,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two dates people actually open a cycle app for.
class _Countdowns extends StatelessWidget {
  const _Countdowns({required this.phase});

  final MenstrualPhase phase;

  static String _relative(int days) {
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    if (days > 0) return 'in $days days';
    final ago = days.abs();
    return '$ago ${ago == 1 ? 'day' : 'days'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final nextPeriod = addDays(today, phase.daysUntilNextPeriod);
    final ovulation = addDays(today, phase.daysUntilOvulation);

    return Row(
      spacing: AppSpacing.space3,
      children: [
        Expanded(
          child: _CountdownTile(
            icon: Icons.brightness_low_outlined,
            label: 'Ovulation',
            headline: _relative(phase.daysUntilOvulation),
            detail:
                'Day ${phase.ovulationDay} · '
                '${DateFormat('MMM d').format(ovulation)}',
          ),
        ),
        Expanded(
          child: _CountdownTile(
            icon: Icons.water_drop_outlined,
            label: 'Next period',
            headline: _relative(phase.daysUntilNextPeriod),
            detail: DateFormat('MMMM d').format(nextPeriod),
          ),
        ),
      ],
    );
  }
}

class _CountdownTile extends StatelessWidget {
  const _CountdownTile({
    required this.icon,
    required this.label,
    required this.headline,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String headline;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(icon, size: 15, color: AppColors.brand),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardBody.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(headline, style: AppTextStyles.cardTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 2),
          Text(detail, style: AppTextStyles.cardMeta.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.phase});

  final MenstrualPhase phase;

  static String _confidenceCopy(PhaseConfidence confidence) =>
      switch (confidence) {
        PhaseConfidence.high => 'Based on your own logged cycle length',
        PhaseConfidence.moderate => 'Estimated — log another period to sharpen',
        PhaseConfidence.low => 'Low confidence — treat this as a rough guide',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.brand50,
        border: Border.all(color: AppColors.brand200),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 6,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: cyclePhaseColor[phase.name],
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                phase.label.toUpperCase(),
                style: AppTextStyles.tag.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.brand700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(phase.summary, style: AppTextStyles.h5.copyWith(height: 1.35)),
          const SizedBox(height: AppSpacing.space2),
          Row(
            spacing: 4,
            children: [
              const Icon(Icons.info_outline, size: 11, color: AppColors.faint),
              Expanded(
                child: Text(
                  _confidenceCopy(phase.confidence),
                  style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CycleStats extends StatelessWidget {
  const _CycleStats({
    required this.cycleDays,
    required this.isMeasured,
    required this.periodDays,
    required this.regularity,
  });

  final int cycleDays;
  final bool isMeasured;
  final int periodDays;
  final int? regularity;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.space2,
      children: [
        Expanded(
          child: _StatBox(
            value: '$cycleDays',
            label: isMeasured ? 'Your avg. cycle' : 'Assumed cycle',
          ),
        ),
        Expanded(child: _StatBox(value: '$periodDays', label: 'Period days')),
        Expanded(
          child: _StatBox(
            // An invented regularity score is worse than an honest dash.
            value: regularity == null ? '—' : '$regularity%',
            label: 'Regularity',
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.metricSmall.copyWith(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppTextStyles.cardMeta.copyWith(fontSize: 10, height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// Training and nutrition for the current phase.
///
/// This is the half of a cycle tracker that earns its place: a day number is
/// trivia, whereas "iron demand peaks now, and a lower HRV this week is normal"
/// changes what someone does today.
class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({required this.phase});

  final MenstrualPhase phase;

  @override
  Widget build(BuildContext context) {
    final guidance = phaseGuidance[phase.name]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'What this phase means'),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GuidanceRow(
                icon: Icons.fitness_center,
                title: switch (guidance.trainingBias) {
                  TrainingBias.push => 'Push',
                  TrainingBias.maintain => 'Hold steady',
                  TrainingBias.ease => 'Ease off',
                },
                body: guidance.training,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.space3),
                child: Divider(height: 1, color: AppColors.hairline),
              ),
              _GuidanceRow(
                icon: Icons.restaurant_outlined,
                title: 'Eat for it',
                body: guidance.nutrition,
              ),
              if (guidance.expectedTelemetryNote != null) ...[
                const SizedBox(height: AppSpacing.space3),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  decoration: BoxDecoration(
                    color: AppColors.brand50,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    spacing: AppSpacing.space2,
                    children: [
                      const Icon(
                        Icons.monitor_heart_outlined,
                        size: 14,
                        color: AppColors.brand,
                      ),
                      Expanded(
                        child: Text(
                          guidance.expectedTelemetryNote!,
                          style: AppTextStyles.cardBody.copyWith(
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GuidanceRow extends StatelessWidget {
  const _GuidanceRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.space3,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brand50,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 16, color: AppColors.brand),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: AppTextStyles.cardBody.copyWith(
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown when the model declines to name a phase.
class _NoCycleData extends StatelessWidget {
  const _NoCycleData();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            size: 22,
            color: AppColors.brand,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text('No cycle to show yet', style: AppTextStyles.h5),
          const SizedBox(height: 6),
          Text(
            'Log the first day of a period and this fills in. After two logged '
            'periods the cycle length becomes measured rather than assumed.',
            style: AppTextStyles.cardBody.copyWith(fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// The non-cycle view: the same wellness read without phase maths.
class _WellnessView extends ConsumerWidget {
  const _WellnessView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(cycleRepositoryProvider);
    final score = repo.wellnessScore();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space8,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            children: [
              Text(
                'Wellness score',
                style: AppTextStyles.cardBody.copyWith(fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.space2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$score',
                    style: AppTextStyles.metricLarge.copyWith(fontSize: 56),
                  ),
                  Text(
                    ' / 100',
                    style: AppTextStyles.cardBody.copyWith(fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              // A meter, not a chart: one ratio against a fixed limit, with the
              // track a lighter step of the fill's own hue.
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: SizedBox(
                  height: 6,
                  child: ColoredBox(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (score / 100).clamp(0.0, 1.0),
                      child: const ColoredBox(color: AppColors.brand),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: AppColors.brand50,
            border: Border.all(color: AppColors.brand200),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INSIGHT',
                style: AppTextStyles.tag.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.brand700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                repo.wellnessInsight(),
                style: AppTextStyles.h5.copyWith(height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
