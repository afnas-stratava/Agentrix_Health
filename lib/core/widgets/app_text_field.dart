import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Labeled text input matching `.field` + `.input`.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.keyboardType,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final TextInputType? keyboardType;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5,
      children: [
        Text(widget.label, style: AppTextStyles.fieldLabel),
        Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(AppSpacing.space4),
          ),
          child: TextFormField(
            controller: _controller,
            onChanged: widget.onChanged,
            keyboardType: widget.keyboardType,
            style: AppTextStyles.input,
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.placeholder,
              hintStyle: AppTextStyles.input.copyWith(
                color: AppColors.text.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
