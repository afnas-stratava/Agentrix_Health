import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/section_header.dart';
import 'main_shell.dart';
import 'upload_screen.dart';

/// Gmail import. Mirrors `app/gmail-import.tsx` — as far as it can.
///
/// ───────────────────────────────────────────────────────────────────────────
/// THIS FEATURE IS NOT WIRED UP, AND THIS SCREEN SAYS SO.
///
/// It is blocked on four things, three of which are outside the code:
///
///  1. `gmail.readonly` is a Google **Restricted** scope. Shipping it requires
///     OAuth verification plus an annual third-party CASA security assessment.
///     `gmail.metadata` would only be Sensitive, but cannot read attachment
///     bodies — which is the entire feature.
///  2. The authorization-code exchange must happen server-side (the PKCE
///     verifier never belongs in a shipped bundle). This build has no backend.
///  3. Extracting values from a fetched attachment needs the OCR service that
///     is also not configured — see `lab_parser.dart`.
///  4. Until verification clears, it would only work for accounts added as test
///     users in the Google Cloud console.
///
/// A "Connect Gmail" button that opened a consent screen and then failed at the
/// token exchange would be worse than this screen: it would look like a bug in
/// the app rather than a capability that is not built. So the affordance is
/// absent and the reason is stated, with the manual path offered instead.
///
/// To finish it: implement the OAuth flow against a backend that holds the client
/// secret, then reuse [LabParser] on the fetched attachment. Nothing downstream
/// changes — `LabSource.email` already exists for exactly this.
/// ───────────────────────────────────────────────────────────────────────────
class GmailImportScreen extends ConsumerWidget {
  const GmailImportScreen({super.key});

  static const _blockers = [
    (
      'Restricted Google scope',
      'Reading attachment bodies needs gmail.readonly, which Google classes as '
          'Restricted. Publishing with it requires OAuth verification and an '
          'annual third-party security assessment.',
    ),
    (
      'No server to exchange the token',
      'The authorization code has to be exchanged for a token server-side — a '
          'client secret in a shipped app is not a secret. This build has no '
          'backend.',
    ),
    (
      'No OCR service',
      'Even with the PDF in hand, pulling values out of it needs the document '
          'parsing service that is not configured either.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      'The idea: find the lab reports already sitting in your '
                      'inbox, so you never have to hunt for a PDF again.',
                      style: AppTextStyles.cardBody.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space6,
            AppSpacing.space5,
            AppSpacing.space6,
            0,
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
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.muted,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Not available in this build',
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rather than show you a Connect button that fails '
                        'halfway through, here is exactly what it is waiting on.',
                        style: AppTextStyles.cardBody.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space6,
            AppSpacing.space6,
            AppSpacing.space6,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'What it needs'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.hairline),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: AppShadows.sm,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final blocker in _blockers)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.space4),
                        decoration: BoxDecoration(
                          border: blocker == _blockers.last
                              ? null
                              : const Border(
                                  bottom: BorderSide(
                                    color: AppColors.hairline,
                                  ),
                                ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              blocker.$1,
                              style: AppTextStyles.cardTitle.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              blocker.$2,
                              style: AppTextStyles.cardBody.copyWith(
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space6,
            AppSpacing.space6,
            AppSpacing.space6,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'What works now'),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                child: Text(
                  'Adding a report by hand takes two taps, and everything after '
                  'the upload — unit conversion, optimal-band flagging, the '
                  'correlation engine — is fully built.',
                  style: AppTextStyles.cardBody.copyWith(height: 1.5),
                ),
              ),
              AppButton(
                label: 'Add a report instead',
                block: true,
                leading: const Icon(Icons.add, size: 16),
                onPressed: () {
                  Navigator.of(context).pop();
                  MainShell.push(context, const UploadScreen());
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
