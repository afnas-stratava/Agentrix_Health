import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../domain/entities/labs/lab_report.dart';
import '../../providers/labs_providers.dart';
import 'ai_scan_progress.dart';

/// The three real ways to get a report in, plus the sample.
///
/// This replaces a bordered box captioned "Drop a PDF or photo here" that had no
/// tap handler at all — a dead affordance is worse than no affordance, because it
/// reads as broken rather than absent.
class UploadReportActions extends ConsumerWidget {
  const UploadReportActions({super.key, this.onUploaded});

  final ValueChanged<LabReport>? onUploaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labs = ref.watch(labsProvider);

    if (labs.parsing) {
      return const AiScanProgress();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space2,
      children: [
        AppButton(
          label: 'Choose a PDF',
          block: true,
          leading: const Icon(Icons.picture_as_pdf_outlined, size: 16),
          onPressed: () => _pickDocument(context, ref),
        ),
        Row(
          spacing: AppSpacing.space2,
          children: [
            Expanded(
              child: AppButton(
                label: 'Photograph it',
                variant: AppButtonVariant.secondary,
                leading: const Icon(Icons.photo_camera_outlined, size: 15),
                onPressed: () => _pickImage(context, ref, ImageSource.camera),
              ),
            ),
            Expanded(
              child: AppButton(
                label: 'From library',
                variant: AppButtonVariant.secondary,
                leading: const Icon(Icons.image_outlined, size: 15),
                onPressed: () => _pickImage(context, ref, ImageSource.gallery),
              ),
            ),
          ],
        ),
        AppButton(
          label: 'Use the sample panel',
          variant: AppButtonVariant.ghost,
          block: true,
          leading: const Icon(Icons.science_outlined, size: 15),
          onPressed: () => _useSample(ref),
        ),
        if (labs.error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space2),
            child: Text(
              labs.error!,
              style: AppTextStyles.cardBody.copyWith(
                color: AppColors.critical,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickDocument(BuildContext context, WidgetRef ref) async {
    // Captured before the first await: a picker can outlive this widget, and
    // reaching for `ScaffoldMessenger.of(context)` afterwards is exactly the
    // crash `use_build_context_synchronously` is warning about.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      final file = result?.files.singleOrNull;
      final path = file?.path;
      if (file == null || path == null) return;

      await _submit(
        ref,
        LabUpload(
          path: path,
          name: file.name,
          source: LabSource.pdf,
          sizeBytes: file.size,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open that file: $error')),
      );
    }
  }

  Future<void> _pickImage(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2400,
        imageQuality: 90,
      );
      if (picked == null) return;

      await _submit(
        ref,
        LabUpload(
          path: picked.path,
          name: picked.name,
          source: LabSource.image,
          sizeBytes: await picked.length(),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not use that photo: $error')),
      );
    }
  }

  Future<void> _useSample(WidgetRef ref) => _submit(
    ref,
    const LabUpload(
      path: '',
      name: 'Sample panel',
      source: LabSource.sample,
    ),
  );

  Future<void> _submit(WidgetRef ref, LabUpload upload) async {
    final report = await ref.read(labsProvider.notifier).upload(upload);
    if (report != null) onUploaded?.call(report);
  }
}
