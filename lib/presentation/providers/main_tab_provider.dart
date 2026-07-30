import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tab routes, mirroring `app/(tabs)/_layout.tsx` one-for-one.
///
/// Five routes, four of which get a slot in the bar. `settings` stays a route so
/// it resolves from anywhere, but is deliberately absent from the bar: five
/// icons plus the centre action reads as cramped, and settings already has a
/// permanent home in the Today header.
///
/// Everything else in the React Native app — the brief, dining, the cycle
/// tracker, a lab report, a metric detail — is a *pushed* route there, and is
/// pushed here too. A destination you back out of should not be a tab.
enum MainTab {
  today,
  food,
  insights,
  labs,
  settings;

  String get title => switch (this) {
    MainTab.today => 'Today',
    MainTab.food => 'Food',
    MainTab.insights => 'Insights',
    MainTab.labs => 'Labs',
    MainTab.settings => 'Settings',
  };
}

class MainTabNotifier extends Notifier<MainTab> {
  @override
  MainTab build() => MainTab.today;

  void select(MainTab tab) => state = tab;
  void reset() => state = MainTab.today;
}

final mainTabProvider = NotifierProvider<MainTabNotifier, MainTab>(
  MainTabNotifier.new,
);
