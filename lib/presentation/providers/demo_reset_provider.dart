import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_stage_provider.dart';
import 'blood_test_provider.dart';
import 'brief_provider.dart';
import 'cycle_view_provider.dart';
import 'health_apps_provider.dart';
import 'main_tab_provider.dart';
import 'meals_provider.dart';
import 'notification_time_provider.dart';
import 'user_profile_provider.dart';

/// Resets every piece of demo state back to its initial value and returns
/// to the welcome screen, matching the design's "Reset demo" action.
void resetDemo(WidgetRef ref) {
  ref.read(userProfileProvider.notifier).reset();
  ref.read(bloodTestProvider.notifier).reset();
  ref.read(healthAppsProvider.notifier).reset();
  ref.read(mealsProvider.notifier).reset();
  ref.read(briefProvider.notifier).reset();
  ref.read(mainTabProvider.notifier).reset();
  ref.read(notificationTimeIndexProvider.notifier).reset();
  ref.read(cycleViewProvider.notifier).reset();
  ref.read(appStageProvider.notifier).goWelcome();
}
