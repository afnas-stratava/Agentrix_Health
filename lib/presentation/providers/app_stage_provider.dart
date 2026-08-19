import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_endpoints.dart';
import 'auth_providers.dart';

/// Whether onboarding was already finished on this device, resolved in
/// `main()` *before* `runApp()` and overridden via `ProviderScope(overrides:
/// [...])`. [AppStageNotifier.build] reads it synchronously, so the first
/// frame is already correct — Riverpod's
/// `build()` cannot itself await the SharedPreferences read that would
/// otherwise be needed, and the natural fallback (start at `welcome`, flip to
/// `main` a moment later) draws one real frame of onboarding before flipping,
/// which is the flash a user actually sees as "onboarding showing again".
final onboardingCompleteAtLaunchProvider = Provider<bool>((ref) => false);

/// Shared with `main.dart`, which reads this key directly before `runApp()`
/// — a single source of truth so the write side (`AppStageNotifier`) and the
/// pre-launch read can never drift onto different key strings.
const String onboardingCompleteKey = 'onboarding_complete.v1';

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

class AppStageNotifier extends Notifier<AppStage> {
  /// Starts at [AppStage.main] when either `SKIP_ONBOARDING` is set or
  /// onboarding was already finished on this device in a previous launch —
  /// both known synchronously by the time this runs, so there is no flash of
  /// `welcome` to correct a moment later.
  ///
  /// To jump straight to the main app while working on a tab, run with
  /// `--dart-define=SKIP_ONBOARDING=true` rather than editing this default —
  /// hardcoding `main` here silently ships an app with no onboarding, and takes
  /// the onboarding widget tests down with it.
  @override
  AppStage build() {
    final done = _skipOnboarding || ref.read(onboardingCompleteAtLaunchProvider);
    return done ? AppStage.main : AppStage.welcome;
  }

  static const bool _skipOnboarding = bool.fromEnvironment('SKIP_ONBOARDING');

  void go(AppStage stage) => state = stage;
  void next() => state = state.next;
  void back() => state = state.previous;

  /// Also clears the "onboarding finished" flag: every caller of this —
  /// sign out, delete account, demo reset — is a deliberate reset, and the
  /// next launch should be able to show onboarding again rather than
  /// skipping past it on a profile that no longer exists.
  Future<void> goWelcome() async {
    state = AppStage.welcome;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(onboardingCompleteKey);
    } catch (error) {
      debugPrint('AppStageNotifier: could not clear onboarding flag: $error');
    }
  }

  /// Marks onboarding finished, so the next launch skips straight past it.
  Future<void> goMain() async {
    state = AppStage.main;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(onboardingCompleteKey, true);
    } catch (error) {
      debugPrint('AppStageNotifier: could not save onboarding flag: $error');
    }
    unawaited(_syncOnboardingComplete());
  }

  /// Write-behind backup of the local flag above to the FastAPI backend
  /// (`PATCH /users/me/onboarding-complete`) — read back on a later
  /// `/auth/google` so a reinstall or a second device also skips onboarding
  /// for this account. Best-effort like the other onboarding syncs: a flaky
  /// connection here must not block reaching the main app.
  Future<void> _syncOnboardingComplete() async {
    final idToken = ref.read(googleIdTokenProvider);
    if (idToken == null) return;

    try {
      await http
          .patch(
            ApiEndpoints.markOnboardingComplete,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Could not sync onboarding-complete to backend: $error');
    }
  }
}

final appStageProvider = NotifierProvider<AppStageNotifier, AppStage>(
  AppStageNotifier.new,
);
