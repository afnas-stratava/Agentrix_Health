import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/blood_marker.dart';
import 'repository_providers.dart';

class BloodTestState {
  const BloodTestState({this.uploaded = false, this.markers = const []});

  final bool uploaded;
  final List<BloodMarker> markers;

  BloodTestState copyWith({bool? uploaded, List<BloodMarker>? markers}) {
    return BloodTestState(
      uploaded: uploaded ?? this.uploaded,
      markers: markers ?? this.markers,
    );
  }
}

class BloodTestNotifier extends Notifier<BloodTestState> {
  @override
  BloodTestState build() => const BloodTestState();

  Future<void> useSampleReport() async {
    final markers = await ref
        .read(bloodTestRepositoryProvider)
        .fetchSampleReport();
    state = state.copyWith(uploaded: true, markers: markers);
  }

  void reset() => state = const BloodTestState();
}

final bloodTestProvider = NotifierProvider<BloodTestNotifier, BloodTestState>(
  BloodTestNotifier.new,
);
