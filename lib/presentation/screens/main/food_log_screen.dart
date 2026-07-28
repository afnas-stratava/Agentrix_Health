import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/weekly_log_entry.dart';
import '../../providers/meals_provider.dart';

class FoodLogScreen extends ConsumerWidget {
  const FoodLogScreen({super.key});

  static const _dinnerMealId = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(mealsProvider);
    final weeklyLog = ref.watch(weeklyLogProvider);
    final todayLabel = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final maxCal = weeklyLog
        .map((e) => e.calories)
        .reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(todayLabel, style: AppTextStyles.muted.copyWith(fontSize: 13)),
          const SizedBox(height: AppSpacing.space4),
          AppButton(
            label: 'Log a meal',
            block: true,
            leading: const Icon(Icons.restaurant_menu_outlined, size: 16),
            onPressed: () =>
                ref.read(mealsProvider.notifier).logMeal(_dinnerMealId),
          ),
          const SizedBox(height: AppSpacing.space4),
          for (final meal in meals) ...[
            AppCard(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(meal.name, style: AppTextStyles.cardKicker),
                    Text(
                      meal.calorieLabel,
                      style: AppTextStyles.h6.copyWith(
                        letterSpacing: 0,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  meal.itemLabel,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
                if (meal.logged)
                  Text(meal.macroText, style: AppTextStyles.cardMeta),
              ],
            ),
            const SizedBox(height: AppSpacing.space2),
          ],
          const SizedBox(height: AppSpacing.space2),
          AppCard(
            children: [
              Text('This week', style: AppTextStyles.cardKicker),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space2,
                ),
                child: _WeeklyChart(entries: weeklyLog, maxCal: maxCal),
              ),
              Text(
                'avg 1,840 cal/day — slightly high in sugar',
                style: AppTextStyles.cardBody,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.entries, required this.maxCal});

  final List<WeeklyLogEntry> entries;
  final int maxCal;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 6,
      children: [
        for (var i = 0; i < entries.length; i++)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 4,
              children: [
                Container(
                  height: (entries[i].calories / maxCal) * 52,
                  decoration: BoxDecoration(
                    color: i == entries.length - 1
                        ? AppColors.accent
                        : AppColors.neutral800,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  entries[i].dayLabel,
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 10,
                    color: AppColors.neutral600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
