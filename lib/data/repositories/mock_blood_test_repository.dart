import '../../domain/entities/blood_marker.dart';
import '../../domain/entities/blood_test_record.dart';
import '../../domain/repositories/blood_test_repository.dart';

class MockBloodTestRepository implements BloodTestRepository {
  @override
  Future<List<BloodMarker>> fetchSampleReport() async {
    return const [
      BloodMarker(label: 'Iron', value: '45 µg/dL', status: MarkerStatus.low),
      BloodMarker(
        label: 'Vitamin B12',
        value: '520 pg/mL',
        status: MarkerStatus.normal,
      ),
      BloodMarker(
        label: 'Vitamin D',
        value: '22 ng/mL',
        status: MarkerStatus.low,
      ),
      BloodMarker(
        label: 'Glucose',
        value: '92 mg/dL',
        status: MarkerStatus.normal,
      ),
      BloodMarker(
        label: 'Cholesterol',
        value: '178 mg/dL',
        status: MarkerStatus.normal,
      ),
    ];
  }

  @override
  List<BloodTestRecord> history() {
    return const [
      BloodTestRecord(label: 'Full panel', date: 'Jul 20, 2026'),
      BloodTestRecord(label: 'Routine check', date: 'Apr 3, 2026'),
    ];
  }
}
