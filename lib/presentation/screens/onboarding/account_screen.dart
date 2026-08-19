import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/surface_card.dart';
import '../../providers/account_provider.dart';
import '../../providers/app_stage_provider.dart';
import '../../widgets/auth/sign_in_buttons.dart';
import 'onboarding_scaffold.dart';

/// The account step, between the welcome pitch and the profile questions.
///
/// **Mandatory.** There is no way past it without an account, so it is placed
/// before the profile questions rather than after: a wall at the end would
/// throw away everything the user had already typed.
///
/// Note what this means for a build whose Firebase project is not finished —
/// see `docs/AUTH_SETUP.md`. With no providers enabled, nobody reaches the app
/// at all. `--dart-define=SKIP_ONBOARDING=true` remains the way past it while
/// working on other screens.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(accountStatusProvider);
    final stage = ref.read(appStageProvider.notifier);
    final next = stage.next;

    // A registered account that already finished onboarding — elsewhere, or
    // on an earlier install here — skips straight to the main app instead of
    // re-asking everything it already has an answer for.
    void afterSignIn(bool onboardingComplete) =>
        onboardingComplete ? stage.goMain() : next();

    if (status.isAccount) {
      return OnboardingScaffold(
        title: 'You’re signed in',
        intro:
            'Your health profile will follow you to a new phone. You can sign '
            'out any time from Settings.',
        onContinue: next,
        children: [_SignedInCard(label: status.label)],
      );
    }

    return OnboardingScaffold(
      title: 'Sign in to continue',
      intro:
          'Your health profile is stored against your account, so it comes '
          'back on a new phone. It takes one tap — there is no password to '
          'choose.',
      // Continue exists but stays locked, rather than being absent: a footer
      // that appears out of nowhere once you sign in reads as a glitch, and a
      // disabled button with a stated reason is the clearer signal.
      canContinue: false,
      blockedHint: 'Choose a sign-in method above to continue.',
      children: [
        SignInButtons(onSignedIn: afterSignIn),
        const SizedBox(height: AppSpacing.space6),
        const _PrivacyNote(),
      ],
    );
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        spacing: AppSpacing.space3,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 20,
              color: AppColors.brand,
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.space3,
      children: [
        const Icon(Icons.lock_outline, size: 16, color: AppColors.brand),
        Expanded(
          child: Text(
            'Signing in stores your health profile, name and email against '
            'your account. Your telemetry, food log and lab reports stay on '
            'this device.',
            style: AppTextStyles.cardBody.copyWith(fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }
}
