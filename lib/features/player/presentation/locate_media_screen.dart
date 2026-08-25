/// Prompts the user to pick a local file when synced metadata has no path on
/// this device.
library;

import 'package:cross_file/cross_file.dart';
import 'package:enjoy_player/core/presentation/loading_icon.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/data/files/media_resolver.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/domain/media_relocate_exception.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

String _formatExpectedSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)} GB';
}

class LocateMediaScreen extends ConsumerStatefulWidget {
  const LocateMediaScreen({required this.info, super.key});

  final MediaNeedsRelocateException info;

  @override
  ConsumerState<LocateMediaScreen> createState() => _LocateMediaScreenState();
}

class _LocateMediaScreenState extends ConsumerState<LocateMediaScreen> {
  bool _working = false;

  Future<void> _onChooseFile() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _working = true);
    try {
      final allowed = widget.info.kind == MediaKind.video
          ? kFilePickerLocalVideoExtensions
          : kFilePickerLocalAudioExtensions;
      final pick = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: allowed,
      );
      if (pick == null) return;
      final path = pick.path;
      if (path == null || path.isEmpty) return;
      if (!mounted) return;

      final pickedName = pick.name;
      final extOk = widget.info.kind == MediaKind.video
          ? isVideoFileName(pickedName)
          : isAudioFileName(pickedName);
      if (!extOk) {
        if (!mounted) return;
        AppNotice.error(context, l10n.importUnsupportedFileType);
        return;
      }

      try {
        await ref
            .read(playerControllerProvider.notifier)
            .relocateAndOpen(widget.info.mediaId, XFile(path, name: pick.name));
      } on AppFailure {
        if (!mounted) return;
        AppNotice.error(context, l10n.mediaLocateHashMismatch);
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final sizeLabel = _formatExpectedSize(widget.info.expectedSize);
    final sizeLine = sizeLabel.isEmpty
        ? l10n.mediaLocateSizeUnknown
        : l10n.mediaLocateExpectedSize(sizeLabel);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: _working ? null : () => context.pop(),
        ),
        title: Text(l10n.mediaLocateTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.info.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                sizeLine,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.mediaLocateBody,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _working ? null : _onChooseFile,
                icon: _working
                    ? LoadingIcon(size: 20, color: cs.onPrimary)
                    : const Icon(Icons.folder_open),
                label: Text(
                  _working ? l10n.importingMedia : l10n.mediaLocateChooseFile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
