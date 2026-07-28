import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps the system status bar transparent so this screen's own background
/// shows through it, with icon brightness picked to stay legible against
/// that background — [light] for a dark screen (light icons), false for a
/// light screen (dark icons).
class StatusBarStyle extends StatelessWidget {
  const StatusBarStyle({super.key, required this.child, required this.light});

  final Widget child;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: light ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: child,
    );
  }
}
