import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../../../domain/entities/labs/lab_report.dart';
import '../../../domain/entities/nutrition/meal_entry.dart';
import '../../../domain/entities/nutrition/nutrition_targets.dart';
import '../../../domain/entities/profile/diet_pattern.dart';
import '../../providers/health_providers.dart';
import '../../providers/labs_providers.dart';
import '../../providers/notification_time_provider.dart';
import '../../providers/nutrition_providers.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/labs/biomarker_table.dart';
import '../../widgets/labs/upload_report_actions.dart';

/// Profile and settings.
///
/// The two fake sections are gone: a "Connected devices" table listing four
/// vendors with hardcoded pills, and a blood-test history from a stub repository.
/// In their place, the one thing that is actually true about telemetry on this
/// device, and the reports the user has actually uploaded.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final labs = ref.watch(labsProvider);
    final timeLabel = ref.watch(briefTimeLabelProvider);
    final targets = ref.watch(nutritionTargetsProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: AppSpacing.space3,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent900,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  profile.initial,
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.accent2_400,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.greetingName, style: AppTextStyles.h4),
                    Text(
                      '${profile.age.isNotEmpty ? '${profile.age} · ' : ''}'
                      '${profile.goal.label}',
                      style: AppTextStyles.muted.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.space6),
          const _BodyComposition(),

          const SizedBox(height: AppSpacing.space6),
          const _ActivityAndDiet(),

          const SizedBox(height: AppSpacing.space6),
          const SectionHeader(title: 'Health data'),
          const _TelemetrySourceRow(),

          const SizedBox(height: AppSpacing.space6),
          SectionHeader(
            title: 'Blood test history',
            count: labs.reports.isEmpty ? null : labs.reports.length,
          ),
          if (labs.reports.isEmpty)
            const UploadReportActions()
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.space2,
              children: [
                for (final report in labs.reports)
                  _ReportRow(report: report),
                const SizedBox(height: AppSpacing.space2),
                const UploadReportActions(),
              ],
            ),

          const SizedBox(height: AppSpacing.space6),
          const SectionHeader(title: 'Notifications'),
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 2),
                bottom: BorderSide(color: AppColors.divider, width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Morning brief time',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        // The brief is composed on device, so this only ever
                        // drives a local notification — say so rather than
                        // implying a scheduled server job.
                        'When to nudge you to read it',
                        style: AppTextStyles.cardMeta,
                      ),
                    ],
                  ),
                ),
                Row(
                  spacing: AppSpacing.space2,
                  children: [
                    AppButton.icon(
                      leading: const Icon(Icons.remove, size: 16),
                      onPressed: () => ref
                          .read(notificationTimeIndexProvider.notifier)
                          .decrement(),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        timeLabel,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h6.copyWith(
                          letterSpacing: 0,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    AppButton.icon(
                      leading: const Icon(Icons.add, size: 16),
                      onPressed: () => ref
                          .read(notificationTimeIndexProvider.notifier)
                          .increment(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (targets != null) ...[
            const SizedBox(height: AppSpacing.space6),
            const SectionHeader(title: "Today's arithmetic"),
            _TargetsBreakdown(),
          ],

          const SizedBox(height: AppSpacing.space6),
          const _DemoData(),
          const SizedBox(height: AppSpacing.space4),
        ],
      ),
    );
  }
}

/// Height, weight and age. Every calorie, protein and hydration figure in the
/// app derives from these, so the section says that outright — a user who
/// understands why the field matters is far likelier to fill it in.
class _BodyComposition extends ConsumerWidget {
  const _BodyComposition();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Body'),
        if (!profile.canComputeTargets)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space3),
            child: Text(
              'Your targets are currently estimated from population averages. '
              'Add your height and weight and every number in the app sharpens.',
              style: AppTextStyles.cardBody.copyWith(height: 1.45),
            ),
          ),
        Row(
          spacing: AppSpacing.space3,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Height (cm)',
                value: profile.heightCm?.round().toString() ?? '',
                placeholder: '172',
                keyboardType: TextInputType.number,
                onChanged: (value) => notifier.setBodyComposition(
                  heightCm: double.tryParse(value),
                  weightKg: profile.weightKg,
                ),
              ),
            ),
            Expanded(
              child: AppTextField(
                label: 'Weight (kg)',
                value: profile.weightKg?.round().toString() ?? '',
                placeholder: '68',
                keyboardType: TextInputType.number,
                onChanged: (value) => notifier.setBodyComposition(
                  heightCm: profile.heightCm,
                  weightKg: double.tryParse(value),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivityAndDiet extends ConsumerWidget {
  const _ActivityAndDiet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);
    final targets = ref.watch(nutritionTargetsProvider);
    final measured = targets?.energyBasis == EnergyBasis.measured;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Activity'),
        if (measured)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space3),
            child: Text(
              'Your watch is reporting enough active energy that this setting is '
              'no longer used — measured burn beats an activity multiplier every '
              'time.',
              style: AppTextStyles.cardBody.copyWith(height: 1.45),
            ),
          ),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: [
            for (final level in ActivityLevel.values)
              SelectableChip(
                label: level.label,
                selected: profile.activityLevel == level,
                onTap: () => notifier.setActivityLevel(level),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.space5),
        const SectionHeader(title: 'Diet'),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: [
            for (final pattern in DietPattern.values)
              SelectableChip(
                label: pattern.label,
                selected: profile.effectiveDietPattern == pattern,
                onTap: () => notifier.setDietPattern(pattern),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.space5),
        const SectionHeader(title: 'Preferences'),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: [
            for (final restriction in Restriction.values)
              SelectableChip(
                label: restriction.label,
                selected: profile.restrictions.contains(restriction),
                onTap: () => notifier.toggleRestriction(restriction),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.space5),
        const SectionHeader(title: 'Conditions'),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space3),
          child: Text(
            'Used to tighten your carbohydrate and sugar targets. Not a '
            'diagnosis, and nothing here is shared.',
            style: AppTextStyles.cardBody.copyWith(height: 1.45),
          ),
        ),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: [
            for (final condition in Condition.values)
              SelectableChip(
                label: condition.label,
                selected: profile.conditions.contains(condition),
                onTap: () => notifier.toggleCondition(condition),
              ),
          ],
        ),
      ],
    );
  }
}

