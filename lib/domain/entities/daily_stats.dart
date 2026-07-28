class DailyStats {
  const DailyStats({
    required this.steps,
    required this.sleepHours,
    required this.caloriesBurned,
  });

  final int steps;
  final double sleepHours;
  final int caloriesBurned;

  String get stepsLabel => steps.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  String get sleepLabel => '${sleepHours}h';
  String get burnedLabel => caloriesBurned.toString();
}
