import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../util/iso_day.dart';

/// The date scope for everything below it.
///
/// One control, above the figures it scopes — not a filter per card. Every
/// figure on the screen re-reads from the same selected day, so two cards can
/// never disagree about which day is on screen.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final List<IsoDay> days;
  final IsoDay selected;
  final ValueChanged<IsoDay> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = toIsoDay(DateTime.now());

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.space1),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day == selected;
          final date = fromIsoDay(day);

          // The selected chip spells the date out; the rest are just the day
          // number, so the strip stays scannable instead of a wall of text.
          final label = isSelected
              ? (day == today
                    ? 'Today, ${DateFormat('d MMM').format(date)}'
                    : DateFormat('EEE, d MMM').format(date))
              : DateFormat('d').format(date);

          return Semantics(
            inMutuallyExclusiveGroup: true,
            selected: isSelected,
            label: DateFormat('EEEE, d MMMM').format(date),
            child: Material(
              color: isSelected ? AppColors.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                onTap: () => onSelect(day),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(minWidth: 44),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? AppSpacing.space4 : AppSpacing.space2,
                  ),
                  child: Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? AppColors.onBrand : AppColors.faint,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
