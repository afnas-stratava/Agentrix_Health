/// The four phases of a 28-day menstrual cycle, with their day ranges
/// (inclusive, 1-indexed) as modeled by the design's demo data.
enum CyclePhaseType {
  menstrual(1, 5),
  follicular(6, 13),
  ovulatory(14, 16),
  luteal(17, 28);

  const CyclePhaseType(this.startDay, this.endDay);

  final int startDay;
  final int endDay;

  String get label => switch (this) {
    CyclePhaseType.menstrual => 'Menstrual',
    CyclePhaseType.follicular => 'Follicular',
    CyclePhaseType.ovulatory => 'Ovulatory',
    CyclePhaseType.luteal => 'Luteal',
  };

  static CyclePhaseType forDay(int day) {
    return CyclePhaseType.values.firstWhere(
      (p) => day >= p.startDay && day <= p.endDay,
      orElse: () => CyclePhaseType.luteal,
    );
  }
}
