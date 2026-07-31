import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/iso_day.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/entities/nutrition/food_definition.dart';
import '../../../domain/entities/nutrition/macros.dart';
import '../../../domain/entities/nutrition/meal_entry.dart';
import '../../../features/nutrition/food_database.dart';
import '../../../features/nutrition/suggest_plate.dart';
import '../../providers/nutrition_providers.dart';
import '../../providers/user_profile_provider.dart';

/// Meal logging. Mirrors `app/meal/log.tsx`.
///
/// Two ways in — photograph the plate, or search — converging on the same
/// confirm-and-adjust list. The photo is attached to the entry and the
/// suggestion list is ranked from the user's own profile and history; the copy
/// is explicit that it is *not* read from the image, because a food log that
/// quietly invents portions is worse than no food log.
class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({super.key});

  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
  late MealSlot _slot;
  String? _photoPath;
  String _query = '';
  final List<LoggedFood> _selected = [];

  @override
  void initState() {
    super.initState();
    _slot = MealSlot.forHour(DateTime.now().hour);
  }

  Macros get _total => sumMacros(_selected.map((f) => f.macros));

  /// Tapping the same dish twice means a second helping, not a duplicate row.
  void _addFood(FoodDefinition definition) {
    HapticFeedback.lightImpact();
    setState(() {
      final existing = _selected.indexWhere((f) => f.foodId == definition.id);
      if (existing != -1) {
        final current = _selected[existing];
        _selected[existing] = LoggedFood.fromDefinition(
          definition,
          portions: current.portions + 1,
        );
      } else {
        _selected.add(LoggedFood.fromDefinition(definition));
      }
      _query = '';
    });
  }

  /// Rescales from the *definition*, never from the already-scaled macros —
  /// otherwise repeated adjustments compound rounding error.
  void _changePortions(int index, double delta) {
    setState(() {
      final food = _selected[index];
      final next = ((food.portions + delta) * 2).round() / 2;
      if (next <= 0) {
        _selected.removeAt(index);
        return;
      }
      final definition = food.foodId == null ? null : findFood(food.foodId!);
      if (definition == null) return;
      _selected[index] = LoggedFood.fromDefinition(
        definition,
        portions: next,
      );
    });
  }

  Future<void> _attachPhoto(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _photoPath = picked.path);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not attach the photo: $error')),
      );
    }
  }

  Future<void> _save() async {
    if (_selected.isEmpty) return;
    await HapticFeedback.mediumImpact();

    final now = DateTime.now();
    await ref.read(mealLogProvider.notifier).add(
      MealEntry(
        id: 'meal-${now.microsecondsSinceEpoch}',
        day: toIsoDay(now),
        loggedAt: now,
        slot: _slot,
        source: _photoPath != null ? MealSource.photo : MealSource.database,
        foods: List.of(_selected),
        photoPath: _photoPath,
        // Confirmed by the user on this screen, so the entry is fully trusted
        // regardless of how the foods got onto the list.
        confidence: 1,
      ),
    );

    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final recent = ref
        .watch(mealLogProvider)
        .meals
        .reversed
        .expand((m) => m.foods)
        .map((f) => f.foodId)
        .whereType<String>()
        .toList();

    final suggestions = suggestPlate(
      slot: _slot,
      profile: profile,
      recentFoodIds: recent,
    );
    final results = _query.trim().length > 1
        ? searchFoods(_query, limit: 12)
        : const <FoodDefinition>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
          child: Row(
            children: [
              const ScreenBackButton(),
              Expanded(
                child: Text(
                  'Log a meal',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h6.copyWith(
                    fontSize: 15,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: AppSpacing.space6),
            children: [
              // SLOT
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space5,
                  AppSpacing.space4,
                  AppSpacing.space5,
                  0,
                ),
                child: Row(
                  spacing: 6,
                  children: [
                    for (final option in MealSlot.values)
                      Expanded(
                        child: _SlotChip(
                          label: option.label,
                          selected: _slot == option,
                          onTap: () => setState(() => _slot = option),
                        ),
                      ),
                  ],
                ),
              ),

              // PHOTO
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space5,
                  AppSpacing.space5,
                  AppSpacing.space5,
                  0,
                ),
                child: _photoPath != null
                    ? _PhotoPreview(
                        path: _photoPath!,
                        onRemove: () => setState(() => _photoPath = null),
                      )
                    : Row(
                        spacing: 10,
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Take photo',
                              variant: AppButtonVariant.secondary,
                              leading: const Icon(
                                Icons.photo_camera_outlined,
                                size: 15,
                              ),
                              onPressed: () =>
                                  _attachPhoto(ImageSource.camera),
                            ),
                          ),
                          Expanded(
                            child: AppButton(
                              label: 'From library',
                              variant: AppButtonVariant.secondary,
                              leading: const Icon(Icons.image_outlined, size: 15),
                              onPressed: () =>
                                  _attachPhoto(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
              ),

              // SELECTED
              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space5,
                    AppSpacing.space6,
                    AppSpacing.space5,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(
                        title: 'On your plate',
                        count: _selected.length,
                      ),
                      SurfaceCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < _selected.length; i += 1)
                              _SelectedRow(
                                food: _selected[i],
                                isLast: i == _selected.length - 1,
                                onLess: () => _changePortions(i, -0.5),
                                onMore: () => _changePortions(i, 0.5),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // SEARCH
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space5,
                  AppSpacing.space6,
                  AppSpacing.space5,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(title: 'Add food'),
                    _SearchField(
                      value: _query,
                      onChanged: (value) => setState(() => _query = value),
                      onClear: () => setState(() => _query = ''),
                    ),
                    if (results.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SurfaceCard(
                          child: Column(
                            children: [
                              for (final item in results)
                                _FoodRow(
                                  title: item.name,
                                  detail:
                                      '${item.portionLabel} · '
                                      '${item.macros.calories} kcal',
                                  isLast: item == results.last,
                                  onTap: () => _addFood(item),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // SUGGESTIONS
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space5,
                    AppSpacing.space6,
                    AppSpacing.space5,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(
                        title: 'Likely at ${_slot.label.toLowerCase()}',
                      ),
                      // The disclosure sits above the list, not under it: it
                      // changes how the list should be read.
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.space3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.04),
                          border: Border.all(color: AppColors.hairline),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: AppSpacing.space2,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 14,
                              color: AppColors.faint,
                            ),
                            Expanded(
                              child: Text(
                                suggestionBasis,
                                style: AppTextStyles.cardMeta.copyWith(
                                  fontSize: 11,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SurfaceCard(
                        child: Column(
                          children: [
                            for (final suggestion in suggestions)
                              _FoodRow(
                                title: suggestion.food.name,
                                detail:
                                    '${suggestion.food.portionLabel} · '
                                    '${suggestion.food.macros.calories} kcal · '
                                    '${suggestion.reason}',
                                isLast: suggestion == suggestions.last,
                                onTap: () => _addFood(suggestion.food),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        _SaveBar(
          total: _total,
          count: _selected.length,
          onSave: _save,
        ),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand600 : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.brand600 : AppColors.hairline,
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            style: AppTextStyles.cardMeta.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.onBrand : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Image.file(
            File(path),
            height: 176,
            width: double.infinity,
            fit: BoxFit.cover,
            // A missing file must not take the screen down — the log entry is
            // still valid without its picture.
            errorBuilder: (_, _, _) => Container(
              height: 176,
              color: AppColors.neutral200,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: AppColors.faint,
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Semantics(
            button: true,
            label: 'Remove photo',
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Stateful so the controller outlives a rebuild.
///
/// Rebuilding a `TextEditingController` inside `build` resets the selection on
/// every keystroke, which fights the cursor and drops the IME composing region.
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_SearchField old) {
    super.didUpdateWidget(old);
    // Only when the parent genuinely diverged — e.g. cleared on selection.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        spacing: AppSpacing.space2,
        children: [
          const Icon(Icons.search, size: 16, color: AppColors.faint),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              autocorrect: false,
              style: AppTextStyles.input.copyWith(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search dal, dosa, salmon…',
                hintStyle: AppTextStyles.input.copyWith(
                  fontSize: 14,
                  color: AppColors.faint,
                ),
              ),
            ),
          ),
          if (widget.value.isNotEmpty)
            Semantics(
              button: true,
              label: 'Clear',
              child: InkWell(
                onTap: widget.onClear,
                child: const Icon(
                  Icons.close,
                  size: 15,
                  color: AppColors.faint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedRow extends StatelessWidget {
  const _SelectedRow({
    required this.food,
    required this.isLast,
    required this.onLess,
    required this.onMore,
  });

  final LoggedFood food;
  final bool isLast;
  final VoidCallback onLess;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      child: Row(
        spacing: AppSpacing.space3,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${food.macros.calories} kcal · '
                  '${food.macros.proteinG.round()} g protein',
                  style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Row(
            spacing: AppSpacing.space2,
            children: [
              _StepButton(
                icon: Icons.remove,
                label: 'Less ${food.name}',
                onTap: onLess,
              ),
              SizedBox(
                width: 26,
                child: Text(
                  food.portions == food.portions.roundToDouble()
                      ? '${food.portions.round()}'
                      : '${food.portions}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h6.copyWith(
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                label: 'More ${food.name}',
                filled: true,
                onTap: onMore,
              ),
            ],
          ),
        ],
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? AppColors.brand600
                : AppColors.ink.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 13,
            color: filled ? AppColors.onBrand : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.title,
    required this.detail,
    required this.isLast,
    required this.onTap,
  });

  final String title;
  final String detail;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scaleTo: 0.985,
      semanticLabel: 'Add $title',
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
        child: Row(
          spacing: AppSpacing.space3,
          children: [
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
                    detail,
                    style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.add, size: 16, color: AppColors.brand),
          ],
        ),
      ),
    );
  }
}

/// Pinned rather than scrolled: the running total is the number that decides
/// whether you add one more thing, so it has to stay in view while you browse.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.total,
    required this.count,
    required this.onSave,
  });

  final Macros total;
  final int count;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space3,
        AppSpacing.space5,
        AppSpacing.space3 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
                    children: [
                      TextSpan(text: '${total.calories} kcal'),
                      if (count > 0)
                        TextSpan(
                          text:
                              '  ${total.proteinG.round()}P · '
                              '${total.carbsG.round()}C · '
                              '${total.fatG.round()}F',
                          style: AppTextStyles.cardBody,
                        ),
                    ],
                  ),
                ),
              ),
              Text(
                '$count item${count == 1 ? '' : 's'}',
                style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppButton(
            label: count == 0 ? 'Add something first' : 'Save meal',
            size: AppButtonSize.lg,
            block: true,
            onPressed: count == 0 ? null : onSave,
          ),
        ],
      ),
    );
  }
}
