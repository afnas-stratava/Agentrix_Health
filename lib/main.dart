import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Let each screen draw behind the system bars instead of the OS painting
  // an opaque strip behind them — screens then set their own transparent
  // SystemUiOverlayStyle (see StatusBarStyle) so the app's own background
  // shows through.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(child: AgentrixHealthApp()));
}
