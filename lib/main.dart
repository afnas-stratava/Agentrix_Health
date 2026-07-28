import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Let each screen draw behind the system bars instead of the OS painting
  // an opaque strip behind them — screens then set their own transparent
  // SystemUiOverlayStyle (see StatusBarStyle) so the app's own background
  // shows through.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Firebase is used for background sync only (see UserProfileNotifier) —
  // nothing on the golden path requires it, so a misconfigured project,
  // offline device, etc. must not block the app from launching at all.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // No sign-up flow yet — anonymous auth just gives each install a stable
    // uid so per-user data (e.g. the health profile) has somewhere to live.
    // Swap this out once a real auth feature lands.
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (error) {
    debugPrint('Firebase setup failed, continuing without cloud sync: $error');
  }

  runApp(const ProviderScope(child: AgentrixHealthApp()));
}
