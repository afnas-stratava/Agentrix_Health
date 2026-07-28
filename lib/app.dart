import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_shadows.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/app_stage_provider.dart';
import 'presentation/screens/main/main_shell.dart';
import 'presentation/screens/onboarding/blood_test_screen.dart';
import 'presentation/screens/onboarding/health_connect_screen.dart';
import 'presentation/screens/onboarding/personal_info_screen.dart';
import 'presentation/screens/onboarding/welcome_screen.dart';

class AgentrixHealthApp extends StatelessWidget {
  const AgentrixHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agentrix Health',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _ResponsiveRoot(child: _AppStageSwitcher()),
    );
  }
}

/// On a real phone (or a narrow web window) the device itself is already
/// the "frame" — the app fills the screen edge-to-edge like any native app.
/// The rounded/bordered phone-card mockup only makes sense on a wide
/// desktop/web viewport, where it stands in for the device chrome that
/// isn't there.
class _ResponsiveRoot extends StatelessWidget {
  const _ResponsiveRoot({required this.child});

  final Widget child;

  static const _compactBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _compactBreakpoint) {
          return ColoredBox(
            color: AppColors.bg,
            child: Material(type: MaterialType.transparency, child: child),
          );
        }
        return _PhoneFrame(child: child);
      },
    );
  }
}

/// Frames the app in the mobile-card viewport from the source design so the
/// experience reads the same on a wide desktop/web window as it does on a
/// phone.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.neutral200,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 428, minHeight: 860),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border.all(color: AppColors.accent700, width: 2),
                borderRadius: BorderRadius.circular(32),
                boxShadow: AppShadows.lg,
              ),
              child: SizedBox(
                height: 860,
                child: Material(type: MaterialType.transparency, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppStageSwitcher extends ConsumerWidget {
  const _AppStageSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(appStageProvider);

    return switch (stage) {
      AppStage.welcome => const WelcomeScreen(),
      AppStage.form => const PersonalInfoScreen(),
      AppStage.bloodTest => const BloodTestScreen(),
      AppStage.healthConnect => const HealthConnectScreen(),
      AppStage.main => const MainShell(),
    };
  }
}
