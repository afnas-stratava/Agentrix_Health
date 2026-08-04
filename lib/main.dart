import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'presentation/providers/app_stage_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Let each screen draw behind the system bars instead of the OS painting
  // an opaque strip behind them — screens then set their own transparent
  // SystemUiOverlayStyle (see StatusBarStyle) so the app's own background
  // shows through.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Set once Firebase confirms the persisted session belongs to a real
  // account, so a returning user lands straight in the app instead of
  // walking through sign-in and onboarding again on every launch.
  var returningAccount = false;

  // Sign-in is on the golden path now (AppStage.account sits second in
  // onboarding), so Firebase is no longer optional. It is still initialized
  // inside a try/catch: a misconfigured project or an offline first launch
  // should surface as an error the user can read at the account gate, not as
  // a crash before the first frame.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // The anonymous uid is the pre-sign-in identity, not a substitute for one:
    // per-user data written during onboarding hangs off it, and
    // AccountController *links* the Apple or Google credential onto this same
    // uid so none of it is stranded. Removing this would orphan every profile
    // written before the user reaches the account step.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await FirebaseAuth.instance.signInAnonymously();
    } else {
      returningAccount = !user.isAnonymous;
    }
  } catch (error) {
    debugPrint('Firebase setup failed, continuing without cloud sync: $error');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (returningAccount)
          initialAppStageProvider.overrideWithValue(AppStage.main),
      ],
      child: const AgentrixHealthApp(),
    ),
  );
}
