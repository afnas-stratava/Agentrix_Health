import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../data/labs/gmail_lab_source.dart';
import '../../providers/gmail_import_provider.dart';
import 'main_shell.dart';
import 'upload_screen.dart';

/// Gmail import. Mirrors `app/gmail-import.tsx`.
///
/// Access is requested only when the user taps Connect, and only
/// `gmail.readonly` — never folded into signing in. Searching and importing
/// are separate steps on purpose: this screen lists what it found and the user
/// picks. Nothing is downloaded, parsed or stored until they do.
///
/// Until Google's OAuth verification and the annual CASA assessment clear, the
/// consent screen only completes for accounts listed as test users on the
/// Cloud project. That surfaces as [GmailImportStage.denied], which offers the
/// manual upload path rather than reading as a bug in the app.
class GmailImportScreen extends ConsumerWidget {
  const GmailImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gmailImportProvider);

    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.space1,
        bottom: MainShell.bottomInsetFor(context),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenBackButton(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Import from Gmail', style: AppTextStyles.h3),
                    const SizedBox(height: 6),
                    Text(
                      'Finds the lab reports already sitting in your inbox, so '
                      'you never have to hunt for a PDF again.',
                      style: AppTextStyles.cardBody.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space5),
        ..._body(context, ref, state),
        const SizedBox(height: AppSpacing.space5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space6),
          child: AppButton(
            label: 'Add a report by hand',
            block: true,
            variant: AppButtonVariant.secondary,
            leading: const Icon(Icons.add, size: 16),
            onPressed: () {
              Navigator.of(context).pop();
              MainShell.push(context, const UploadScreen());
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    GmailImportState state,
  ) {
    final notifier = ref.read(gmailImportProvider.notifier);

    return switch (state.stage) {
      GmailImportStage.idle => [
        const _Notice(
          icon: Icons.lock_outline,
          title: 'Read-only, and only when you ask',
          body:
              'Agentrix reads message attachments to find lab reports. It '
              'cannot send mail, delete anything or change your account, and '
              'it only looks when you tap below. You can revoke access from '
              'your Google account at any time.',
        ),
        _Action(
          label: 'Connect Gmail',
          icon: Icons.mail_outline,
          onPressed: notifier.search,
        ),
      ],

      GmailImportStage.searching => const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.space6),
          child: Center(child: CircularProgressIndicator()),
        ),
        Center(child: _Muted('Looking through your inbox…')),
      ],

      GmailImportStage.denied => [
        const _Notice(
          icon: Icons.no_accounts_outlined,
          title: 'Gmail access was not granted',
          body:
              'Nothing was read. This also happens while the integration is '
              'still in Google review, when only accounts added as testers can '
              'connect.',
        ),
        _Action(
          label: 'Try again',
          icon: Icons.refresh,
          onPressed: notifier.search,
        ),
      ],

      GmailImportStage.failed => [
        _Notice(
          icon: Icons.error_outline,
          title: 'Could not reach Gmail',
          body: state.error ?? 'Something went wrong.',
        ),
        _Action(
          label: 'Try again',
          icon: Icons.refresh,
          onPressed: notifier.search,
        ),
      ],

      GmailImportStage.results => [
        if (state.candidates.isEmpty) ...[
          const _Notice(
            icon: Icons.search_off,
            title: 'No lab reports found',
            body:
                'Nothing in your inbox looked like a lab report with an '
                'attachment. Many US labs email only a "your results are '
                'ready" notice and keep the PDF in their portal — in that '
                'case, download it there and add it by hand.',
          ),
          _Action(
            label: 'Search again',
            icon: Icons.refresh,
            onPressed: notifier.search,
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space6),
            child: Text(
              '${state.candidates.length} possible '
              '${state.candidates.length == 1 ? 'report' : 'reports'}. '
              'Tap one to read it.',
              style: AppTextStyles.cardBody,
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          for (final attachment in state.candidates)
            _CandidateRow(
              attachment: attachment,
              busy: state.importing.contains(attachment.attachmentId),
              done: state.imported.contains(attachment.attachmentId),
              onImport: () => notifier.import(attachment),
            ),
        ],
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space6,
              AppSpacing.space3,
              AppSpacing.space6,
              0,
            ),
            child: Text(
              state.error!,
              style: AppTextStyles.cardBody.copyWith(color: AppColors.muted),
            ),
          ),
      ],
    };
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.attachment,
    required this.busy,
    required this.done,
    required this.onImport,
  });

  final GmailAttachment attachment;
  final bool busy;
  final bool done;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space6,
        0,
        AppSpacing.space6,
        AppSpacing.space3,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.space3,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.subject,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _Muted(
                    '${attachment.senderName} · '
                    '${_formatDate(attachment.receivedAt)}',
                  ),
                  const SizedBox(height: 2),
                  _Muted(attachment.filename),
                ],
              ),
            ),
            if (done)
              const Icon(Icons.check_circle, color: AppColors.limeStrong)
            else if (busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              AppButton(
                label: 'Read',
                size: AppButtonSize.sm,
                onPressed: onImport,
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space6,
        0,
        AppSpacing.space6,
        AppSpacing.space4,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space4),
        decoration: BoxDecoration(
          color: AppColors.neutral200,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.space3,
          children: [
            Icon(icon, size: 18, color: AppColors.muted),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: AppTextStyles.cardBody.copyWith(height: 1.5),
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

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space6),
      child: AppButton(
        label: label,
        block: true,
        leading: Icon(icon, size: 18),
        onPressed: onPressed,
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTextStyles.cardBody.copyWith(
      fontSize: 13,
      color: AppColors.muted,
    ),
  );
}
