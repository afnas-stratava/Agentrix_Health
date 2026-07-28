import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/brief_line.dart';
import '../../providers/brief_provider.dart';
import '../../providers/user_profile_provider.dart';

class MorningBriefScreen extends ConsumerWidget {
  const MorningBriefScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brief = ref.watch(briefProvider);
    final profile = ref.watch(userProfileProvider);
    final lines = ref.watch(briefLinesProvider);
    final todayLabel = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(todayLabel, style: AppTextStyles.muted.copyWith(fontSize: 13)),
          const SizedBox(height: AppSpacing.space4),
          AppCard(
            backgroundColor: AppColors.accent900,
            padding: const EdgeInsets.all(AppSpacing.space4),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.space4),
                child: Text(
                  "Good morning ${profile.greetingName}. Here's your plan for today, based on your blood work and last night's sleep.",
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.bg,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              if (brief.loading)
                Column(
                  spacing: AppSpacing.space2,
                  children: List.generate(
                    3,
                    (_) => Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.accent800,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    for (final line in lines) _BriefLineRow(line: line),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.space4),
                child: AppButton(
                  label: 'Regenerate',
                  block: true,
                  foregroundColor: AppColors.accent2_400,
                  borderColor: AppColors.accent2_400,
                  leading: const Icon(Icons.refresh, size: 14),
                  onPressed: brief.loading
                      ? null
                      : () => ref.read(briefProvider.notifier).regenerate(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BriefLineRow extends StatelessWidget {
  const _BriefLineRow({required this.line});

  final BriefLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.accent700, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space3,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              line.tag.toUpperCase(),
              style: AppTextStyles.cardMeta.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.accent2_400,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Text(
              line.text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.neutral200,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
