import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Back affordance that disappears when there is nothing to go back to.
///
/// The same screen can be reached two ways — pushed on top of the shell, or
/// shown in place as a tab — and `Navigator.canPop` is what tells them apart.
/// Rendering nothing in the tab case keeps one widget tree working for both
/// instead of forking the screen.
class ScreenBackButton extends StatelessWidget {
  const ScreenBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.canPop(context)) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.space3),
      child: AppButton.icon(
        leading: const Icon(Icons.arrow_back),
        backgroundColor: AppColors.surface,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }
}
