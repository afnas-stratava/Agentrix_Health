import '../entities/daily_stats.dart';

abstract interface class DailyStatsRepository {
  DailyStats current();
}
