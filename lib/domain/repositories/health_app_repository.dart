import '../entities/connected_health_app.dart';

abstract interface class HealthAppRepository {
  List<ConnectedHealthApp> initialApps();
}
