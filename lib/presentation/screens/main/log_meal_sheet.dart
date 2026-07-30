import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/iso_day.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../domain/entities/nutrition/food_definition.dart';
import '../../../domain/entities/nutrition/macros.dart';
import '../../../domain/entities/nutrition/meal_entry.dart';
import '../../../features/nutrition/food_database.dart';
import '../../../features/nutrition/suggest_plate.dart';
import '../../providers/nutrition_providers.dart';
import '../../providers/user_profile_provider.dart';

/// Logs a meal.
///
/// Three ways in, in the order people use them: confirm what we suspect you ate,
/// search the table, or attach a photo and then confirm. The photo path is
/// deliberately *not* labelled as recognition — see [suggestionBasis] — because
/// there is no vision model behind it, and a macro number the user believes was
/// measured is worse than one they know they confirmed.
Future<void> showLogMealSheet(BuildContext context, {MealSlot? slot}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _LogMealSheet(initialSlot: slot),
  );
}

class _LogMealSheet extends ConsumerStatefulWidget {
  const _LogMealSheet({this.initialSlot});

  final MealSlot? initialSlot;

  @override
  ConsumerState<_LogMealSheet> createState() => _LogMealSheetState();
}

class _LogMealSheetState extends ConsumerState<_LogMealSheet> {
  late MealSlot _slot;

  /// Food id → portion multiplier. A map rather than a set so the ×1.5 case is
  /// representable, which matters for rice and roti more than anything else.
  final _selected = <String, double>{};

