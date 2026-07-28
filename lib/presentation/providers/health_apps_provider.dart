import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/connected_health_app.dart';
import 'repository_providers.dart';

class HealthAppsNotifier extends Notifier<List<ConnectedHealthApp>> {
  @override
  List<ConnectedHealthApp> build() =>
      ref.read(healthAppRepositoryProvider).initialApps();

  void toggle(HealthAppId id) {
    state = [
      for (final app in state)
        if (app.id == id) app.copyWith(connected: !app.connected) else app,
    ];
  }

  void reset() => state = ref.read(healthAppRepositoryProvider).initialApps();
}

final healthAppsProvider =
    NotifierProvider<HealthAppsNotifier, List<ConnectedHealthApp>>(
      HealthAppsNotifier.new,
    );

final anyHealthAppConnectedProvider = Provider<bool>((ref) {
  return ref.watch(healthAppsProvider).any((app) => app.connected);
});
