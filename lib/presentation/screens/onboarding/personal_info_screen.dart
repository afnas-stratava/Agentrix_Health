import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_choice_row.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../../../core/widgets/status_bar_style.dart';
import '../../../domain/entities/allergy.dart';
import '../../../domain/entities/cuisine_preference.dart';
import '../../../domain/entities/gender.dart';
import '../../../domain/entities/health_goal.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/user_profile_provider.dart';

/// Step 1 of onboarding.
///
/// Follows the layout the React Native onboarding steps use
/// (`app/onboarding/{body,goals,diet}.tsx`): a circular back button alone at
/// the top, the headline and its rationale *inside* the scroll view so they
/// give up their space as you work, uppercase micro-labels rather than a
/// second tier of bold headings, and the CTA pinned at the bottom with a
/// single quiet status line underneath it.
///
/// The groups are ordered hard-filter-first — goal, then allergies, then
/// cuisine taste — because that is the order in which the answers constrain
/// what the app may suggest.
class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  static const int _minAge = 1;
  static const int _maxAge = 120;

  /// `px-8` on the RN steps, against `px-6` for the back-button row.
  static const double _bodyInset = AppSpacing.space8;

  final _nameFocus = FocusNode();
  final _ageFocus = FocusNode();

  /// Errors only surface once a field has been visited and left — nobody
  /// should be told "1 is not an age" while typing the 1 of 18.
  bool _ageTouched = false;

  @override
  void initState() {
    super.initState();
    _ageFocus.addListener(() {
      if (!_ageFocus.hasFocus && !_ageTouched) {
        setState(() => _ageTouched = true);
      }
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _ageFocus.dispose();
    super.dispose();
  }

  bool _ageIsValid(String age) {
    final parsed = int.tryParse(age.trim());
    return parsed != null && parsed >= _minAge && parsed <= _maxAge;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);

    final hasName = profile.name.trim().isNotEmpty;
    final ageFilled = profile.age.trim().isNotEmpty;
    final ageValid = _ageIsValid(profile.age);
    final canContinue = hasName && ageValid;

    final ageError = _ageTouched && ageFilled && !ageValid
        ? 'Enter $_minAge–$_maxAge'
        : null;

    final restrictionCount =
        profile.allergies.length + profile.customRestrictions.length;

    return StatusBarStyle(
      light: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            // Stands in for `resizeToAvoidBottomInset` (there is no Scaffold
            // here): the column shrinks above the keyboard so the footer CTA
            // stays reachable instead of being buried under it.
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(
                  onBack: () => ref.read(appStageProvider.notifier).goWelcome(),
                ),
                Expanded(
                  child: _FadingScroll(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        _bodyInset,
                        AppSpacing.space6,
                        _bodyInset,
                        AppSpacing.space6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tell us about you',
                            style: AppTextStyles.h3.copyWith(
                              fontSize: 28,
                              height: 32 / 28,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space3),
                          Text(
                            'Your name and age set the baseline for every '
                            'target we calculate. Everything below is optional '
                            'and only makes suggestions sharper — you can '
                            'change any of it later.',
                            style: AppTextStyles.muted.copyWith(
                              fontSize: 13,
                              height: 20 / 13,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space6),

                          // No micro-label here: the headline already names
                          // this group, and a second heading would just
                          // compete with it.
                          AppTextField(
                            label: 'Name',
                            value: profile.name,
                            placeholder: 'Your name',
                            focusNode: _nameFocus,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.givenName],
                            onSubmitted: (_) => _ageFocus.requestFocus(),
                            onChanged: notifier.setName,
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: AppSpacing.space3,
                            children: [
                              Expanded(
                                flex: 2,
                                child: AppTextField(
                                  label: 'Age',
                                  value: profile.age,
                                  placeholder: '—',
                                  keyboardType: TextInputType.number,
                                  focusNode: _ageFocus,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  errorText: ageError,
                                  onSubmitted: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  onChanged: notifier.setAge,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 5,
                                  children: [
                                    Text(
                                      'Gender',
                                      style: AppTextStyles.fieldLabel,
                                    ),
                                    SizedBox(
                                      height: 48,
                                      child: SegmentedControl<Gender>(
                                        expand: true,
                                        selected: profile.gender,
                                        options: const [
                                          SegmentedOption(
                                            value: Gender.female,
                                            label: 'Female',
                                          ),
                                          SegmentedOption(
                                            value: Gender.male,
                                            label: 'Male',
                                          ),
                                        ],
                                        onChanged: (gender) {
                                          HapticFeedback.selectionClick();
                                          notifier.setGender(gender);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const _MicroLabel(
                            title: 'Your main goal',
                            hint:
                                'Sets your calorie offset and how much '
                                'protein we hold you to.',
                          ),
                          Column(
                            spacing: 10,
                            children: [
                              for (final goal in _goalDisplayOrder)
                                AppChoiceRow(
                                  label: goal.label,
                                  hint: _goalHint(goal),
                                  icon: _goalIcon(goal),
                                  selected: goal == profile.goal,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    notifier.setGoal(goal);
                                  },
                                ),
                            ],
                          ),

                          _MicroLabel(
                            title: 'Allergies & restrictions',
                            icon: Icons.shield_outlined,
                            iconColor: AppColors.critical,
                            count: restrictionCount,
                            hint:
                                'Optional. Anything selected here is '
                                'excluded outright, everywhere in the app.',
                          ),
                          Wrap(
                            spacing: AppSpacing.space2,
                            runSpacing: AppSpacing.space2,
                            children: [
                              for (final allergy in Allergy.values)
                                SelectableChip(
                                  label: allergy.label,
                                  selected: profile.allergies.contains(allergy),
                                  selectedBackground: _criticalTint,
                                  selectedForeground: AppColors.critical,
                                  selectedBorder: _criticalBorder,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    notifier.toggleAllergy(allergy);
                                  },
                                ),
                              for (final restriction
                                  in profile.customRestrictions)
                                SelectableChip(
                                  label: restriction,
                                  selected: true,
                                  selectedBackground: _criticalTint,
                                  selectedForeground: AppColors.critical,
                                  selectedBorder: _criticalBorder,
                                  onTap: () {},
                                  onRemove: () {
                                    HapticFeedback.selectionClick();
                                    notifier.removeCustomRestriction(
                                      restriction,
                                    );
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.space3),
                          _CustomRestrictionInput(
                            onSubmit: notifier.addCustomRestriction,
                          ),

                          _MicroLabel(
                            title: 'Cuisines you eat most',
                            count: profile.cuisines.length,
                            hint:
                                'Optional. Tap in order of preference — the '
                                'first one you pick carries the most weight.',
                          ),
                          Wrap(
                            spacing: AppSpacing.space2,
                            runSpacing: AppSpacing.space2,
                            children: [
                              for (final cuisine in CuisinePreference.values)
                                () {
                                  final rank = profile.cuisines.indexOf(
                                    cuisine,
                                  );
                                  return SelectableChip(
                                    label: cuisine.label,
                                    selected: rank != -1,
                                    rank: rank == -1 ? null : rank + 1,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      notifier.toggleCuisine(cuisine);
                                    },
                                  );
                                }(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _Footer(
                  status: _footerStatus(
                    hasName: hasName,
                    ageFilled: ageFilled,
                    ageValid: ageValid,
                    cuisineCount: profile.cuisines.length,
                  ),
                  onContinue: canContinue
                      ? () {
                          FocusScope.of(context).unfocus();
                          ref.read(appStageProvider.notifier).goBloodTest();
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `bg-critical/10` and `border-critical/40` from the RN `ChoiceChip`
  /// critical tone — an allergy chip should never read as a taste preference.
  static final Color _criticalTint = AppColors.critical.withValues(alpha: 0.1);
  static final Color _criticalBorder = AppColors.critical.withValues(
    alpha: 0.4,
  );

  /// One line under the CTA: what is missing while the form is incomplete,
  /// and a plain statement of where things stand once it isn't.
  String _footerStatus({
    required bool hasName,
    required bool ageFilled,
    required bool ageValid,
    required int cuisineCount,
  }) {
    if (ageFilled && !ageValid) return 'That age doesn\'t look right.';
    if (!hasName && !ageFilled) return 'Add your name and age to continue.';
    if (!hasName) return 'Add your name to continue.';
    if (!ageValid) return 'Add your age to continue.';
    if (cuisineCount == 0) {
      return 'Skipping the optional answers is fine — suggestions will just '
          'be less tailored.';
    }
    return '$cuisineCount cuisine${cuisineCount == 1 ? '' : 's'} selected.';
  }

  /// `UserProfile.initial()` preselects [HealthGoal.generalWellness], so it
  /// leads the group — with the enum's own order the one selected row sat
  /// fourth, below the fold, and the whole group read as "nothing picked".
  static const List<HealthGoal> _goalDisplayOrder = [
    HealthGoal.generalWellness,
    HealthGoal.loseWeight,
    HealthGoal.buildMuscle,
    HealthGoal.manageCondition,
  ];

  static String _goalHint(HealthGoal goal) => switch (goal) {
    HealthGoal.loseWeight => 'Calorie-aware meals that keep protein steady.',
    HealthGoal.buildMuscle => 'Higher protein targets and training-day meals.',
    HealthGoal.manageCondition => 'Meals that work around your blood markers.',
    HealthGoal.generalWellness => 'Balanced eating, no strict targets.',
  };

  static IconData _goalIcon(HealthGoal goal) => switch (goal) {
    HealthGoal.loseWeight => Icons.trending_down,
    HealthGoal.buildMuscle => Icons.fitness_center,
    HealthGoal.manageCondition => Icons.monitor_heart_outlined,
    HealthGoal.generalWellness => Icons.self_improvement,
  };
}

/// Back affordance plus the step track. The RN steps carry only the back
/// button — each of them asks one question, so progress is implicit. This
/// screen still holds a whole step of the flow, so the track earns its place;
/// the wording ("STEP 1 OF 3") does not, and lives in the semantics instead.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space2,
        AppSpacing.space6,
        0,
      ),
      child: Row(
        spacing: AppSpacing.space4,
        children: [
          AppButton.icon(
            leading: const Icon(Icons.arrow_back),
            backgroundColor: AppColors.surface,
            onPressed: onBack,
          ),
          Expanded(
            child: Semantics(
              container: true,
              label: 'Step 1 of 3',
              child: Row(
                spacing: 5,
                children: [
                  for (var step = 1; step <= 3; step++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 4,
                        decoration: BoxDecoration(
                          color: step == 1
                              ? AppColors.brand
                              : AppColors.hairline,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `text-[11px] font-semibold uppercase tracking-wider text-muted` with the
/// RN `SectionHeader` count badge, over a 12px faint explainer. Quiet enough
/// that the headline stays the only thing shouting on the screen.
class _MicroLabel extends StatelessWidget {
  const _MicroLabel({
    required this.title,
    this.hint,
    this.count,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String? hint;
  final int? count;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.space8 - AppSpacing.space2,
        bottom: AppSpacing.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: AppSpacing.space2,
            children: [
              if (icon != null)
                Icon(icon, size: 15, color: iconColor ?? AppColors.muted),
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  style: AppTextStyles.tag.copyWith(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: AppColors.muted,
                  ),
                ),
              ),
              if (count != null && count! > 0) _CountBadge(count: count!),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                hint!,
                style: AppTextStyles.cardMeta.copyWith(
                  fontSize: 12,
                  height: 17 / 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: AppTextStyles.tag.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.ink.withValues(alpha: 0.8),
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// Fades content into the footer instead of letting it end on a hard crop, so
/// "there is more below" is visible without scrolling first.
class _FadingScroll extends StatelessWidget {
  const _FadingScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: AppSpacing.space6,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.canvas.withValues(alpha: 0),
                    AppColors.canvas,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// CTA with the status line *under* it, as on the RN steps — the button is the
/// thing the eye should land on, and the sentence explaining it comes second.
class _Footer extends StatelessWidget {
  const _Footer({required this.status, required this.onContinue});

  final String status;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space8,
        AppSpacing.space2,
        AppSpacing.space8,
        AppSpacing.space6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: 'Continue',
            block: true,
            size: AppButtonSize.lg,
            leading: const Icon(Icons.arrow_forward),
            onPressed: onContinue,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            status,
            textAlign: TextAlign.center,
            style: AppTextStyles.cardMeta.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _CustomRestrictionInput extends StatefulWidget {
  const _CustomRestrictionInput({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_CustomRestrictionInput> createState() =>
      _CustomRestrictionInputState();
}

class _CustomRestrictionInputState extends State<_CustomRestrictionInput> {
  final _focusNode = FocusNode();

  /// The field is driven by this, so clearing it after an add is a setState
  /// rather than a controller reach-through.
  String _text = '';

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _text.trim();
    if (value.isEmpty) return;
    widget.onSubmit(value);
    setState(() => _text = '');
    // Adding restrictions comes in bursts — keep the caret here so the second
    // one doesn't cost another tap.
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _text.trim().isNotEmpty;

    return AppTextField(
      label: 'Something else to avoid',
      value: _text,
      placeholder: 'e.g. shellfish',
      focusNode: _focusNode,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (value) => setState(() => _text = value),
      onSubmitted: (_) => _submit(),
      suffix: AppButton(
        label: 'Add',
        size: AppButtonSize.sm,
        variant: AppButtonVariant.secondary,
        onPressed: canAdd ? _submit : null,
      ),
    );
  }
}
