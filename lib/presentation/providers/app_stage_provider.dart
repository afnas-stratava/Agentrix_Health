import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top-level app flow: the four onboarding steps, then the main tabbed app.
enum AppStage { welcome, form, bloodTest, healthConnect, main }

class AppStageNotifier extends Notifier<AppStage> {
  /// Starts at [AppStage.welcome].
  ///
  /// To jump straight to the main app while working on a tab, run with
  /// `--dart-define=SKIP_ONBOARDING=true` rather than editing this default —
  /// hardcoding `main` here silently ships an app with no onboarding, and takes
  /// the onboarding widget tests down with it.
  @override
  AppStage build() => _skipOnboarding ? AppStage.main : AppStage.welcome;

  static const bool _skipOnboarding = bool.fromEnvironment('SKIP_ONBOARDING');

  void goWelcome() => state = AppStage.welcome;
  void goForm() => state = AppStage.form;
  void goBloodTest() => state = AppStage.bloodTest;
  void goHealthConnect() => state = AppStage.healthConnect;
  void goMain() => state = AppStage.main;
}

final appStageProvider = NotifierProvider<AppStageNotifier, AppStage>(
  AppStageNotifier.new,
);
