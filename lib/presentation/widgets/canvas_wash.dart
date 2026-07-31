import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The Today screen's background from `app/(tabs)/today.tsx`: a soft green
/// wash top-to-bottom plus two very diffuse blooms. On a light canvas these
/// read as ambient light rather than as the hard vignettes a dark theme needs.
///
/// **Today only.** Every other screen in the React Native app is a plain
/// `bg-canvas` — this used to wrap the whole shell, which put a green gradient
/// behind Food, Insights, Labs and Settings that RN does not have.
class CanvasWash extends StatelessWidget {
  const CanvasWash({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE4F4DA), Color(0xFFF4FAF1), Color(0xFFFBFDF9)],
          stops: [0, 0.45, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -width * 0.55,
            left: -width * 0.25,
            child: _Bloom(size: width * 1.3, color: const Color(0xFFCDEBB8), opacity: 0.35),
          ),
          Positioned(
            bottom: -width * 0.5,
            right: -width * 0.35,
            child: _Bloom(size: width * 1.1, color: const Color(0xFFDCF3C9), opacity: 0.3),
          ),
          child,
        ],
      ),
    );
  }
}

/// The welcome screen's background from `app/onboarding/index.tsx`: a flat
/// canvas with a single bloom off the top-right corner — no gradient.
class WelcomeWash extends StatelessWidget {
  const WelcomeWash({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return ColoredBox(
      color: AppColors.canvas,
      child: Stack(
        children: [
          Positioned(
            top: -width * 0.5,
            right: -width * 0.3,
            child: _Bloom(
              size: width * 1.3,
              color: const Color(0xFFCDEBB8),
              opacity: 0.35,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
