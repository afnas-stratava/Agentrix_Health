import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../domain/entities/cycle_day.dart';
import '../../../domain/entities/cycle_phase.dart';
import '../../../domain/entities/gender.dart';
import '../../../domain/repositories/cycle_repository.dart';
import '../../providers/cycle_view_provider.dart';
import '../../providers/repository_providers.dart';

const _todayDay = 14;
const _totalDays = 28;

Color _phaseColor(CyclePhaseType phase) => switch (phase) {
  CyclePhaseType.menstrual => AppColors.accent700,
  CyclePhaseType.follicular => AppColors.neutral800,
  CyclePhaseType.ovulatory => AppColors.accent500,
  CyclePhaseType.luteal => AppColors.neutral600,
};

class CycleWellnessScreen extends ConsumerWidget {
  const CycleWellnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycleView = ref.watch(cycleViewProvider);
    final cycleRepo = ref.watch(cycleRepositoryProvider);
    final isFemaleView = cycleView == Gender.female;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isFemaleView ? 'Cycle tracker' : 'Wellness',
                style: AppTextStyles.h3,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'DEMO VIEW',
                    style: AppTextStyles.cardMeta.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: AppColors.neutral600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SegmentedControl<Gender>(
                    selected: cycleView,
                    options: const [
                      SegmentedOption(value: Gender.female, label: 'F'),
                      SegmentedOption(value: Gender.male, label: 'M'),
                    ],
                    onChanged: (g) => g == Gender.female
                        ? ref.read(cycleViewProvider.notifier).setFemale()
                        : ref.read(cycleViewProvider.notifier).setMale(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          if (isFemaleView)
            _CycleCalendar(cycleRepo: cycleRepo)
          else
            _WellnessScore(cycleRepo: cycleRepo),
        ],
      ),
    );
  }
}

class _CycleCalendar extends StatelessWidget {
  const _CycleCalendar({required this.cycleRepo});

  final CycleRepository cycleRepo;

  @override
  Widget build(BuildContext context) {
    final days = cycleRepo.monthDays(totalDays: _totalDays, today: _todayDay);
    final currentPhase = CyclePhaseType.forDay(_todayDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          children: [
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.space1,
              crossAxisSpacing: AppSpacing.space1,
              childAspectRatio: 1,
              children: [for (final day in days) _CycleDayCell(day: day)],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space4),
        Wrap(
          spacing: AppSpacing.space4,
          runSpacing: AppSpacing.space2,
          children: [
            for (final phase in CyclePhaseType.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Container(width: 8, height: 8, color: _phaseColor(phase)),
                  Text(
                    phase.label,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.neutral700,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.space4),
        AppCard(
          backgroundColor: AppColors.accent100,
          children: [
            Text(
              'Day $_todayDay · ${currentPhase.label}',
              style: AppTextStyles.cardKicker.copyWith(
                color: AppColors.accent800,
              ),
            ),
            Text(
              cycleRepo.phaseInsight(),
              style: AppTextStyles.cardTitle.copyWith(
                color: AppColors.accent900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CycleDayCell extends StatelessWidget {
  const _CycleDayCell({required this.day});

  final CycleDay day;

  @override
  Widget build(BuildContext context) {
    final color = day.isToday ? _phaseColor(day.phase) : AppColors.neutral200;
    final textColor = day.isToday ? AppColors.bg : AppColors.text;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${day.dayNumber}',
        style: AppTextStyles.h6.copyWith(
          fontSize: 12,
          letterSpacing: 0,
          color: textColor,
        ),
      ),
    );
  }
}

class _WellnessScore extends StatelessWidget {
  const _WellnessScore({required this.cycleRepo});

  final CycleRepository cycleRepo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          crossAxisAlignment: CrossAxisAlignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space8,
          ),
          children: [
            Text('Wellness score', style: AppTextStyles.cardKicker),
            Text(
              '${cycleRepo.wellnessScore()}',
              style: AppTextStyles.h1.copyWith(fontSize: 56, height: 1),
            ),
            Text(
              'out of 100',
              style: AppTextStyles.muted.copyWith(fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space4),
        AppCard(
          backgroundColor: AppColors.accent100,
          children: [
            Text(
              'Insight',
              style: AppTextStyles.cardKicker.copyWith(
                color: AppColors.accent800,
              ),
            ),
            Text(
              cycleRepo.wellnessInsight(),
              style: AppTextStyles.cardTitle.copyWith(
                color: AppColors.accent900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
