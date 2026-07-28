import 'package:flutter/material.dart';

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
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(AppSpacing.space4),
      ),
      clipBehavior: Clip.antiAlias,
      child: row,
    );
  }

  Widget _buildOption(SegmentedOption<T> option, {required bool isFirst}) {
    final isChecked = option.value == selected;
    final child = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isChecked ? AppColors.accent : Colors.transparent,
        border: isFirst
            ? null
            : Border(left: BorderSide(color: AppColors.divider)),
      ),
      child: Text(
        option.label,
        style: AppTextStyles.body.copyWith(
          fontSize: 13,
          color: isChecked ? AppColors.bg : AppColors.text,
        ),
      ),
    );

    final tappable = InkWell(
      onTap: () => onChanged(option.value),
      child: child,
    );
    return expand ? Expanded(child: tappable) : tappable;
  }
}
