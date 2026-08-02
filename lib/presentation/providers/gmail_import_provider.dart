import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/labs/gmail_lab_source.dart';
import 'labs_providers.dart';

final gmailLabSourceProvider = Provider<GmailLabSource>((ref) {
  final source = GmailLabSource();
  ref.onDispose(source.dispose);
  return source;
});

enum GmailImportStage {
  /// Nothing asked for yet — the user has not granted Gmail access.
  idle,
  searching,
  results,

  /// The user declined, or the grant was revoked. Not an error state: the
  /// screen offers the manual upload path instead of a failure message.
  denied,
  failed,
}

class GmailImportState {
  const GmailImportState({
    this.stage = GmailImportStage.idle,
    this.candidates = const [],
    this.importing = const {},
    this.imported = const {},
    this.error,
  });

  final GmailImportStage stage;
  final List<GmailAttachment> candidates;

  /// Attachment ids currently downloading or parsing.
  final Set<String> importing;

  /// Attachment ids already turned into a report, so a second tap is a no-op
  /// rather than a duplicate entry in the user's history.
  final Set<String> imported;

  final String? error;

  GmailImportState copyWith({
    GmailImportStage? stage,
    List<GmailAttachment>? candidates,
    Set<String>? importing,
    Set<String>? imported,
    String? error,
    bool clearError = false,
  }) => GmailImportState(
    stage: stage ?? this.stage,
    candidates: candidates ?? this.candidates,
    importing: importing ?? this.importing,
    imported: imported ?? this.imported,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Drives the Gmail import screen.
///
/// Searching and importing are separate, deliberately. [search] only lists what
/// it found; nothing is downloaded or parsed until the user picks a specific
/// message. Reading someone's mail and acting on it unprompted is not a thing
/// this app does.
class GmailImportNotifier extends Notifier<GmailImportState> {
  @override
  GmailImportState build() => const GmailImportState();

  Future<void> search() async {
    state = state.copyWith(
      stage: GmailImportStage.searching,
      clearError: true,
    );
    try {
      final found = await ref.read(gmailLabSourceProvider).findCandidates();
      state = state.copyWith(
        stage: GmailImportStage.results,
        candidates: found,
      );
    } on GmailAccessDenied {
      state = state.copyWith(stage: GmailImportStage.denied);
    } catch (error) {
      state = state.copyWith(
        stage: GmailImportStage.failed,
        error: 'Could not reach Gmail. $error',
      );
    }
  }

  /// Downloads one attachment and runs it through the lab parser.
  ///
  /// Errors are surfaced on this screen rather than thrown — a report that
  /// will not parse should not take the whole list down with it.
  Future<void> import(GmailAttachment attachment) async {
    if (state.importing.contains(attachment.attachmentId) ||
        state.imported.contains(attachment.attachmentId)) {
      return;
    }

    state = state.copyWith(
      importing: {...state.importing, attachment.attachmentId},
      clearError: true,
    );

    try {
      final upload = await ref
          .read(gmailLabSourceProvider)
          .download(attachment);
      final report = await ref.read(labsProvider.notifier).upload(upload);

      state = state.copyWith(
        importing: {...state.importing}..remove(attachment.attachmentId),
        imported: report == null
            ? state.imported
            : {...state.imported, attachment.attachmentId},
        error: report == null
            ? 'That report could not be read.'
            : null,
      );
    } catch (error) {
      state = state.copyWith(
        importing: {...state.importing}..remove(attachment.attachmentId),
        error: 'Could not import ${attachment.filename}. $error',
      );
    }
  }
}

final gmailImportProvider =
    NotifierProvider<GmailImportNotifier, GmailImportState>(
      GmailImportNotifier.new,
    );
