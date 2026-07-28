import '../entities/blood_marker.dart';
import '../entities/blood_test_record.dart';

abstract interface class BloodTestRepository {
  Future<List<BloodMarker>> fetchSampleReport();
  List<BloodTestRecord> history();
}
