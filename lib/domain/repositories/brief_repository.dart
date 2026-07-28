import '../entities/brief_line.dart';

abstract interface class BriefRepository {
  List<List<BriefLine>> briefVariants();

  /// Simulated latency for regenerating the morning brief.
  Future<void> simulateGeneration();
}
