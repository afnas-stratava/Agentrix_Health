import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:agentrix_health/core/config/secrets.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/labs/gmail_lab_source.dart';
import '../../../domain/entities/labs/lab_report.dart';
import '../../../domain/entities/prescriptions/prescription.dart';
import '../../providers/labs_providers.dart';
import '../../providers/prescriptions_providers.dart';
import 'gmail_import_screen.dart';
import 'main_shell.dart';

/// Which document type this screen is collecting. Gmail import only exists
/// for lab reports — it searches specifically for attachments from known
/// diagnostics labs, which has no prescription equivalent — so a prescription
/// upload skips straight to the manual pickers.
enum UploadKind { labReport, prescription }

/// Add your blood work, or a prescription. Mirrors `app/upload.tsx`.
///
/// Gmail is the loud primary path and the manual pickers are deliberately
/// quieter, because most lab reports arrive by email and stay there — hunting
/// for a PDF in Files is the failure mode this screen exists to avoid.
///
/// In this build the Gmail path leads to an explainer rather than a consent
/// screen; see [GmailImportScreen] for why.
enum _ManualMethod {
  pdf(Icons.description_outlined, 'Choose a PDF'),
  library(Icons.image_outlined, 'Pick a photo'),
  camera(Icons.photo_camera_outlined, 'Scan a printout');

  const _ManualMethod(this.icon, this.title);

  final IconData icon;
  final String title;
}

/// Picker output before it becomes a [LabUpload] or [PrescriptionUpload] —
/// which one depends on [UploadScreen.kind], decided in `_handleManual`.
class _PickedFile {
  const _PickedFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.isPdf,
  });

  final String path;
  final String name;
  final int? sizeBytes;
  final bool isPdf;
}

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key, this.kind = UploadKind.labReport});

  final UploadKind kind;

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  String? _error;
  _ManualMethod? _picking;

  Future<void> _handleManual(_ManualMethod method) async {
    setState(() {
      _error = null;
      _picking = method;
    });

    final navigator = Navigator.of(context);

    try {
      final picked = switch (method) {
        _ManualMethod.pdf => await _pickDocument(),
        _ManualMethod.library => await _pickPhoto(ImageSource.gallery),
        _ManualMethod.camera => await _pickPhoto(ImageSource.camera),
      };

      // Cancelled.
      if (picked == null) return;

      // Dismiss immediately: parsing is slow and the pending row is already
      // visible on the tab.
      navigator.pop();
      final label = switch (widget.kind) {
        UploadKind.labReport => 'report',
        UploadKind.prescription => 'prescription',
      };
      switch (widget.kind) {
        case UploadKind.labReport:
          unawaited(
            ref
                .read(labsProvider.notifier)
                .upload(
                  LabUpload(
                    path: picked.path,
                    name: picked.name,
                    source: picked.isPdf ? LabSource.pdf : LabSource.image,
                    sizeBytes: picked.sizeBytes,
                  ),
                ),
          );
        case UploadKind.prescription:
          unawaited(
            ref
                .read(prescriptionsProvider.notifier)
                .upload(
                  PrescriptionUpload(
                    path: picked.path,
                    name: picked.name,
                    source: picked.isPdf
                        ? PrescriptionSource.pdf
                        : PrescriptionSource.image,
                    sizeBytes: picked.sizeBytes,
                  ),
                ),
          );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Your $label is being processed. You will see it on the tab shortly.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      // The only failure feedback on this screen was a line of red text at
      // the top, which is off-screen once the picker has been dismissed.
      HapticFeedback.vibrate();
      setState(() => _error = 'Could not read that file: $error');
    } finally {
      if (mounted) setState(() => _picking = null);
    }
  }

  Future<_PickedFile?> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final file = result?.files.singleOrNull;
    final path = file?.path;
    if (file == null || path == null) return null;

    return _PickedFile(
      path: path,
      name: file.name,
      sizeBytes: file.size,
      isPdf: true,
    );
  }

  Future<_PickedFile?> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2400,
      imageQuality: 90,
    );
    if (picked == null) return null;

    return _PickedFile(
      path: picked.path,
      name: picked.name,
      sizeBytes: await picked.length(),
      isPdf: false,
    );
  }

  bool get _isLab => widget.kind == UploadKind.labReport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.space6,
        MainShell.bottomInsetFor(context),
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLab ? 'Add your blood work' : 'Add a prescription',
                      style: AppTextStyles.h3.copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLab
                          ? 'Most lab reports arrive by email and stay there. '
                                'We can find them for you.'
                          : 'Photograph a prescription or pharmacy label and '
                                'we will read the medicines onto your list.',
                      style: AppTextStyles.cardBody.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            // A close affordance rather than a back chevron: this is a modal
            // task you finish or abandon, not a place in a hierarchy.
            AppButton.icon(
              leading: const Icon(Icons.close, size: 16),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),

        if (_isLab) ...[
          const SizedBox(height: AppSpacing.space6),
          const _GmailCard(),

          const SizedBox(height: AppSpacing.space3),
          const _AccessDisclosure(),

          const SizedBox(height: AppSpacing.space6 + AppSpacing.space1),
          Text(
            'OR ADD ONE MANUALLY',
            style: AppTextStyles.tag.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.55,
              color: AppColors.faint,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
        ] else
          const SizedBox(height: AppSpacing.space6),

        Container(
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final method in _ManualMethod.values)
                _ManualRow(
                  method: method,
                  busy: _picking == method,
                  enabled: _picking == null,
                  isFirst: method == _ManualMethod.values.first,
                  onTap: () => _handleManual(method),
                ),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: AppSpacing.space4),
          Container(
            padding: const EdgeInsets.all(AppSpacing.space4),
            decoration: BoxDecoration(
              color: AppColors.critical.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.critical.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              _error!,
              style: AppTextStyles.cardBody.copyWith(
                fontSize: 13,
                height: 1.46,
                color: AppColors.ink.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],

        if (geminiApiKey.trim().isEmpty) ...[
          const SizedBox(height: AppSpacing.space5),
          const Text(
            'No AI key configured — parsing runs against on-device fixtures.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.faint),
          ),
        ],
      ],
    );
  }
}

