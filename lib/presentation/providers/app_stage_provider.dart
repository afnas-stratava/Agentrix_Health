import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top-level app flow: the four onboarding steps, then the main tabbed app.
enum AppStage { welcome, form, bloodTest, healthConnect, main }

class AppStageNotifier extends Notifier<AppStage> {
  @override
  AppStage build() => AppStage.welcome;

  void goWelcome() => state = AppStage.welcome;
  void goForm() => state = AppStage.form;
  void goBloodTest() => state = AppStage.bloodTest;
  void goHealthConnect() => state = AppStage.healthConnect;
  void goMain() => state = AppStage.main;
}

final appStageProvider = NotifierProvider<AppStageNotifier, AppStage>(
  AppStageNotifier.new,
);
