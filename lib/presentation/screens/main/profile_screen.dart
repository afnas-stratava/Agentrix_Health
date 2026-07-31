import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../domain/entities/nutrition/meal_entry.dart';
import '../../../features/correlation/engine_context.dart';
import '../../providers/health_providers.dart';
import '../../providers/insights_providers.dart';
import '../../providers/labs_providers.dart';
import '../../providers/nutrition_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/user_profile_provider.dart';
import 'gmail_import_screen.dart';
import 'main_shell.dart';
import 'profile_edit_screen.dart';

/// Settings. Mirrors `app/(tabs)/settings.tsx`.
///
/// Eight sections in RN's order: profile, Apple Health, Gmail, reference ranges,
/// analysis window, which insights you see, demo data, your data.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.space5),
      child: ListView(
        padding: EdgeInsets.only(
          top: AppSpacing.space4,
          bottom: MainShell.bottomInsetFor(context),
        ),
        children: const [
          _Title(),
          _ProfileSection(),
          _AppleHealthSection(),
          _GmailSection(),
          _ReferenceRangeSection(),
          _AnalysisWindowSection(),
          _RuleToggleSection(),
          _DemoDataSection(),
          _YourDataSection(),
          _VersionFooter(),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) =>
      Text('Settings', style: AppTextStyles.screenTitle);
}

/// Uppercase micro-label above each card, from RN's `SectionLabel`.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space6 + AppSpacing.space1,
        AppSpacing.space6,
        AppSpacing.space3,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.tag.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.55,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brand50,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, size: 20, color: AppColors.brand),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Your profile
