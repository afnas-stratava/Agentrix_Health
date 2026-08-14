import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_blood_test_repository.dart';
import '../../data/repositories/mock_brief_repository.dart';
import '../../data/repositories/mock_cycle_repository.dart';
import '../../data/repositories/mock_daily_stats_repository.dart';
import '../../data/repositories/mock_health_app_repository.dart';
import '../../data/repositories/mock_meal_repository.dart';
import '../../data/repositories/prefs_user_profile_repository.dart';
import '../../domain/repositories/blood_test_repository.dart';
import '../../domain/repositories/brief_repository.dart';
import '../../domain/repositories/cycle_repository.dart';
import '../../domain/repositories/daily_stats_repository.dart';
import '../../domain/repositories/health_app_repository.dart';
import '../../domain/repositories/meal_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';

// Wires domain repository interfaces to their (mock) data implementations.
// Swap the implementation passed here to move off mock data later without
// touching any presentation code.

final bloodTestRepositoryProvider = Provider<BloodTestRepository>(
  (ref) => MockBloodTestRepository(),
);

final healthAppRepositoryProvider = Provider<HealthAppRepository>(
  (ref) => MockHealthAppRepository(),
);

final mealRepositoryProvider = Provider<MealRepository>(
  (ref) => MockMealRepository(),
);

final briefRepositoryProvider = Provider<BriefRepository>(
  (ref) => MockBriefRepository(),
);

final cycleRepositoryProvider = Provider<CycleRepository>(
  (ref) => MockCycleRepository(),
);

final dailyStatsRepositoryProvider = Provider<DailyStatsRepository>(
  (ref) => MockDailyStatsRepository(),
);

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => PrefsUserProfileRepository(),
);
