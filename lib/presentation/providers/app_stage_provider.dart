import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top-level app flow. Mirrors `app/onboarding/_layout.tsx` plus the tab shell.
///
/// Forward-only: each step's Continue is the only way on, and Back is an
/// explicit control rather than a gesture, so a half-configured profile cannot
/// be left behind by a swipe.
///
/// Note there is no blood-test step. RN collects blood work from the Labs tab
/// after onboarding, because a first-run flow that asks for a PDF is a first-run
/// flow most people abandon.
enum AppStage {
  welcome,
  account,
  sex,
  body,
  goals,
  diet,
  permissions,
  main;

  /// The step after this one. `main` is terminal.
  AppStage get next => switch (this) {
    AppStage.welcome => AppStage.account,
    AppStage.account => AppStage.sex,
    AppStage.sex => AppStage.body,
    AppStage.body => AppStage.goals,
    AppStage.goals => AppStage.diet,
    AppStage.diet => AppStage.permissions,
    AppStage.permissions || AppStage.main => AppStage.main,
  };

  /// The step before this one. `welcome` is the first.
  AppStage get previous => switch (this) {
    AppStage.welcome || AppStage.account => AppStage.welcome,
    AppStage.sex => AppStage.account,
    AppStage.body => AppStage.sex,
    AppStage.goals => AppStage.body,
    AppStage.diet => AppStage.goals,
    AppStage.permissions => AppStage.diet,
    AppStage.main => AppStage.permissions,
  };
}

/// The stage to land on at cold start. Defaults to [AppStage.welcome]; `main.dart`
/// overrides this once, before `runApp`, when Firebase Auth's persisted session
/// already belongs to a real (non-anonymous) account — that user signed in
/// once and should not see onboarding again on every relaunch, only after an
/// explicit sign-out.
final initialAppStageProvider = Provider<AppStage>(
  (ref) => AppStageNotifier._skipOnboarding ? AppStage.main : AppStage.welcome,
);

class AppStageNotifier extends Notifier<AppStage> {
  /// Starts at [initialAppStageProvider].
  ///
  /// To jump straight to the main app while working on a tab, run with
  /// `--dart-define=SKIP_ONBOARDING=true` rather than editing this default —
  /// hardcoding `main` here silently ships an app with no onboarding, and takes
  /// the onboarding widget tests down with it.
  @override
  AppStage build() => ref.read(initialAppStageProvider);

  static const bool _skipOnboarding = bool.fromEnvironment('SKIP_ONBOARDING');

  void go(AppStage stage) => state = stage;
  void next() => state = state.next;
  void back() => state = state.previous;

  void goWelcome() => state = AppStage.welcome;
  void goMain() => state = AppStage.main;
}

final appStageProvider = NotifierProvider<AppStageNotifier, AppStage>(
  AppStageNotifier.new,
);