class _TelemetrySourceRow extends ConsumerWidget {
  const _TelemetrySourceRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(telemetrySourceProvider);
    final days = ref.watch(healthSeriesProvider).valueOrNull?.length ?? 0;
    final synthetic = source == TelemetrySource.synthetic;

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
            children: [
              Expanded(
                child: Text(
                  synthetic ? 'Sample telemetry' : 'Apple Health',
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
              ),
              AppTag(
                label: synthetic ? 'Sample data' : 'Connected',
                variant: synthetic
                    ? AppTagVariant.neutral
                    : AppTagVariant.accent,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            synthetic
                ? '$days days of a deterministic sample series. Readiness, '
                      'targets and the brief are computed from it for real — but '
                      'it is not your data.'
                : '$days days read from your health store. Read-only; nothing is '
                      'written back.',
            style: AppTextStyles.cardBody.copyWith(height: 1.45),
          ),
          if (synthetic) ...[
            const SizedBox(height: AppSpacing.space3),
            AppButton(
              label: 'Connect Apple Health',
              variant: AppButtonVariant.secondary,
              block: true,
              onPressed: () => requestHealthAccess(ref),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportRow extends ConsumerWidget {
  const _ReportRow({required this.report});

  final LabReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = report.collectedAt ?? report.uploadedAt;
    final flagged = report.flagged.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.space4,
          0,
          AppSpacing.space4,
          AppSpacing.space4,
        ),
        title: Text(
          report.panelName ?? 'Blood panel',
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${DateFormat('d MMM yyyy').format(date)} · '
          '${report.biomarkers.length} markers'
          '${flagged == 0 ? '' : ' · $flagged to watch'}',
          style: AppTextStyles.cardMeta,
        ),
        children: [
          for (final warning in report.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: Text(
                warning,
                style: AppTextStyles.cardMeta.copyWith(height: 1.45),
              ),
            ),
          BiomarkerTable(report: report),
          const SizedBox(height: AppSpacing.space3),
          AppButton(
            label: 'Delete this report',
            variant: AppButtonVariant.danger,
            block: true,
            onPressed: () => ref.read(labsProvider.notifier).remove(report.id),
          ),
        ],
      ),
    );
  }
}

/// Shows the arithmetic behind today's targets.
///
/// Not a debug panel — it is the answer to "why does it think I should eat
/// 2,180 calories", which is the first question anyone asks of a number like
/// that, and the reason most calorie apps get closed.
class _TargetsBreakdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(nutritionTargetsProvider);
    if (targets == null) return const SizedBox.shrink();

    final rows = <(String, String)>[
      (
        'Maintenance',
        '${targets.maintenanceCalories} kcal · '
            '${targets.energyBasis == EnergyBasis.measured ? 'measured' : 'estimated'}',
      ),
      ('Today’s target', '${targets.calories} kcal'),
      ('Protein', '${targets.macros.proteinG} g'),
      ('Carbs', '${targets.macros.carbsG} g'),
      ('Fat', '${targets.macros.fatG} g'),
      ('Fibre', '${targets.macros.fibreG} g'),
      ('Added sugar ceiling', '${targets.addedSugarCeilingG} g'),
      ('Water', '${(targets.waterMl / 1000).toStringAsFixed(1)} L'),
      ('Steps', '${targets.stepTarget}'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final row in rows)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
                vertical: AppSpacing.space2 + 2,
              ),
              decoration: BoxDecoration(
                border: row == rows.last
                    ? null
                    : const Border(
                        bottom: BorderSide(
                          color: AppColors.hairline,
                          width: 1,
                        ),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(row.$1, style: AppTextStyles.bodySmall),
                  ),
                  Text(
                    row.$2,
                    style: AppTextStyles.h6.copyWith(
                      fontSize: 13,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DemoData extends ConsumerWidget {
  const _DemoData();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(mealLogProvider);
    final seeded = log.meals.any((m) => m.source == MealSource.seed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space2,
      children: [
        const SectionHeader(title: 'Demo data'),
        Text(
          seeded
              ? 'Your food log contains a seeded week so the weekly pattern '
                    'analysis has something to find. Clearing it leaves only what '
                    'you log yourself.'
              : 'Your food log contains only your own entries.',
          style: AppTextStyles.cardBody.copyWith(height: 1.45),
        ),
        const SizedBox(height: AppSpacing.space1),
        AppButton(
          label: seeded ? 'Clear the seeded week' : 'Load the demo week',
          variant: AppButtonVariant.secondary,
          block: true,
          onPressed: () => seeded
              ? ref.read(mealLogProvider.notifier).clear()
              : ref.read(mealLogProvider.notifier).reseed(),
        ),
      ],
    );
  }
}
