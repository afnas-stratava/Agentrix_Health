import 'package:agentrix_health/core/config/secrets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/labs/gemini_lab_parser.dart';
import '../../data/repositories/prefs_lab_repository.dart';
import '../../domain/entities/labs/lab_report.dart';
import '../../domain/repositories/lab_repository.dart';
import '../../features/labs/lab_parser.dart';
import 'user_profile_provider.dart';

final labRepositoryProvider = Provider<LabRepository>(
  (ref) => PrefsLabRepository(),
);

/// Gemini reads the document; [LocalLabParser] is what answers when there is
/// no key configured, the network is down, or the call fails — the same
/// primary/fallback shape the health assistant chat uses.
final labParserProvider = Provider<LabParser>((ref) {
  const gemini = GeminiLabParser(apiKey: geminiApiKey);
  if (!gemini.isConfigured) return const LocalLabParser();
  return const FallbackLabParser(
    primary: gemini,
    fallback: LocalLabParser(),
  );
});

class LabsState {
  const LabsState({
    this.reports = const [],
    this.loading = true,
    this.parsing = false,
    this.error,
  });

  /// Newest first.
  final List<LabReport> reports;

  final bool loading;

  /// True while a document is being parsed — the UI shows the pending row.
  final bool parsing;

  final String? error;

  LabReport? get latest => reports.isEmpty ? null : reports.first;

  bool get hasAny => reports.isNotEmpty;

  LabsState copyWith({
    List<LabReport>? reports,
    bool? loading,
    bool? parsing,
    String? error,
    bool clearError = false,
  }) => LabsState(
    reports: reports ?? this.reports,
    loading: loading ?? this.loading,
    parsing: parsing ?? this.parsing,
    error: clearError ? null : (error ?? this.error),
  );
}

class LabsNotifier extends Notifier<LabsState> {
  @override
  LabsState build() {
    _hydrate();
    return const LabsState();
  }

  LabRepository get _repository => ref.read(labRepositoryProvider);

  Future<void> _hydrate() async {
    final reports = await _repository.loadReports();
    state = LabsState(reports: _sorted(reports), loading: false);
  }

  /// Newest collection date first, falling back to upload time when a report
  /// carries no collection date.
  List<LabReport> _sorted(List<LabReport> reports) {
    final out = [...reports];
    out.sort((a, b) {
      final aDate = a.collectedAt ?? a.uploadedAt;
      final bDate = b.collectedAt ?? b.uploadedAt;
      return bDate.compareTo(aDate);
    });
    return out;
  }

  /// Parses and stores a report. Returns null on failure, with the reason in
  /// [LabsState.error].
  Future<LabReport?> upload(LabUpload upload) async {
    final rejection = upload.rejectionReason;
    if (rejection != null) {
      state = state.copyWith(error: rejection);
      return null;
    }

    state = state.copyWith(parsing: true, clearError: true);

    try {
      final report = await ref
          .read(labParserProvider)
          .parse(upload, gender: ref.read(userProfileProvider).gender);
      final next = _sorted([report, ...state.reports]);
      state = state.copyWith(reports: next, parsing: false);
      await _repository.saveReports(next);
      return report;
    } catch (error) {
      state = state.copyWith(
        parsing: false,
        error: 'That report could not be read. $error',
      );
      return null;
    }
  }

  Future<void> remove(String id) async {
    final next = state.reports.where((r) => r.id != id).toList();
    state = state.copyWith(reports: next);
    await _repository.saveReports(next);
  }

  Future<void> clear() async {
    state = const LabsState(loading: false);
    await _repository.clear();
  }
}

final labsProvider = NotifierProvider<LabsNotifier, LabsState>(
  LabsNotifier.new,
);

/// The report every downstream feature reads: the brief's food focus, the dish
/// ranker's focus tags, and the blood-work card on Home.
final latestLabReportProvider = Provider<LabReport?>(
  (ref) => ref.watch(labsProvider).latest,
);
