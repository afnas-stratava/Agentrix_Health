import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/labs/shared_document_receiver.dart';
import 'labs_providers.dart';

final sharedDocumentReceiverProvider = Provider<SharedDocumentReceiver>(
  (ref) => const SharedDocumentReceiver(),
);

/// Drains anything the share sheet handed over and runs it through the lab
/// parser.
///
/// Mounted once near the root so a document shared while the app was closed is
/// picked up on the next launch, and one shared while it was backgrounded is
/// picked up on resume. Nothing is re-imported: the native queue is cleared as
/// it is read.
class SharedDocumentWatcher extends ConsumerStatefulWidget {
  const SharedDocumentWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SharedDocumentWatcher> createState() =>
      _SharedDocumentWatcherState();
}

class _SharedDocumentWatcherState extends ConsumerState<SharedDocumentWatcher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _drain();
  }

  Future<void> _drain() async {
    final uploads = await ref
        .read(sharedDocumentReceiverProvider)
        .takePending();
    if (uploads.isEmpty || !mounted) return;

    final labs = ref.read(labsProvider.notifier);
    for (final upload in uploads) {
      // Sequential on purpose: each parse is a model call, and firing several
      // at once would race the shared parsing flag in LabsState.
      await labs.upload(upload);
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
