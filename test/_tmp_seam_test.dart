import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentrix_health/core/theme/app_colors.dart';
import 'package:agentrix_health/presentation/widgets/canvas_wash.dart';

/// Reproduces the shell composition: a 47pt notch inset, wash outside the
/// SafeArea, plain canvas content inside it.
Widget _shell({required bool washOutsideSafeArea}) {
  const inner = SafeArea(bottom: false, child: SizedBox.expand());
  return MediaQuery(
    data: const MediaQueryData(
      size: Size(390, 300),
      padding: EdgeInsets.only(top: 47),
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        child: washOutsideSafeArea
            ? const CanvasWash(child: inner)
            : const ColoredBox(
                color: AppColors.canvas,
                child: SafeArea(
                  bottom: false,
                  child: CanvasWash(child: SizedBox.expand()),
                ),
              ),
      ),
    ),
  );
}

Future<List<Color>> _column(WidgetTester tester) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary));
  final image = await boundary.toImage();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  Color at(int y) {
    final i = (y * image.width + 195) * 4;
    return Color.fromARGB(255, bytes[i], bytes[i + 1], bytes[i + 2]);
  }

  return [at(40), at(46), at(48), at(54)];
}

void main() {
  testWidgets('no seam at the safe-area edge', (tester) async {
    await tester.pumpWidget(_shell(washOutsideSafeArea: false));
    debugPrint('before: ${await _column(tester)}');

    await tester.pumpWidget(_shell(washOutsideSafeArea: true));
    debugPrint('after:  ${await _column(tester)}');
  });
}
