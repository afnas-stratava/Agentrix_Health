import '../entities/prescriptions/prescription.dart';

/// Stored prescription history, newest first.
abstract class PrescriptionRepository {
  Future<List<Prescription>> loadPrescriptions();

  Future<void> savePrescriptions(List<Prescription> prescriptions);

  Future<void> clear();
}