/// The loud path. Keeps RN's accent top-rule and "Fastest" badge so the
/// hierarchy between this and the manual list is unmistakable.
class _GmailCard extends StatelessWidget {
  const _GmailCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          MainShell.push(context, const GmailImportScreen());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: AppColors.accent),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space5),
              child: Row(
                spacing: 14,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.mail_outline,
                      size: 22,
                      color: AppColors.ink,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          spacing: AppSpacing.space2,
                          children: [
                            Text(
                              'Connect Gmail',
                              style: AppTextStyles.h5.copyWith(fontSize: 17),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.ink.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                'FASTEST',
                                style: AppTextStyles.tag.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: AppColors.ink.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'We search only for messages from known diagnostics '
                          'labs, and only ones with attachments.',
                          style: AppTextStyles.cardBody.copyWith(height: 1.42),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.faint,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown before consent rather than buried in a policy — which is the only
/// point at which a permission explanation is actually worth anything.
class _AccessDisclosure extends StatelessWidget {
  const _AccessDisclosure();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space2 + 2,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 15,
            color: AppColors.optimal,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What we access',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Read-only. We search for attachments from known labs, and we '
                  'only ever open the ones you tick. We never send email, never '
                  'read unrelated messages, and your Google sign-in stays on '
                  'Google’s servers — this app never holds your password or a '
                  'long-lived token.',
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualRow extends StatelessWidget {
  const _ManualRow({
    required this.method,
    required this.busy,
    required this.enabled,
    required this.isFirst,
    required this.onTap,
  });

  final _ManualMethod method;
  final bool busy;
  final bool enabled;
  final bool isFirst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          border: isFirst
              ? null
              : const Border(top: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: 14,
        ),
        child: Row(
          spacing: 14,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.muted,
                      ),
                    )
                  : Icon(method.icon, size: 17, color: AppColors.muted),
            ),
            Expanded(
              child: Text(
                method.title,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 14,
                  color: AppColors.ink.withValues(alpha: 0.8),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
