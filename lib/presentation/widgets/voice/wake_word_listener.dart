import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/wake_word_provider.dart';

/// Renders nothing — exists only to keep [wakeWordControllerProvider] alive
/// for the app's whole lifetime by watching it. Riverpod providers are lazy;
/// without something watching this one, `WakeWordController.build()` would
/// never run and "Hey Agentrix" would never start listening. Mounted once in
/// `app.dart`, next to `GlobalVoiceButton`.
class WakeWordListener extends ConsumerWidget {
  const WakeWordListener({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(wakeWordControllerProvider);
    return const SizedBox.shrink();
  }
}
