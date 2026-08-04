import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_info.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../domain/entities/nutrition/meal_entry.dart';
import '../../../data/auth/social_sign_in.dart';
import '../../../features/correlation/engine_context.dart';
import '../../providers/account_provider.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/health_providers.dart';
import '../../providers/insights_providers.dart';
import '../../providers/labs_providers.dart';
import '../../providers/nutrition_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/auth/sign_in_buttons.dart';
import 'about_screen.dart';
import 'gmail_import_screen.dart';
import 'main_shell.dart';
import 'profile_edit_screen.dart';

/// Settings. Mirrors `app/(tabs)/settings.tsx`.
///
/// RN's order — profile, Apple Health, Gmail, reference ranges, analysis
/// window, which insights you see, demo data, your data — then two sections
/// with no RN counterpart: About and support, and Account. Both sit at the
/// bottom, About because it is reference material rather than a setting and
/// Account because sign out and delete belong last.
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
          _AboutSection(),
          _AccountSection(),
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
  const _RowIcon(this.icon, {this.photoUrl});

  final IconData icon;

  /// From the sign-in provider. Falls back to [icon] when absent, or when the
  /// URL fails to load (Google photos require an active session to fetch).
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      clipBehavior: url == null ? Clip.none : Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.brand50,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: url == null
          ? Icon(icon, size: 20, color: AppColors.brand)
          : Image.network(
              url,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(icon, size: 20, color: AppColors.brand),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// 9. Account
// ---------------------------------------------------------------------------

/// Sign in, sign out, delete.
///
/// Sits at the bottom because sign out and delete account are destructive,
/// rarely-used actions — they belong last, after every other setting.
class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(accountStatusProvider);
    final busy = ref.watch(accountControllerProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Account'),
        SurfaceCard(
          padded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.space5),
                child: status.isAccount
                    ? _SignedIn(status: status)
                    : const _SignedOut(),
              ),
              if (status.isAccount)
                _CardFooter(
                  child: Row(
                    spacing: AppSpacing.space2,
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Sign out',
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.sm,
                          block: true,
                          onPressed: busy
                              ? null
                              : () => _confirmSignOut(context, ref),
                        ),
                      ),
                      Expanded(
                        child: AppButton(
                          label: 'Delete account',
                          variant: AppButtonVariant.danger,
                          size: AppButtonSize.sm,
                          block: true,
                          onPressed: busy
                              ? null
                              : () => _confirmDelete(context, ref),
                        ),
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

  /// Sign-in is mandatory, so signing out cannot leave the user sitting in the
  /// app — it returns them to the gate. The controller has already put the
  /// session back on an anonymous uid by then, which is what the gate blocks
  /// on.
  ///
  /// Confirmed rather than immediate: the button sits next to Delete account,
  /// and a mis-tap now costs the whole app until the user signs back in.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to use the app. Nothing is deleted '
          '— your profile and history come back when you do.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(accountControllerProvider.notifier).signOut();
    ref.read(appStageProvider.notifier).go(AppStage.account);
  }

  /// Deleting the account removes the cloud copy *and* everything local — a
  /// user who asks to be deleted does not mean "except the food log".
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your account and everything stored with '
          'it, on this device and in the cloud. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    HapticFeedback.heavyImpact();

    // Firebase demands a fresh sign-in before it will delete a user, so the
    // provider sheet may reappear mid-flow. Deciding *which* provider to
    // re-run is the UI's job — the controller only knows it needs one.
    final providerIds = ref.read(accountStatusProvider).providerIds;
    final deleted = await ref
        .read(accountControllerProvider.notifier)
        .deleteAccount(
          reauthenticate: () async {
            final social = ref.read(socialSignInProvider);
            try {
              return providerIds.contains('apple.com')
                  ? await social.apple()
                  : await social.google();
            } on SignInCancelled {
              // Backing out of the re-auth sheet cancels the deletion, which
              // is not an error worth a red banner.
              return null;
            }
          },
        );

    // Only wipe the device once the account is actually gone: a dismissed
    // re-auth sheet must leave the user exactly as they were.
    if (!deleted) return;

    await ref.read(labsProvider.notifier).clear();
    await ref.read(mealLogProvider.notifier).clear();
    ref.read(settingsProvider.notifier).reset();
    ref.read(userProfileProvider.notifier).reset();

    // Nothing of theirs is left, so the app returns to its first-run state
    // rather than showing an empty shell behind a locked gate.
    ref.read(appStageProvider.notifier).goWelcome();
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.status});

  final AccountStatus status;

  @override
  Widget build(BuildContext context) {
    final via = status.providerIds
        .map(
          (id) => switch (id) {
            'apple.com' => 'Apple',
            'google.com' => 'Google',
            _ => null,
          },
        )
        .whereType<String>()
        .join(' and ');

    return Row(
      spacing: AppSpacing.space3,
      children: [
        _RowIcon(Icons.person_outline, photoUrl: status.photoUrl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.label,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                via.isEmpty ? 'Signed in' : 'Signed in with $via',
                style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'This device only',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Your health profile is stored against your account and comes back '
          'on a new phone. Your food log and lab reports stay on this one.',
          style: AppTextStyles.cardBody.copyWith(fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.space4),
        const SignInButtons(),
      ],
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
                      _RowIcon(Icons.person_outline, photoUrl: profile.photoUrl),
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
                  '$days days read from your health store. Read-only — '
                  'nothing is ever written back. Your raw readings stay on '
                  'this device; only a short readiness summary goes out, and '
                  'only when you ask the assistant a question.',
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
                      'Your Apple Health readings, food log and stored reports '
                      'live on this device. Google Gemini sees three things: a '
                      'lab report when you upload one, a meal photo when you '
                      'take one, and a summary of your data with each question '
                      'you ask the assistant. Nothing is sold, advertised '
                      'against, or used to train anyone’s models.',
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

    // Nothing of theirs is left, so the app returns to its first-run state
    // rather than showing an empty shell behind a locked gate.
    ref.read(appStageProvider.notifier).goWelcome();
  }
}

// ---------------------------------------------------------------------------
// 9. About and support
// ---------------------------------------------------------------------------

/// The rows every app is expected to carry: what this is, the two legal
/// documents, a way to reach a human, and the licences of what it is built on.
///
/// Privacy policy is not filler here — App Review requires a reachable one for
/// anything touching HealthKit, and it has to be linked from inside the app as
/// well as from App Store Connect.
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('About and support'),
        SurfaceCard(
          padded: false,
          child: Column(
            children: [
              _AboutRow(
                icon: Icons.info_outline,
                title: 'About ${AppInfo.appName}',
                subtitle: 'Version ${AppInfo.version} · what leaves your device',
                onTap: () => MainShell.push(context, const AboutScreen()),
              ),
              _AboutRow(
                icon: Icons.shield_outlined,
                title: 'Privacy policy',
                subtitle: 'How your health data is handled',
                onTap: () =>
                    _open(context, Uri.parse(AppInfo.privacyPolicyUrl)),
                external: true,
              ),
              _AboutRow(
                icon: Icons.gavel_outlined,
                title: 'Terms of service',
                subtitle: 'The agreement you are using this under',
                onTap: () => _open(context, Uri.parse(AppInfo.termsUrl)),
                external: true,
              ),
              _AboutRow(
                icon: Icons.mail_outline,
                title: 'Contact us',
                subtitle: AppInfo.supportEmail,
                onTap: () => _open(
                  context,
                  AppInfo.supportMailto(platform: _platformName),
                ),
                external: true,
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String get _platformName {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    return Platform.operatingSystem;
  }

  /// Reports a failed open instead of doing nothing. The likeliest cause is a
  /// placeholder URL in [AppInfo] that was never pointed at a real page, and
  /// that should be loud rather than silent.
  static Future<void> _open(BuildContext context, Uri uri) async {
    HapticFeedback.selectionClick();
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open ${uri.host.isEmpty ? uri : uri.host}'),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.external = false,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Leaves the app, so it gets the outward arrow rather than the chevron
  /// that means "another screen in here".
  final bool external;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scaleTo: 0.99,
      semanticLabel: title,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space5,
          vertical: AppSpacing.space4,
        ),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          spacing: AppSpacing.space3,
          children: [
            _RowIcon(icon),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              external ? Icons.open_in_new : Icons.chevron_right,
              size: external ? 15 : 17,
              color: AppColors.faint,
            ),
          ],
        ),
      ),
    );
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
        '${AppInfo.appName} ${AppInfo.version} · Not a medical device',
        textAlign: TextAlign.center,
        style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
      ),
    );
  }
}
