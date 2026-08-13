import 'package:agentrix_health/core/config/secrets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prescriptions/gemini_prescription_parser.dart';
import '../../data/repositories/prefs_prescription_repository.dart';
import '../../domain/entities/prescriptions/prescription.dart';
import '../../domain/repositories/prescription_repository.dart';
import '../../features/prescriptions/prescription_parser.dart';

/// Mirrors `labs_providers.dart` exactly — same repository/parser/notifier
/// shape, a separate instance because a prescription is not a lab report.

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>(
  (ref) => PrefsPrescriptionRepository(),
);

final prescriptionParserProvider = Provider<PrescriptionParser>((ref) {
  const gemini = GeminiPrescriptionParser(apiKey: geminiApiKey);
  if (!gemini.isConfigured) return const LocalPrescriptionParser();
  return const FallbackPrescriptionParser(
    primary: gemini,
    fallback: LocalPrescriptionParser(),
  );
});

class PrescriptionsState {
  const PrescriptionsState({
    this.prescriptions = const [],
    this.loading = true,
    this.parsing = false,
    this.error,
  });

  /// Newest first.
  final List<Prescription> prescriptions;

  final bool loading;

  /// True while a document is being parsed — the UI shows the pending row.
  final bool parsing;

  final String? error;

  Prescription? get latest =>
      prescriptions.isEmpty ? null : prescriptions.first;

  bool get hasAny => prescriptions.isNotEmpty;

  PrescriptionsState copyWith({
    List<Prescription>? prescriptions,
    bool? loading,
    bool? parsing,
    String? error,
    bool clearError = false,
  }) => PrescriptionsState(
    prescriptions: prescriptions ?? this.prescriptions,
    loading: loading ?? this.loading,
    parsing: parsing ?? this.parsing,
    error: clearError ? null : (error ?? this.error),
  );
}

class PrescriptionsNotifier extends Notifier<PrescriptionsState> {
  @override
  PrescriptionsState build() {
    _hydrate();
    return const PrescriptionsState();
  }

  PrescriptionRepository get _repository =>
      ref.read(prescriptionRepositoryProvider);

  Future<void> _hydrate() async {
    final prescriptions = await _repository.loadPrescriptions();
    state = PrescriptionsState(
      prescriptions: _sorted(prescriptions),
      loading: false,
    );
  }

  /// Newest prescribed date first, falling back to upload time.
  List<Prescription> _sorted(List<Prescription> prescriptions) {
    final out = [...prescriptions];
    out.sort((a, b) {
      final aDate = a.prescribedAt ?? a.uploadedAt;
      final bDate = b.prescribedAt ?? b.uploadedAt;
      return bDate.compareTo(aDate);
    });
    return out;
  }

  /// Parses and stores a prescription. Returns null on failure, with the
  /// reason in [PrescriptionsState.error].
  Future<Prescription?> upload(PrescriptionUpload upload) async {
    final rejection = upload.rejectionReason;
    if (rejection != null) {
      state = state.copyWith(error: rejection);
      return null;
    }

    state = state.copyWith(parsing: true, clearError: true);

    try {
      final prescription = await ref
          .read(prescriptionParserProvider)
          .parse(upload);
      final next = _sorted([prescription, ...state.prescriptions]);
      state = state.copyWith(prescriptions: next, parsing: false);
      await _repository.savePrescriptions(next);
      return prescription;
    } catch (error) {
      state = state.copyWith(
        parsing: false,
        error: 'That prescription could not be read. $error',
      );
      return null;
    }
  }

  Future<void> remove(String id) async {
    final next = state.prescriptions.where((p) => p.id != id).toList();
    state = state.copyWith(prescriptions: next);
    await _repository.savePrescriptions(next);
  }

  Future<void> clear() async {
    state = const PrescriptionsState(loading: false);
    await _repository.clear();
  }
}

final prescriptionsProvider =
    NotifierProvider<PrescriptionsNotifier, PrescriptionsState>(
      PrescriptionsNotifier.new,
    );
