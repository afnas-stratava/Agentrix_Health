enum HealthAppId { apple, google, fitbit, oura }

class ConnectedHealthApp {
  const ConnectedHealthApp({
    required this.id,
    required this.name,
    required this.initial,
    required this.connected,
  });

  final HealthAppId id;
  final String name;
  final String initial;
  final bool connected;

  ConnectedHealthApp copyWith({bool? connected}) {
    return ConnectedHealthApp(
      id: id,
      name: name,
      initial: initial,
      connected: connected ?? this.connected,
    );
  }
}
