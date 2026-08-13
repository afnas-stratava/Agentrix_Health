import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Mirrors `src/components/ui/Choice.tsx`.
///
/// The three selection primitives onboarding and the profile editor share, so a
/// user who changes a goal later recognises the control they used at signup.

/// A full-width option with a label and the reason to pick it.
///
/// A hint on every row rather than only the unusual ones: if one option needs
/// explaining, the others need explaining too, or the explained one reads as
/// the recommended one.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
    this.isCheckbox = false,
  });

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;
  final bool isCheckbox;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.space4),
            decoration: BoxDecoration(
              color: selected ? AppColors.brand50 : AppColors.surface,
              border: Border.all(
                color: selected ? AppColors.brand400 : AppColors.hairline,
                width: selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.space3,
              children: [
                Icon(
                  isCheckbox
                      ? (selected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded)
                      : (selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked),
                  size: 18,
                  color: selected ? AppColors.brand : AppColors.faint,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                      ),
                      if (hint != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          hint!,
                          style: AppTextStyles.cardBody.copyWith(height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Layout for a set of [ChoiceChip]s.
class ChipGroup extends StatelessWidget {
  const ChipGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: children,
    );
  }
}

enum ChoiceChipTone {
  brand,

  /// For allergens — a hard exclusion, not a preference, and coloured to say so.
  critical,
}

/// A multi-select chip, optionally carrying its selection order.
class ChoiceChip extends StatelessWidget {
  const ChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.rank,
    this.tone = ChoiceChipTone.brand,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 1-based position when order is meaningful, as it is for cuisines.
  final int? rank;

  final ChoiceChipTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone == ChoiceChipTone.critical
        ? AppColors.critical
        : AppColors.brand;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            rank != null ? 6 : AppSpacing.space3 + 2,
            8,
            AppSpacing.space3 + 2,
            8,
          ),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.1)
                : AppColors.surface,
            border: Border.all(
              color: selected ? accent : AppColors.hairline,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              if (rank != null)
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: AppTextStyles.tag.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onBrand,
                    ),
                  ),
                ),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? accent : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A numeric field with increment and decrement.
///
/// A stepper rather than a text field because these are bounded, low-precision
/// values that a keyboard makes slower to enter, not faster — and because a
/// stepper cannot produce a height of 1750 cm.
class Stepper extends StatelessWidget {
  const Stepper({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.step = 1,
    this.fallback,
    this.formatValue,
  });

  final String label;
  final String unit;

  /// Null when the user has never set it — the row shows a dash and the first
  /// tap seeds [fallback] rather than jumping from zero.
  final double? value;

  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;
  final double? fallback;

  /// Overrides the default "172" / "32.5" rendering — e.g. height in feet and
  /// inches, which reads as "5'10"" rather than a bare number. [unit] is
  /// typically empty when this is set, since the format already carries it.
  final String Function(double value)? formatValue;

  void _nudge(double delta) {
    final current = value ?? fallback ?? min;
    final next = (current + delta).clamp(min, max);
    // Rounded to the step so repeated 0.5 nudges cannot drift.
    onChanged((next / step).round() * step);
  }

  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? '—'
        : formatValue != null
        ? formatValue!(value!)
        : (value! == value!.roundToDouble()
              ? '${value!.round()}'
              : value!.toStringAsFixed(1));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
              ),
            ),
            _StepButton(
              icon: Icons.remove,
              label: 'Decrease $label',
              onTap: () => _nudge(-step),
            ),
            // A minimum rather than a fixed width: "32 years" and "172 cm" are
            // different widths, and a fixed box overflows on the longer one.
            // The label above is `Expanded`, so it yields the space instead.
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 76),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  spacing: 3,
                  children: [
                    Text(
                      display,
                      style: AppTextStyles.h6.copyWith(
                        fontSize: 16,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      unit,
                      style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              label: 'Increase $label',
              filled: true,
              onTap: () => _nudge(step),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? AppColors.brand600
                : AppColors.ink.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 15,
            color: filled ? AppColors.onBrand : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
