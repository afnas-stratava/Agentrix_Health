import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MainTab {
  home,
  log,
  brief,
  cycle,
  profile;

  String get title => switch (this) {
    MainTab.home => 'Home',
    MainTab.log => 'Food log',
    MainTab.brief => 'Morning brief',
    MainTab.cycle => 'Cycle & wellness',
    MainTab.profile => 'Profile',
  };
}

class MainTabNotifier extends Notifier<MainTab> {
  @override
  MainTab build() => MainTab.home;

  void select(MainTab tab) => state = tab;
  void reset() => state = MainTab.home;
}

final mainTabProvider = NotifierProvider<MainTabNotifier, MainTab>(
  MainTabNotifier.new,
);