  String _query = '';
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _slot = widget.initialSlot ?? MealSlot.forHour(DateTime.now().hour);
  }

  Macros get _runningTotal {
    final items = <Macros>[];
    for (final entry in _selected.entries) {
      final food = findFood(entry.key);
      if (food == null) continue;
      items.add(
        entry.value == 1 ? food.macros : food.macros.scaled(entry.value),
      );
    }
    return sumMacros(items);
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.containsKey(id)) {
        _selected.remove(id);
      } else {
        _selected[id] = 1;
      }
    });
  }

  void _bumpPortion(String id, double delta) {
    setState(() {
      final next = ((_selected[id] ?? 1) + delta).clamp(0.5, 10.0);
      _selected[id] = next;
    });
  }

  Future<void> _attachPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _photoPath = picked.path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not attach that photo: $error')),
      );
    }
  }

  Future<void> _save() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);

    final now = DateTime.now();
    final foods = <LoggedFood>[];
    for (final entry in _selected.entries) {
      final food = findFood(entry.key);
      if (food == null) continue;
      foods.add(LoggedFood.fromDefinition(food, portions: entry.value));
    }

    if (foods.isEmpty) {
      setState(() => _saving = false);
      return;
    }

    await ref.read(mealLogProvider.notifier).add(
      MealEntry(
        id: 'meal-${now.microsecondsSinceEpoch}',
        day: toIsoDay(now),
        loggedAt: now,
        slot: _slot,
        // A photo was attached, but the macros came from the user's own
        // confirmation — which is exactly what `photo` means here.
        source: _photoPath != null ? MealSource.photo : MealSource.database,
        foods: foods,
        photoPath: _photoPath,
      ),
    );

    if (mounted) Navigator.of(context).pop();
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
    final results = _query.trim().isEmpty
        ? const <FoodDefinition>[]
        : searchFoods(_query);

    final total = _runningTotal;
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          child: Column(
            children: [
              const _Grabber(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space5,
                    0,
                    AppSpacing.space5,
                    AppSpacing.space5,
                  ),
                  children: [
                    Text('Log a meal', style: AppTextStyles.h4),
                    const SizedBox(height: AppSpacing.space4),

                    SegmentedControl<MealSlot>(
                      options: [
                        for (final slot in MealSlot.values)
                          SegmentedOption(value: slot, label: slot.label),
                      ],
                      selected: _slot,
                      onChanged: (slot) => setState(() => _slot = slot),
                    ),
                    const SizedBox(height: AppSpacing.space4),

                    _PhotoRow(
                      photoPath: _photoPath,
                      onCamera: () => _attachPhoto(ImageSource.camera),
                      onLibrary: () => _attachPhoto(ImageSource.gallery),
                      onClear: () => setState(() => _photoPath = null),
                    ),
                    const SizedBox(height: AppSpacing.space4),

                    AppTextField(
                      label: 'Search the food table',
                      value: _query,
                      placeholder: 'dal, dosa, salmon…',
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: AppSpacing.space4),

                    if (results.isNotEmpty) ...[
                      _MicroLabel(label: '${results.length} matches'),
                      for (final food in results)
                        _FoodRow(
                          food: food,
                          portions: _selected[food.id],
                          onTap: () => _toggle(food.id),
                          onBump: (delta) => _bumpPortion(food.id, delta),
                        ),
                    ] else ...[
                      const _MicroLabel(label: "What's on the plate?"),
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.space3,
                        ),
                        child: Text(
                          suggestionBasis,
                          style: AppTextStyles.cardBody.copyWith(height: 1.45),
                        ),
                      ),
                      for (final suggestion in suggestions)
                        _FoodRow(
                          food: suggestion.food,
                          portions: _selected[suggestion.food.id],
                          caption: suggestion.reason,
                          onTap: () => _toggle(suggestion.food.id),
                          onBump: (delta) =>
                              _bumpPortion(suggestion.food.id, delta),
                        ),
                    ],
                  ],
                ),
              ),
              _Footer(
                total: total,
                count: _selected.length,
                saving: _saving,
                onSave: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.hairline,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

class _MicroLabel extends StatelessWidget {
  const _MicroLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.tag.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.photoPath,
    required this.onCamera,
    required this.onLibrary,
    required this.onClear,
  });

  final String? photoPath;
  final VoidCallback onCamera;
  final VoidCallback onLibrary;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (photoPath != null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: AppColors.brand50,
          border: Border.all(color: AppColors.brand200),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          spacing: AppSpacing.space2,
          children: [
            const Icon(
              Icons.photo_camera_back_outlined,
              size: 16,
              color: AppColors.brand,
            ),
            Expanded(
              child: Text(
                'Photo attached to this entry',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand800,
                ),
              ),
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 16),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
    }

    return Row(
      spacing: AppSpacing.space2,
      children: [
        Expanded(
          child: AppButton(
            label: 'Take a photo',
            variant: AppButtonVariant.secondary,
            leading: const Icon(Icons.photo_camera_outlined, size: 15),
            onPressed: onCamera,
          ),
        ),
        Expanded(
          child: AppButton(
            label: 'From library',
            variant: AppButtonVariant.secondary,
            leading: const Icon(Icons.image_outlined, size: 15),
            onPressed: onLibrary,
          ),
        ),
      ],
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.food,
    required this.portions,
    required this.onTap,
    required this.onBump,
    this.caption,
  });

  final FoodDefinition food;
  final double? portions;
  final VoidCallback onTap;
  final ValueChanged<double> onBump;
  final String? caption;

  bool get _selected => portions != null;

  @override
  Widget build(BuildContext context) {
    final macros = _selected && portions != 1
        ? food.macros.scaled(portions!)
        : food.macros;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Material(
        color: _selected ? AppColors.brand50 : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.space3),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selected ? AppColors.brand400 : AppColors.hairline,
                width: _selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              spacing: AppSpacing.space3,
              children: [
                Icon(
                  _selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: _selected ? AppColors.brand : AppColors.faint,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${food.portionLabel} · ${macros.calories} kcal · '
                        '${macros.proteinG.round()} g protein',
                        style: AppTextStyles.cardMeta,
                      ),
                      if (caption != null && !_selected) ...[
                        const SizedBox(height: 1),
                        Text(
                          caption!,
                          style: AppTextStyles.cardMeta.copyWith(
                            fontSize: 10,
                            color: AppColors.brand600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_selected)
                  Row(
                    children: [
                      _StepButton(icon: Icons.remove, onTap: () => onBump(-0.5)),
                      SizedBox(
                        width: 30,
                        child: Text(
                          _portionLabel,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h6.copyWith(
                            fontSize: 13,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      _StepButton(icon: Icons.add, onTap: () => onBump(0.5)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _portionLabel {
    final value = portions ?? 1;
    return value == value.roundToDouble()
        ? '×${value.round()}'
        : '×$value';
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 15, color: AppColors.brand700),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.total,
    required this.count,
    required this.saving,
    required this.onSave,
  });

  final Macros total;
  final int count;
  final bool saving;
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
      child: Row(
        spacing: AppSpacing.space3,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count == 0
                      ? 'Nothing selected'
                      : '${total.calories} kcal · '
                            '${total.proteinG.round()} g protein',
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 1),
                Text(
                  count == 0
                      ? 'Pick what you ate'
                      : '$count item${count == 1 ? '' : 's'}',
                  style: AppTextStyles.cardMeta,
                ),
              ],
            ),
          ),
          AppButton(
            label: saving ? 'Saving…' : 'Log it',
            onPressed: count == 0 || saving ? null : onSave,
          ),
        ],
      ),
    );
  }
}
