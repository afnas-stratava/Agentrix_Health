import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/brief_line.dart';
import 'repository_providers.dart';

class BriefState {
  const BriefState({this.variantIndex = 0, this.loading = false});

  final int variantIndex;
  final bool loading;

  BriefState copyWith({int? variantIndex, bool? loading}) {
    return BriefState(
      variantIndex: variantIndex ?? this.variantIndex,
      loading: loading ?? this.loading,
    );
  }
}

class BriefNotifier extends Notifier<BriefState> {
  @override
  BriefState build() => const BriefState();

  List<BriefLine> get currentLines {
    final variants = ref.read(briefRepositoryProvider).briefVariants();
    return variants[state.variantIndex % variants.length];
  }

  Future<void> regenerate() async {
    state = state.copyWith(loading: true);
    await ref.read(briefRepositoryProvider).simulateGeneration();
    final variantCount = ref
        .read(briefRepositoryProvider)
        .briefVariants()
        .length;
    state = state.copyWith(
      loading: false,
      variantIndex: (state.variantIndex + 1) % variantCount,
    );
  }

  void reset() => state = const BriefState();
}

final briefProvider = NotifierProvider<BriefNotifier, BriefState>(
  BriefNotifier.new,
);

final briefLinesProvider = Provider<List<BriefLine>>((ref) {
  ref.watch(briefProvider);
  return ref.read(briefProvider.notifier).currentLines;
});
