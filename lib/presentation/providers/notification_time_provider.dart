import 'package:flutter_riverpod/flutter_riverpod.dart';

const timeOptions = ['6:00 AM', '6:30 AM', '7:00 AM', '7:30 AM', '8:00 AM'];

class NotificationTimeNotifier extends Notifier<int> {
  @override
  int build() => 2;

  void increment() => state = (state + 1).clamp(0, timeOptions.length - 1);
  void decrement() => state = (state - 1).clamp(0, timeOptions.length - 1);
  void reset() => state = 2;
}

final notificationTimeIndexProvider =
    NotifierProvider<NotificationTimeNotifier, int>(
      NotificationTimeNotifier.new,
    );

final briefTimeLabelProvider = Provider<String>(
  (ref) => timeOptions[ref.watch(notificationTimeIndexProvider)],
);
