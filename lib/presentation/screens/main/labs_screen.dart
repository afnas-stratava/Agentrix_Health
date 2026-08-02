import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../domain/entities/labs/biomarker.dart';
import '../../../domain/entities/labs/lab_report.dart';
import '../../providers/insights_providers.dart';
import '../../providers/labs_providers.dart';
import '../../widgets/labs/ai_scan_progress.dart';
import '../../widgets/labs/biomarker_range_row.dart';
import 'gmail_import_screen.dart';
import 'lab_report_screen.dart';
import 'main_shell.dart';
import 'upload_screen.dart';

/// Blood work. Mirrors `app/(tabs)/labs.tsx`.
///
/// "Needs attention" is computed across the *latest value per biomarker*, not per
/// report — otherwise an old panel keeps flagging a marker the user has since
/// corrected.
class LabsScreen extends ConsumerWidget {
  const LabsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labs = ref.watch(labsProvider);
    final reports = labs.reports;
    final flagged =
        ref
            .watch(mergedBiomarkersProvider)
            .where((b) => b.flag.needsAttention)
            .toList()
          ..sort((a, b) => b.flag.severity.compareTo(a.flag.severity));

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
            spacing: AppSpacing.space3,
            children: [
              const ScreenBackButton(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Labs', style: AppTextStyles.screenTitle),
                    const SizedBox(height: 6),
                    Text(
                      reports.isEmpty
                          ? 'Upload a PDF or photo of a blood report'
                          : '${reports.length} report'
                                '${reports.length == 1 ? '' : 's'} on file',
                      style: AppTextStyles.cardBody,
                    ),
                  ],
                ),
              ),
              Row(
                spacing: AppSpacing.space2,
                children: [
                  AppButton(
                    label: 'Import',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    onPressed: () =>
                        MainShell.push(context, const GmailImportScreen()),
                  ),
                  AppButton(
                    label: 'Add',
                    size: AppButtonSize.sm,
                    leading: const Icon(Icons.add, size: 14),
                    onPressed: () =>
                        MainShell.push(context, const UploadScreen()),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (labs.parsing)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space6,
              AppSpacing.space6,
              AppSpacing.space6,
              0,
            ),
            child: const AiScanProgress(),
          ),

        if (flagged.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space6,
              AppSpacing.space6,
              AppSpacing.space6,
              AppSpacing.space3,
            ),
            child: Text(
              'OUTSIDE YOUR OPTIMAL BAND',
              style: AppTextStyles.tag.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.55,
                color: AppColors.muted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space6),
            child: _FlaggedCard(flagged: flagged),
          ),
        ],

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
              if (reports.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                  child: Text(
                    'ALL REPORTS',
                    style: AppTextStyles.tag.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.55,
                      color: AppColors.muted,
                    ),
                  ),
                ),

              if (reports.isEmpty && !labs.parsing)
                EmptyState(
                  icon: Icons.science_outlined,
                  title: 'No blood work yet',
                  body:
                      'Connect Gmail and we will find the lab reports already '
                      'sitting in your inbox — or add one manually. Either way '
                      'we extract every biomarker and line it up against your '
                      'daily telemetry.',
                  actionLabel: 'Import from Gmail',
                  onAction: () =>
                      MainShell.push(context, const GmailImportScreen()),
                )
              else
                Column(
                  spacing: AppSpacing.space3,
                  children: [
                    for (final report in reports) _ReportCard(report: report),
                  ],
                ),

              if (reports.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space4),
                  child: AppButton(
                    label: 'Add another report',
                    size: AppButtonSize.sm,
                    block: true,
                    leading: const Icon(Icons.add, size: 14),
                    onPressed: () =>
                        MainShell.push(context, const UploadScreen()),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlaggedCard extends StatelessWidget {
  const _FlaggedCard({required this.flagged});

  final List<Biomarker> flagged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final biomarker in flagged)
            BiomarkerRangeRow(
              biomarker: biomarker,
              isLast: biomarker == flagged.last,
            ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final LabReport report;

  @override
  Widget build(BuildContext context) {
    final date = report.collectedAt ?? report.uploadedAt;
    final flagged = report.flagged.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: PressableScale(
        scaleTo: 0.99,
        semanticLabel:
            '${report.panelName ?? 'Blood panel'}, '
            '${DateFormat('d MMMM yyyy').format(date)}',
        semanticHint: 'Opens the full report',
        onTap: () =>
            MainShell.push(context, LabReportScreen(reportId: report.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Row(
            spacing: AppSpacing.space3,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 17,
                  color: AppColors.brand,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.panelName ?? 'Blood panel',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('d MMM yyyy').format(date)} · '
                      '${report.labName ?? report.source.label} · '
                      '${report.biomarkers.length} markers'
                      '${flagged == 0 ? '' : ' · $flagged to watch'}',
                      style: AppTextStyles.cardMeta.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 15, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
