import '../entities/labs/lab_report.dart';

/// Stored blood-test history, newest first.
abstract class LabRepository {
  Future<List<LabReport>> loadReports();

  Future<void> saveReports(List<LabReport> reports);

  Future<void> clear();
}
