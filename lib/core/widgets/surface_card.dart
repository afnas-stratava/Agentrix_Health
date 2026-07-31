import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Mirrors `src/components/ui/Card.tsx`.
///
/// One card for the whole app. Several screens had grown a private `_Card` each,
/// and they had drifted: 16px padding instead of RN's 20, and no shadow at all,
/// which is most of why the Flutter build read flatter and tighter than the
/// React Native original.
enum SurfaceCardTone {
  /// The default white card on the near-white canvas.
  light,

  /// A quieter, tinted grouping for secondary content.
  translucent,

  /// Reserved for the single highest-priority item on a screen.
  accent,
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.tone = SurfaceCardTone.light,
    this.padded = true,
    this.elevated = true,
  });

  final Widget child;
  final SurfaceCardTone tone;
  final bool padded;

  /// Set false for nested cards, where a second shadow reads as muddy.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final translucent = tone == SurfaceCardTone.translucent;

    return Container(
      width: double.infinity,
      padding: padded ? const EdgeInsets.all(AppSpacing.space5) : null,
      decoration: BoxDecoration(
        color: switch (tone) {
          SurfaceCardTone.light => AppColors.surface,
          SurfaceCardTone.translucent =>
            AppColors.brand50.withValues(alpha: 0.6),
          SurfaceCardTone.accent => AppColors.lime,
        },
        border: tone == SurfaceCardTone.accent
            ? null
            : Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
        // Separation on a light canvas comes from a soft lift rather than from
        // contrast; the hairline carries the edge when shadows are reduced.
        boxShadow: elevated && !translucent ? AppShadows.sm : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
