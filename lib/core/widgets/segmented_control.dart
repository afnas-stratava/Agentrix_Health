import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class SegmentedOption<T> {
  const SegmentedOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// Radio-style toggle group matching `.seg` / `.seg-opt`.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.expand = false,
  });

  final List<SegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i++)
          _buildOption(options[i], isFirst: i == 0),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      clipBehavior: Clip.antiAlias,
      child: row,
    );
  }

  Widget _buildOption(SegmentedOption<T> option, {required bool isFirst}) {
    final isChecked = option.value == selected;
    final child = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isChecked ? AppColors.brand : Colors.transparent,
        border: isFirst || isChecked
            ? null
            : Border(left: BorderSide(color: AppColors.hairline)),
      ),
      child: Text(
        option.label,
        style: AppTextStyles.body.copyWith(
          fontSize: 13,
          fontWeight: isChecked ? FontWeight.w600 : FontWeight.w500,
          color: isChecked ? AppColors.onBrand : AppColors.muted,
        ),
      ),
    );

    final tappable = InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(option.value);
      },
      child: child,
    );
    return expand ? Expanded(child: tappable) : tappable;
  }
}
