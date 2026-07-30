import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../providers/labs_providers.dart';
import '../../widgets/labs/biomarker_table.dart';
import '../../widgets/labs/upload_report_actions.dart';
import 'lab_report_screen.dart';
import 'main_shell.dart';

/// Adds a blood report. Mirrors `app/upload.tsx`.
///
/// A route of its own rather than a sheet, because it has three distinct states
/// — pick, parse, confirm — and a sheet that changes height twice while the user
/// waits reads as instability.
class UploadScreen extends ConsumerWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labs = ref.watch(labsProvider);

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
                    Text('Add a report', style: AppTextStyles.h3),
                    const SizedBox(height: 6),
                    Text(
                      'A PDF from your lab, or a photo of a printout. We pull '
                      'out every biomarker and flag each one against its '
                      'reference interval.',
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
          child: UploadReportActions(
            // Straight into the parsed report — the upload was the means, the
            // report is the thing the user came for.
            onUploaded: (report) {
              Navigator.of(context).pop();
              MainShell.push(context, LabReportScreen(reportId: report.id));
            },
          ),
        ),

        if (labs.reports.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space6,
              AppSpacing.space6,
              AppSpacing.space6,
              0,
            ),
            child: SectionHeader(
              title: 'Already on file',
              count: labs.reports.length,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space6,
            ),
            child: BiomarkerTable(
              report: labs.reports.first,
              flaggedOnly: true,
            ),
          ),
        ],

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space8,
            AppSpacing.space6,
            AppSpacing.space8,
            0,
          ),
          child: Text(
            'Reports stay on this device. Reference intervals are population '
            'defaults, not a diagnosis.',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardMeta.copyWith(fontSize: 10, height: 1.5),
          ),
        ),
      ],
    );
  }
}
