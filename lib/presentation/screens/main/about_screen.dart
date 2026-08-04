import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_info.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/surface_card.dart';
import 'main_shell.dart';

String get _healthStoreName => Platform.isAndroid ? 'Health Connect' : 'Apple Health';

/// About, and the honest version of "what happens to my data".
///
/// The data section is not decoration. An app that reads HealthKit and then
/// sends anything derived from it to a third party has to say so somewhere the
/// user can find before they are asked to connect — that is both App Review
/// guideline 5.1.3 and the only defensible thing to do with blood work. This
/// screen is that place, and the privacy policy is the long form of it.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    Text('About', style: AppTextStyles.h3),
                    const SizedBox(height: 6),
                    Text(
                      '${AppInfo.appName} ${AppInfo.version}',
                      style: AppTextStyles.cardBody.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space5),
        _Section(
          label: 'What this app does',
          child: _Body(
            'Agentrix Health reads your sleep, activity, resting heart rate '
            'and heart-rate variability from $_healthStoreName, and pairs them '
            'with the blood work you upload. It scores your readiness each '
            'morning, tracks what you eat and drink, and points out where the '
            'two lines up — a biomarker that moves with a habit, a pattern '
            'worth taking to a clinician.',
          ),
        ),
        const _Section(
          label: 'Not a medical device',
          child: _Notice(
            'Agentrix Health is an informational tool. It does not diagnose, '
            'treat or prevent any condition, and nothing it shows you is '
            'medical advice. Reference ranges vary between laboratories, and '
            'a result only means something in the context of your history. '
            'Always take a concerning value to a qualified clinician.',
          ),
        ),
        _Section(
          label: 'What leaves your device',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Body(
                'Most of your data stays on this phone. These are the '
                'exceptions, and each happens only when you use the feature '
                'it belongs to:',
              ),
              SizedBox(height: AppSpacing.space4),
              _DataRow(
                icon: Icons.description_outlined,
                title: 'Lab reports you upload',
                detail:
                    'The document is sent to Google Gemini to be read into '
                    'biomarker values, then stored on this device.',
              ),
              _DataRow(
                icon: Icons.forum_outlined,
                title: 'Questions you ask the assistant',
                detail:
                    'Your message is sent to Google Gemini together with a '
                    'summary of your readiness, food log and latest results, '
                    'so the answer is about you rather than generic.',
              ),
              _DataRow(
                icon: Icons.place_outlined,
                title: 'Your location, while searching for food',
                detail:
                    'Sent to Google Places to find restaurants nearby. It is '
                    'used for that search and never stored.',
              ),
              _DataRow(
                icon: Icons.cloud_outlined,
                title: 'Your profile',
                detail:
                    'Name, goal and body measurements are stored against your '
                    'account so they follow you to a new phone.',
                last: true,
              ),
              SizedBox(height: AppSpacing.space4),
              _Body(
                'Your $_healthStoreName readings are never uploaded in raw '
                'form, and none of your data is sold, used for advertising or '
                'used to train anyone’s models.',
              ),
            ],
          ),
        ),
        _Section(
          label: 'Legal and support',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LinkTile(
                icon: Icons.shield_outlined,
                label: 'Privacy policy',
                onTap: () => _open(context, Uri.parse(AppInfo.privacyPolicyUrl)),
              ),
              _LinkTile(
                icon: Icons.gavel_outlined,
                label: 'Terms of service',
                onTap: () => _open(context, Uri.parse(AppInfo.termsUrl)),
              ),
              _LinkTile(
                icon: Icons.mail_outline,
                label: 'Contact support',
                detail: AppInfo.supportEmail,
                onTap: () => _open(
                  context,
                  AppInfo.supportMailto(platform: _platformName),
                ),
              ),
              _LinkTile(
                icon: Icons.article_outlined,
                label: 'Open-source licences',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppInfo.appName,
                  applicationVersion: AppInfo.version,
                ),
                last: true,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space6,
            AppSpacing.space8,
            AppSpacing.space6,
            0,
          ),
          child: Text(
            '© ${AppInfo.publisher}. ${AppInfo.appName} '
            '${AppInfo.version}.',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }

  static String get _platformName {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    return Platform.operatingSystem;
  }

  /// Surfaces a failure rather than swallowing it. A tap on "Privacy policy"
  /// that does nothing at all reads as a frozen app; it also hides the case
  /// this is most likely to hit in practice, which is a placeholder URL that
  /// was never pointed at a real page.
  static Future<void> _open(BuildContext context, Uri uri) async {
    HapticFeedback.selectionClick();
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open ${uri.host.isEmpty ? uri : uri.host}')),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space1,
              AppSpacing.space5,
              AppSpacing.space1,
              AppSpacing.space3,
            ),
            child: Text(
              label.toUpperCase(),
              style: AppTextStyles.tag.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.55,
                color: AppColors.muted,
              ),
            ),
          ),
          SurfaceCard(child: child),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTextStyles.cardBody.copyWith(fontSize: 13, height: 1.55),
  );
}

/// The medical disclaimer, given the visual weight of a warning rather than
/// being buried in body copy.
class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.space3,
      children: [
        const Icon(
          Icons.info_outline,
          size: 18,
          color: AppColors.borderline,
        ),
        Expanded(child: _Body(text)),
      ],
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.space3),
      margin: EdgeInsets.only(bottom: last ? 0 : AppSpacing.space3),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space3,
        children: [
          Icon(icon, size: 18, color: AppColors.brand),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppTextStyles.cardBody.copyWith(
                    fontSize: 12,
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

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.space3),
          margin: EdgeInsets.only(bottom: last ? 0 : AppSpacing.space3),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            spacing: AppSpacing.space3,
            children: [
              Icon(icon, size: 18, color: AppColors.brand),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 17,
                color: AppColors.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
