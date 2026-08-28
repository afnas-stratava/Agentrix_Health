import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/health/metric_key.dart';
import '../providers/main_tab_provider.dart';
import '../screens/main/main_shell.dart';
import '../screens/main/metric_detail_screen.dart';
import '../screens/main/voice_screen.dart';

/// Lets code with no [BuildContext] of its own — the voice tool dispatcher in
/// `voice_providers.dart`, which runs inside a [Notifier] — drive the same
/// navigation the rest of the app uses. Not a second routing system: this
/// wraps the existing [MainShell.push]/[mainTabProvider] pair behind a
/// [GlobalKey], the standard Flutter pattern for context-free navigation.
abstract final class AppNavigator {
  /// Attached to `MaterialApp.navigatorKey` in `app.dart`.
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static BuildContext? get _context => key.currentContext;

  /// Pops back to the tab shell — a voice command arriving while a pushed
  /// screen is showing (the call screen itself, a metric detail, Settings)
  /// should land on the tab, not stack a second route on top of the first —
  /// then selects [tab].
  ///
  /// Returns false with nothing changed if there is no attached
  /// [BuildContext] yet (the app is still on its first frame), so the caller
  /// can report a failed tool call instead of navigating into thin air.
  static bool goToTab(Ref ref, MainTab tab) {
    final context = _context;
    if (context == null) return false;
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.read(mainTabProvider.notifier).select(tab);
    return true;
  }

  /// Pops back to the tab shell, then pushes [metric]'s detail screen —
  /// there is no dedicated screen per metric; this is what a metric's own
  /// card already opens from Home.
  static bool openMetric(MetricKey metric) {
    final context = _context;
    if (context == null) return false;
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainShell.push(context, MetricDetailScreen(metric: metric));
    return true;
  }

  /// Pops back to the tab shell, then pushes the voice screen — used by the
  /// global floating voice control (`global_voice_button.dart`), which lives
  /// outside the app's `Navigator` (mounted via `MaterialApp.builder`) so it
  /// can float above every screen, and so needs this same context-free path
  /// rather than a `BuildContext` of its own.
  static bool openVoiceScreen() {
    final context = _context;
    if (context == null) return false;
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainShell.push(context, const VoiceScreen());
    return true;
  }

  /// Pops one route, if there is one to pop — the live call screen itself
  /// counts, so "go back" while looking at it just closes that screen
  /// without ending the call underneath it.
  static bool goBack() {
    final state = key.currentState;
    if (state == null || !state.canPop()) return false;
    state.pop();
    return true;
  }
}
