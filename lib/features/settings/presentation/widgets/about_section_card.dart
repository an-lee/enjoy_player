/// About card — app identity, version, and open-source link.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:enjoy_player/core/application/app_links.dart';
import 'package:enjoy_player/core/diagnostics/diagnostic_export_flow.dart';
import 'package:enjoy_player/core/diagnostics/diagnostics_verbose_provider.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_logo.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/developer_contact_sheet.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_row.dart';
import 'package:enjoy_player/features/update/application/update_controller.dart';
import 'package:enjoy_player/features/update/presentation/update_notification_dot.dart';
import 'package:enjoy_player/features/update/presentation/update_prompt_host.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class AboutSectionCard extends ConsumerStatefulWidget {
  const AboutSectionCard({super.key});

  @override
  ConsumerState<AboutSectionCard> createState() => _AboutSectionCardState();
}

class _AboutSectionCardState extends ConsumerState<AboutSectionCard> {
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  Future<void> _openGitHub(BuildContext context) async {
    final uri = Uri.parse(kEnjoyPlayerGitHubUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppNotice.error(
        context,
        AppLocalizations.of(context)!.playerOpenGenericError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Horizontal inset comes from the Settings hub page metrics — same as
    // [SettingsSectionCard]. Do not add a second gutter here.
    return Material(
      color: cs.surfaceContainerLow.withValues(alpha: 0.88),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusXl),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surfaceContainerHigh.withValues(alpha: 0.38),
              cs.surfaceContainerLow.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(t.radiusXl),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [t.gradientStart, t.gradientEnd],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(t.space16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const EnjoyLogo(size: 52),
                          SizedBox(width: t.space16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.appTitle,
                                        style: tt.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    FutureBuilder<PackageInfo>(
                                      future: _packageInfoFuture,
                                      builder: (context, snapshot) {
                                        final version = snapshot.data?.version;
                                        if (version == null ||
                                            version.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
                                        return _AboutVersionPill(
                                          label: l10n.settingsAboutVersion(
                                            version,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                SizedBox(height: t.space8),
                                Text(
                                  l10n.settingsAboutSubtitle,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: t.space12),
                                Text(
                                  l10n.settingsAboutMadeWithCare,
                                  style: tt.labelMedium?.copyWith(
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.88,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: t.space16,
                      endIndent: t.space16,
                      color: cs.outlineVariant.withValues(alpha: 0.18),
                    ),
                    SettingsRow(
                      leadingIcon: Icons.system_update_alt_rounded,
                      title: l10n.settingsCheckForUpdatesTitle,
                      subtitle: l10n.settingsCheckForUpdatesSubtitle,
                      valueBadge: ref.watch(updateAvailableBadgeProvider)
                          ? UpdateNotificationDot(
                              semanticsLabel:
                                  l10n.updateAvailableBadgeSemantics,
                            )
                          : null,
                      onTap: () => runManualUpdateCheck(context, ref),
                      responsive: false,
                    ),
                    Divider(
                      height: 1,
                      indent: t.space16,
                      endIndent: t.space16,
                      color: cs.outlineVariant.withValues(alpha: 0.18),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        t.space20,
                        t.space12,
                        t.space8,
                        t.space8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: Icon(
                                    Icons.bug_report_outlined,
                                    size: 22,
                                    color: cs.primary.withValues(alpha: 0.92),
                                  ),
                                ),
                              ),
                              SizedBox(width: t.space16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.settingsDiagnosticsLoggingTitle,
                                      style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    SizedBox(height: t.space4),
                                    Text(
                                      l10n.settingsDiagnosticsLoggingSubtitle,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.86,
                                        ),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ref
                                  .watch(diagnosticsVerboseProvider)
                                  .when(
                                    data: (enabled) => Switch.adaptive(
                                      value: enabled,
                                      onChanged: (value) {
                                        unawaited(
                                          ref
                                              .read(
                                                diagnosticsVerboseProvider
                                                    .notifier,
                                              )
                                              .setEnabled(value),
                                        );
                                      },
                                    ),
                                    loading: () => const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    error: (_, _) => const SizedBox.shrink(),
                                  ),
                            ],
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                              left: 44 + t.space16 + t.space12,
                              top: t.space4,
                            ),
                            child: Text(
                              l10n.settingsDiagnosticsPrivacyNote,
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.78,
                                ),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: t.space16,
                      endIndent: t.space16,
                      color: cs.outlineVariant.withValues(alpha: 0.18),
                    ),
                    SettingsRow(
                      leadingIcon: Icons.archive_outlined,
                      title: l10n.settingsDiagnosticsExportTitle,
                      subtitle: l10n.settingsDiagnosticsExportSubtitle,
                      onTap: () => exportDiagnosticReport(context),
                      responsive: false,
                    ),
                    Divider(
                      height: 1,
                      indent: t.space16,
                      endIndent: t.space16,
                      color: cs.outlineVariant.withValues(alpha: 0.18),
                    ),
                    SettingsRow(
                      leadingIcon: Icons.code_rounded,
                      title: l10n.settingsAboutOpenSourceTitle,
                      subtitle: l10n.settingsAboutOpenSourceSubtitle,
                      showChevron: false,
                      trailing: Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                      onTap: () => _openGitHub(context),
                      responsive: false,
                    ),
                    Divider(
                      height: 1,
                      indent: t.space16,
                      endIndent: t.space16,
                      color: cs.outlineVariant.withValues(alpha: 0.18),
                    ),
                    SettingsRow(
                      leadingIcon: Icons.forum_outlined,
                      title: l10n.settingsAboutContactTitle,
                      subtitle: l10n.settingsAboutContactSubtitle,
                      onTap: () => showDeveloperContactSheet(context),
                      responsive: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutVersionPill extends StatelessWidget {
  const _AboutVersionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space8, vertical: t.space4),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(t.radiusFull),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onPrimaryContainer,
          letterSpacing: 0.02,
        ),
      ),
    );
  }
}
