import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/labs/biomarker.dart';
import '../../../domain/entities/labs/lab_report.dart';
import '../../providers/insights_providers.dart';
import '../../providers/labs_providers.dart';
import '../../widgets/labs/biomarker_table.dart';
import '../../widgets/labs/upload_report_actions.dart';
import 'lab_report_screen.dart';
import 'main_shell.dart';

/// Blood work.
///
/// Leads with what is outside the *optimal* band across every report, because
/// that is the set a lab report prints in black and this app exists to surface.
/// Individual reports sit below as history.
class LabsScreen extends ConsumerWidget {
  const LabsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labs = ref.watch(labsProvider);
    final merged = ref.watch(mergedBiomarkersProvider);
    final flagged = merged.where((b) => b.flag.needsAttention).toList()
      ..sort((a, b) => b.flag.severity.compareTo(a.flag.severity));

    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.space1,
        bottom: MainShell.bottomInsetFor(context),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                merged.isEmpty
                    ? 'No results yet'
                    : '${merged.length} markers across '
                          '${labs.reports.length} '
                          'report${labs.reports.length == 1 ? '' : 's'}',
                style: AppTextStyles.cardMeta.copyWith(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text('Blood work', style: AppTextStyles.h3),
            ],
          ),
        ),

        if (labs.reports.isEmpty)
          _Section(delay: 20, child: const _EmptyLabs())
        else ...[
          if (flagged.isNotEmpty)
            _Section(
              delay: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Outside your optimal band',
                    count: flagged.length,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                    child: Text(
                      'Most of these are "normal" on the printed report. The '
                      'optimal band is narrower than the lab interval, and the '
                      'gap is where the useful signal lives.',
                      style: AppTextStyles.cardBody.copyWith(height: 1.45),
                    ),
                  ),
                  _FlaggedList(flagged: flagged),
                ],
              ),
            )
          else
            _Section(delay: 20, child: const _AllOptimal()),

          _Section(
            delay: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'Reports', count: labs.reports.length),
                Column(
                  spacing: AppSpacing.space2,
                  children: [
                    for (final report in labs.reports)
                      _ReportCard(report: report),
                  ],
                ),
              ],
            ),
          ),

          _Section(delay: 120, child: const UploadReportActions()),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space5,
        AppSpacing.space5,
        0,
      ),
      child: FadeIn(delay: Duration(milliseconds: delay), child: child),
    );
  }
}

class _EmptyLabs extends StatelessWidget {
  const _EmptyLabs();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.space5),
          decoration: BoxDecoration(
            color: AppColors.brand50,
            border: Border.all(color: AppColors.brand200),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.science_outlined,
                size: 20,
                color: AppColors.brand,
              ),
              const SizedBox(height: AppSpacing.space3),
              Text(
                'Add a blood panel',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Your wearable can tell you that recovery is down. Only blood '
                'work can tell you why. Once a panel is here, the insights '
                'screen starts looking for findings where the two agree.',
                style: AppTextStyles.cardBody.copyWith(
                  height: 1.5,
                  color: AppColors.brand800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        const UploadReportActions(),
      ],
    );
  }
}

class _AllOptimal extends StatelessWidget {
  const _AllOptimal();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.brand50,
        border: Border.all(color: AppColors.brand200),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        spacing: AppSpacing.space3,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: AppColors.brand,
          ),
          Expanded(
            child: Text(
              'Every marker in your panel sits inside its optimal band — not '
              'just inside the lab range.',
              style: AppTextStyles.cardBody.copyWith(
                height: 1.45,
                color: AppColors.brand800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlaggedList extends StatelessWidget {
  const _FlaggedList({required this.flagged});

  final List<Biomarker> flagged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final biomarker in flagged)
            _FlaggedRow(
              biomarker: biomarker,
              isLast: biomarker == flagged.last,
            ),
        ],
      ),
    );
  }
}

class _FlaggedRow extends StatelessWidget {
  const _FlaggedRow({required this.biomarker, required this.isLast});

  final Biomarker biomarker;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colour = flagColour(biomarker.flag);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.hairline, width: 1),
              ),
      ),
      child: Row(
        spacing: AppSpacing.space3,
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  biomarker.displayName,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                Text(
                  biomarker.range.source == ReferenceSource.lab
                      ? 'Against your lab’s own interval'
                      : 'Against our reference interval',
                  style: AppTextStyles.cardMeta.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                biomarker.valueWithUnit,
                style: AppTextStyles.h6.copyWith(
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
              Text(
                biomarker.flag.label,
                style: AppTextStyles.cardMeta.copyWith(
                  fontSize: 10,
                  color: colour,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
      ),
      clipBehavior: Clip.antiAlias,
      child: PressableScale(
        scaleTo: 0.99,
        semanticLabel: '${report.panelName ?? 'Blood panel'}, '
            '${DateFormat('d MMMM yyyy').format(date)}',
        semanticHint: 'Opens the full report',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LabReportScreen(reportId: report.id),
          ),
        ),
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
              const Icon(
                Icons.chevron_right,
                size: 15,
                color: AppColors.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
