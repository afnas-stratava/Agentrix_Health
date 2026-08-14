import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'presentation/providers/app_stage_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Let each screen draw behind the system bars instead of the OS painting
  // an opaque strip behind them — screens then set their own transparent
  // SystemUiOverlayStyle (see StatusBarStyle) so the app's own background
  // shows through.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // No backend in this build — see `account_provider.dart` and
  // `presentation/providers/*` for where Firebase/Gemini/Health Connect/
  // Overpass calls were replaced with local and fixture data. Firebase
  // packages stay in pubspec.yaml/native config so wiring a real backend
  // back in later does not mean re-adding and reconfiguring them.

  // Resolved here rather than inside AppStageNotifier.build(), which cannot
  // await it: doing it before the first frame means that frame is already
  // correct, instead of drawing onboarding for one frame and then correcting
  // it — the flash a user sees as "onboarding showing again" on every launch.
  var onboardingComplete = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    onboardingComplete = prefs.getBool(onboardingCompleteKey) ?? false;
  } catch (error) {
    debugPrint('Could not read onboarding flag, defaulting to false: $error');
  }

  runApp(
    ProviderScope(
      overrides: [
        onboardingCompleteAtLaunchProvider.overrideWithValue(
          onboardingComplete,
        ),
      ],
      child: const AgentrixHealthApp(),
    ),
  );
}