// ---------------------------------------------------------------------------

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Your profile'),
        SurfaceCard(
          padded: false,
          child: Column(
            children: [
              PressableScale(
                scaleTo: 0.99,
                semanticLabel: 'Edit your profile',
                onTap: () => MainShell.push(context, const ProfileEditScreen()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space5,
                    vertical: AppSpacing.space4,
                  ),
                  child: Row(
                    spacing: AppSpacing.space3,
                    children: [
                      const _RowIcon(Icons.person_outline),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name.trim().isEmpty
                                  ? 'Goal, diet and body'
                                  : profile.name,
                              style: AppTextStyles.cardTitle.copyWith(
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                profile.goal.label,
                                profile.effectiveDietPattern.label,
                                if (profile.weightKg != null)
                                  '${profile.weightKg!.round()} kg',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.cardMeta.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 17,
                        color: AppColors.faint,
                      ),
                    ],
                  ),
                ),
              ),

              if (profile.cuisines.isNotEmpty)
                _CardFooter(
                  child: Text(
                    'Cuisines: '
                    '${profile.cuisines.map((c) => c.label).join(', ')}',
                    style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
                  ),
                ),

              if (!profile.canComputeTargets)
                _CardFooter(
                  child: Text(
                    'Height, weight and age are missing — calorie and macro '
                    'targets stay switched off until they are set.',
                    style: AppTextStyles.cardBody.copyWith(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.borderline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space5,
        vertical: AppSpacing.space3,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Apple Health
// ---------------------------------------------------------------------------

class _AppleHealthSection extends ConsumerWidget {
  const _AppleHealthSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(telemetrySourceProvider);
    final synthetic = source == TelemetrySource.synthetic;
    final synced = syncLabel(ref.watch(lastSyncedAtProvider));
    final days = ref.watch(healthSeriesProvider).valueOrNull?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Apple Health'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: AppSpacing.space3,
                children: [
                  const _RowIcon(Icons.favorite_outline),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HealthKit access',
                          style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          synced ?? 'Never synced',
                          style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  AppTag(
                    label: synthetic ? 'Sample data' : 'Connected',
                    variant: synthetic
                        ? AppTagVariant.neutral
                        : AppTagVariant.accent,
                  ),
                ],
              ),
              if (synthetic) ...[
                const SizedBox(height: AppSpacing.space3),
                Text(
                  '$days days of a deterministic sample series. Readiness, '
                  'targets and every finding are computed from it for real — '
                  'but it is not your data.',
                  style: AppTextStyles.cardBody.copyWith(
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                AppButton(
                  label: 'Connect Apple Health',
                  block: true,
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await requestHealthAccess(ref);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Apple Health connection attempt completed.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.space3),
                Text(
                  '$days days read from your health store. Read-only; nothing '
                  'is written back, and none of it leaves this device.',
                  style: AppTextStyles.cardBody.copyWith(
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Gmail import
// ---------------------------------------------------------------------------

class _GmailSection extends StatelessWidget {
  const _GmailSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Gmail import'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: AppSpacing.space3,
                children: [
                  const _RowIcon(Icons.mail_outline),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mailbox access',
                          style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Not available in this build',
                          style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const AppTag(label: 'Off', variant: AppTagVariant.neutral),
                ],
              ),
              const SizedBox(height: AppSpacing.space3),
              Text(
                'The plan is read-only access, used to find lab reports from '
                'known diagnostics providers. It needs a Google Restricted-scope '
                'review and a server to exchange the token, neither of which '
                'this build has.',
                style: AppTextStyles.cardBody.copyWith(
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              AppButton(
                label: 'Why not?',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onPressed: () =>
                    MainShell.push(context, const GmailImportScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Reference ranges
// ---------------------------------------------------------------------------

class _ReferenceRangeSection extends ConsumerWidget {
  const _ReferenceRangeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sex = ref.watch(biologicalSexProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Reference ranges'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Several biomarkers — ferritin, haemoglobin, HDL, testosterone, '
                'ALT — have sex-specific reference intervals. This only affects '
                'how values are flagged.',
                style: AppTextStyles.cardBody.copyWith(
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              SegmentedControl<BiologicalSex>(
                options: const [
                  SegmentedOption(value: BiologicalSex.female, label: 'Female'),
                  SegmentedOption(value: BiologicalSex.male, label: 'Male'),
                  SegmentedOption(
                    value: BiologicalSex.unspecified,
                    label: 'Prefer not to say',
                  ),
                ],
                selected: sex,
                onChanged: (next) =>
                    ref.read(settingsProvider.notifier).setSex(next),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Analysis window
// ---------------------------------------------------------------------------

class _AnalysisWindowSection extends ConsumerWidget {
  const _AnalysisWindowSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(analysisWindowProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Analysis window'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How far back correlations look. Longer windows find weaker '
                'signals but respond more slowly to a change you have just made.',
                style: AppTextStyles.cardBody.copyWith(
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              SegmentedControl<AnalysisWindow>(
                options: [
                  for (final w in AnalysisWindow.values)
                    SegmentedOption(value: w, label: '${w.days} days'),
                ],
                selected: window,
                onChanged: (next) =>
                    ref.read(settingsProvider.notifier).setAnalysisWindow(next),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Which insights you see
// ---------------------------------------------------------------------------

class _RuleToggleSection extends ConsumerWidget {
  const _RuleToggleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(allRulesProvider);
    final muted = ref.watch(settingsProvider).mutedRuleIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Which insights you see'),
        SurfaceCard(
          padded: false,
          child: Column(
            children: [
              for (final rule in rules)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space5,
                    vertical: AppSpacing.space2,
                  ),
                  decoration: BoxDecoration(
                    border: rule == rules.last
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppColors.hairline),
                          ),
                  ),
                  child: Row(
                    spacing: AppSpacing.space3,
                    children: [
                      Expanded(
                        child: Text(
                          rule.name,
                          maxLines: 2,
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 14),
                        ),
                      ),
                      Switch.adaptive(
                        value: !muted.contains(rule.id),
                        activeTrackColor: AppColors.brand,
                        onChanged: (_) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(settingsProvider.notifier)
                              .toggleRule(rule.id);
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Demo data
// ---------------------------------------------------------------------------

class _DemoDataSection extends ConsumerWidget {
  const _DemoDataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(mealLogProvider);
    final seeded = log.meals.any((m) => m.source == MealSource.seed);
    final mealCount = log.meals.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Demo data'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: AppSpacing.space3,
                children: [
                  const _RowIcon(Icons.science_outlined),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demo persona',
                          style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${seeded ? 'Active' : 'Off'} · $mealCount meal'
                          '${mealCount == 1 ? '' : 's'} logged',
                          style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  AppTag(
                    label: seeded ? 'On' : 'Off',
                    variant: seeded
                        ? AppTagVariant.accent
                        : AppTagVariant.neutral,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space3),
              Text(
                'Loads a week of vegetarian-leaning meals and hydration, '
                'composed so the weekly pattern analysis has something real to '
                'find — added sugar clears its ceiling on four of the seven '
                'days. It overwrites the food log on this device.',
                style: AppTextStyles.cardBody.copyWith(
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: seeded ? 'Remove demo data' : 'Load demo persona',
                  variant: seeded
                      ? AppButtonVariant.danger
                      : AppButtonVariant.primary,
                  size: AppButtonSize.sm,
                  onPressed: () => seeded
                      ? ref.read(mealLogProvider.notifier).clear()
                      : ref.read(mealLogProvider.notifier).reseed(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 8. Your data
// ---------------------------------------------------------------------------

class _YourDataSection extends ConsumerWidget {
  const _YourDataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportCount = ref.watch(labsProvider).reports.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Your data'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.space3,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: AppColors.optimal,
                  ),
                  Expanded(
                    child: Text(
                      'Telemetry never leaves your device, and neither do your '
                      'lab results — there is no parsing service configured in '
                      'this build, so nothing is uploaded at all.',
                      style: AppTextStyles.cardBody.copyWith(
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.space4),
                padding: const EdgeInsets.only(top: AppSpacing.space4),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$reportCount lab report'
                      '${reportCount == 1 ? '' : 's'} stored on this device',
                      style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    AppButton(
                      label: 'Erase all local data',
                      variant: AppButtonVariant.danger,
                      size: AppButtonSize.sm,
                      leading: const Icon(Icons.delete_outline, size: 14),
                      onPressed: () => _confirmErase(context, ref),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmErase(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase all local data?'),
        content: const Text(
          'This deletes every stored lab report, your food log and your '
          'profile from this device. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Erase'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Heavier than any other press in the app, and deliberately so: this is the
    // one irreversible action, and the thump is the confirmation that it went
    // through on a screen where everything visibly resetting looks like a bug.
    HapticFeedback.heavyImpact();

    await ref.read(labsProvider.notifier).clear();
    await ref.read(mealLogProvider.notifier).clear();
    ref.read(settingsProvider.notifier).reset();
    ref.read(userProfileProvider.notifier).reset();
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space8,
        AppSpacing.space6,
        0,
      ),
      child: Text(
        'Agentrix Health 1.0.0 · Not a medical device',
        textAlign: TextAlign.center,
        style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
      ),
    );
  }
}
