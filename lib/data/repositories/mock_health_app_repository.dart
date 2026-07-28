import '../../domain/entities/connected_health_app.dart';
import '../../domain/repositories/health_app_repository.dart';

class MockHealthAppRepository implements HealthAppRepository {
  @override
  List<ConnectedHealthApp> initialApps() {
    return const [
      ConnectedHealthApp(
        id: HealthAppId.apple,
        name: 'Apple Health',
        initial: 'A',
        connected: false,
      ),
      ConnectedHealthApp(
        id: HealthAppId.google,
        name: 'Google Fit',
        initial: 'G',
        connected: false,
      ),
      ConnectedHealthApp(
        id: HealthAppId.fitbit,
        name: 'Fitbit',
        initial: 'F',
        connected: false,
      ),
      ConnectedHealthApp(
        id: HealthAppId.oura,
        name: 'Oura',
        initial: 'O',
        connected: false,
      ),
    ];
  }
}
