import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/auth/social_sign_in.dart';
import '../../providers/account_provider.dart';

/// The Apple and Google buttons, plus whatever went wrong last time.
///
/// One widget for both call sites — onboarding and Settings — because the
/// provider list, the button order and the error copy have to agree, and Apple
/// is picky enough about its button's appearance that having two versions of it
/// is a review risk.
class SignInButtons extends ConsumerWidget {
  const SignInButtons({super.key, this.onSignedIn});

  /// Called only on a successful sign-in — not on cancel, not on failure.
  /// `onboardingComplete` says whether *this* account already finished
  /// onboarding elsewhere, for callers (the onboarding account step) that
  /// need to skip re-running it.
  final void Function(bool onboardingComplete)? onSignedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountControllerProvider);
    final busy = state.isLoading;

    Future<void> run(SocialProvider provider) async {
      final result = await ref
          .read(accountControllerProvider.notifier)
          .signIn(provider);
      if (result.success) onSignedIn?.call(result.onboardingComplete);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (SocialSignIn.supportsApple) ...[
          // Apple's guidelines want its button at least as prominent as the
          // alternatives, in Apple's own black-on-white or white-on-black.
          AppButton(
            label: 'Continue with Apple',
            size: AppButtonSize.lg,
            block: true,
            backgroundColor: AppColors.ink,
            foregroundColor: AppColors.onBrand,
            borderColor: AppColors.ink,
            leading: const Icon(
              Icons.apple,
              size: 18,
              color: AppColors.onBrand,
            ),
            onPressed: busy ? null : () => run(SocialProvider.apple),
          ),
          const SizedBox(height: AppSpacing.space3),
        ],

        AppButton(
          label: 'Continue with Google',
          size: AppButtonSize.lg,
          block: true,
          variant: AppButtonVariant.secondary,
          leading: const _GoogleMark(),
          onPressed: busy ? null : () => run(SocialProvider.google),
        ),

        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.space4),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brand,
                ),
              ),
            ),
          ),

        if (state.hasError)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.space2,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 15,
                  color: AppColors.critical,
                ),
                Expanded(
                  child: Text(
                    describeAuthError(state.error!),
                    style: AppTextStyles.cardBody.copyWith(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.critical,
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

/// Google's mark, drawn rather than bundled as an asset — four arcs of the
/// wordmark's palette is less to maintain than a PNG set at three densities.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.28;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    void arc(double startDeg, double sweepDeg, Color colour) {
      const rad = 3.1415926535 / 180;
      canvas.drawArc(
        rect,
        startDeg * rad,
        sweepDeg * rad,
        false,
        paint..color = colour,
      );
    }

    arc(-20, 70, _red);
    arc(50, 90, _yellow);
    arc(140, 90, _green);
    arc(230, 90, _blue);

    // The bar into the centre that makes the ring read as a G.
    canvas.drawLine(
      Offset(size.width * 0.52, size.height / 2),
      Offset(size.width - stroke / 2, size.height / 2),
      Paint()
        ..color = _blue
        ..strokeWidth = stroke * 0.9,
    );
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}
