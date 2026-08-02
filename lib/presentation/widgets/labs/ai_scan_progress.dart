import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Animated, staged progress shown while [GeminiLabParser] reads a report.
///
/// The Gemini call is a single non-streaming request with no progress events
/// of its own, so the steps below are a timed approximation rather than a
/// real signal — they exist to keep the wait legible instead of reading as a
/// stalled spinner. The last step holds indefinitely; it's the parent that
/// removes this widget once `LabsState.parsing` actually flips false.
class AiScanProgress extends StatefulWidget {
  const AiScanProgress({super.key});

  @override
  State<AiScanProgress> createState() => _AiScanProgressState();
}

class _AiScanProgressState extends State<AiScanProgress>
    with TickerProviderStateMixin {
  static const _steps = [
    'Uploading your document',
    'Reading with AI',
    'Extracting biomarkers',
    'Checking reference ranges',
  ];

  static const _tips = [
    'Matching each marker against clinical reference ranges…',
    'Converting non-standard units automatically…',
    'Flagging anything outside your normal range…',
    'Cross-checking against your last panel…',
    'Almost there — double-checking the numbers…',
  ];

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  Timer? _stepTimer;
  Timer? _tipTimer;
  int _stepIndex = 0;
  int _tipIndex = 0;

  @override
  void initState() {
    super.initState();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1700), (timer) {
      if (_stepIndex >= _steps.length - 1) {
        timer.cancel();
        return;
      }
      setState(() => _stepIndex++);
    });
    _tipTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _stepTimer?.cancel();
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space5,
        vertical: AppSpacing.space6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.brand200),
        color: AppColors.brand50,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.brand,
                    backgroundColor: AppColors.brand100,
                  ),
                ),
                ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.08).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.brand,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            'Reading your report…',
            style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.space4),
          for (var i = 0; i < _steps.length; i++)
            _StepRow(
              label: _steps[i],
              state: i < _stepIndex
                  ? _StepState.done
                  : i == _stepIndex
                  ? _StepState.active
                  : _StepState.pending,
            ),
          const SizedBox(height: AppSpacing.space3),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _tips[_tipIndex],
              key: ValueKey(_tipIndex),
              textAlign: TextAlign.center,
              style: AppTextStyles.cardBody.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { pending, active, done }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: switch (state) {
              _StepState.done => const Icon(
                Icons.check_circle,
                size: 18,
                color: AppColors.brand,
              ),
              _StepState.active => const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brand,
              ),
              _StepState.pending => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.brand200, width: 1.5),
                ),
              ),
            },
          ),
          const SizedBox(width: AppSpacing.space3),
          Text(
            label,
            style: AppTextStyles.cardBody.copyWith(
              color: state == _StepState.pending
                  ? AppColors.faint
                  : AppColors.ink,
              fontWeight: state == _StepState.active
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
