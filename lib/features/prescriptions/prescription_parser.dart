import '../../domain/entities/labs/lab_report.dart' show ParseStatus;
import '../../domain/entities/prescriptions/prescription.dart';

/// Turns an uploaded document into a parsed [Prescription].
/// Mirrors `lib/features/labs/lab_parser.dart` exactly — see that file for
/// why the local path exists and what it demonstrates.
abstract class PrescriptionParser {
  Future<Prescription> parse(PrescriptionUpload upload);
}

/// Standing disclosure attached to every locally-parsed prescription.
const String localPrescriptionParseDisclosure =
    'Extracted with an on-device fixture — no OCR service is configured in '
    'this build, so this is not yet read from your file.';

class LocalPrescriptionParser implements PrescriptionParser {
  const LocalPrescriptionParser({
    this.latency = const Duration(milliseconds: 1400),
  });

  /// Mimics OCR latency so the parsing state is exercised rather than skipped.
  final Duration latency;

  @override
  Future<Prescription> parse(PrescriptionUpload upload) async {
    await Future<void>.delayed(latency);

    final now = DateTime.now();
    final prescribed = now.subtract(const Duration(days: 2));

    return Prescription(
      id: 'rx-${now.microsecondsSinceEpoch}',
      source: upload.source,
      status: ParseStatus.ready,
      prescribedAt: DateTime(
        prescribed.year,
        prescribed.month,
        prescribed.day,
      ),
      uploadedAt: now,
      medications: const [
        Medication(
          name: 'Ferrous Sulfate',
          dosage: '325 mg',
          frequency: 'Once daily',
          route: 'Oral',
          duration: '90 days',
          instructions: 'Take with food to reduce stomach upset',
          confidence: 0.94,
        ),
        Medication(
          name: 'Vitamin D3',
          dosage: '2000 IU',
          frequency: 'Once daily',
          route: 'Oral',
          duration: 'Ongoing',
          confidence: 0.94,
        ),
      ],
      prescriberName: 'Dr. A. Rao',
      clinicName: 'Meridian Family Clinic',
      fileName: upload.name,
      fileSizeBytes: upload.sizeBytes,
      warnings: [
        localPrescriptionParseDisclosure,
        if (upload.source == PrescriptionSource.image)
          'Photographed prescriptions are the least reliable input — confirm '
              'every dose against the original before acting on it.',
      ],
    );
  }
}
