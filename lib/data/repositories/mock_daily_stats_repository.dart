import '../../domain/entities/daily_stats.dart';
import '../../domain/repositories/daily_stats_repository.dart';

class MockDailyStatsRepository implements DailyStatsRepository {
  @override
  DailyStats current() =>
      const DailyStats(steps: 7240, sleepHours: 6.5, caloriesBurned: 420);
}
