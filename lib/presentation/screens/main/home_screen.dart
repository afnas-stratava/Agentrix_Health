import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/gender.dart';
import '../../providers/brief_provider.dart';
import '../../providers/cycle_view_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/meals_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/user_profile_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final stats = ref.watch(dailyStatsRepositoryProvider).current();
    final briefTeaser = ref.watch(briefLinesProvider).first.text;
    final todayCalories = ref.watch(todayCaloriesProvider);
    final cycleView = ref.watch(cycleViewProvider);
    final todayLabel = DateFormat('EEEE, MMMM d').format(DateTime.now());

    final cycleTeaserLabel = cycleView == Gender.female
        ? 'Cycle · Day 14'
        : 'Wellness score';
    final cycleTeaserText = cycleView == Gender.female
        ? 'Follicular phase — energy is high'
        : '82 / 100 — strong recovery';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(todayLabel, style: AppTextStyles.muted.copyWith(fontSize: 13)),
          const SizedBox(height: AppSpacing.space1),
          Text(
            'Good morning, ${profile.greetingName}',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: AppSpacing.space6),
          Row(
            spacing: AppSpacing.space2,
            children: [
              Expanded(
                child: AppCard(
                  children: [
                    Text('Steps', style: AppTextStyles.cardKicker),
                    Text(stats.stepsLabel, style: AppTextStyles.cardTitle),
                  ],
                ),
              ),
              Expanded(
                child: AppCard(
                  children: [
                    Text('Sleep', style: AppTextStyles.cardKicker),
                    Text(stats.sleepLabel, style: AppTextStyles.cardTitle),
                  ],
                ),
              ),
              Expanded(
                child: AppCard(
                  children: [
                    Text('Burned', style: AppTextStyles.cardKicker),
                    Text(stats.burnedLabel, style: AppTextStyles.cardTitle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          AppCard(
            backgroundColor: AppColors.accent900,
            onTap: () =>
                ref.read(mainTabProvider.notifier).select(MainTab.brief),
            children: [
              Text(
                'Today\'s plan',
                style: AppTextStyles.cardKicker.copyWith(
                  color: AppColors.accent2_400,
                ),
              ),
              Text(
                briefTeaser,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.neutral300,
                  fontSize: 13,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Text(
                    'View full brief',
                    style: AppTextStyles.cardMeta.copyWith(
                      color: AppColors.accent2_400,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    size: 12,
                    color: AppColors.accent2_400,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          AppCard(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            onTap: () => ref.read(mainTabProvider.notifier).select(MainTab.log),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's food log", style: AppTextStyles.cardKicker),
                  Text(
                    '$todayCalories kcal logged',
                    style: AppTextStyles.cardTitle,
                  ),
                ],
              ),
              const Icon(
                Icons.arrow_forward,
                size: 16,
                color: AppColors.accent700,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          AppCard(
            backgroundColor: AppColors.accent100,
            onTap: () =>
                ref.read(mainTabProvider.notifier).select(MainTab.cycle),
            children: [
              Text(
                cycleTeaserLabel,
                style: AppTextStyles.cardKicker.copyWith(
                  color: AppColors.accent800,
                ),
              ),
              Text(
                cycleTeaserText,
                style: AppTextStyles.cardTitle.copyWith(
                  color: AppColors.accent900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
