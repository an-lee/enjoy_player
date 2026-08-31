/// Debug screen to exercise Enjoy AI HTTP APIs (ASR, chat, translation, dictionary).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/features/ai/application/ai_byok_error_mapping.dart';
import 'package:enjoy_player/features/ai/application/ai_modality_config_controller.dart';
import 'package:enjoy_player/features/ai/application/ai_services.dart';
import 'package:enjoy_player/features/ai/domain/byok_not_configured_failure.dart';
import 'package:enjoy_player/features/ai/domain/chat_message.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_request.dart';
import 'package:enjoy_player/features/ai/domain/models/assessment_request.dart';
import 'package:enjoy_player/features/ai/presentation/ai_playground_azure_error.dart';
import 'package:enjoy_player/features/ai/presentation/ai_playground_provider_label.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:logging/logging.dart';

final Logger _log = logNamed('ai.playground');

class AiPlaygroundScreen extends ConsumerStatefulWidget {
  const AiPlaygroundScreen({super.key});

  @override
  ConsumerState<AiPlaygroundScreen> createState() => _AiPlaygroundScreenState();
}

class _AiPlaygroundScreenState extends ConsumerState<AiPlaygroundScreen> {
  final _systemCtrl = TextEditingController();
  final _userCtrl = TextEditingController(
    text: 'Hello, summarize in one line.',
  );
  final _translateSourceCtrl = TextEditingController(text: 'en');
  final _translateTargetCtrl = TextEditingController(text: 'zh');
  final _translateTextCtrl = TextEditingController(text: 'Good morning.');
  final _dictWordCtrl = TextEditingController(text: 'run');
  final _dictSourceCtrl = TextEditingController(text: 'en');
  final _dictTargetCtrl = TextEditingController(text: 'zh');
  final _assessRefCtrl = TextEditingController(text: 'Hello world.');
  final _assessLangCtrl = TextEditingController(text: 'en');

  String _output = '';
  Uint8List? _pickedAudio;
  String _pickedName = 'audio.wav';

  @override
  void dispose() {
    _systemCtrl.dispose();
    _userCtrl.dispose();
    _translateSourceCtrl.dispose();
    _translateTargetCtrl.dispose();
    _translateTextCtrl.dispose();
    _dictWordCtrl.dispose();
    _dictSourceCtrl.dispose();
    _dictTargetCtrl.dispose();
    _assessRefCtrl.dispose();
    _assessLangCtrl.dispose();
    super.dispose();
  }

  void _append(String line) {
    setState(() {
      _output = _output.isEmpty ? line : '$_output\n\n$line';
    });
  }

  String _err(Object e) {
    if (e is ByokNotConfiguredFailure) {
      final l10n = AppLocalizations.of(context)!;
      return formatByokNotConfiguredWithSettingsHint(e, l10n);
    }
    if (e is AppFailure) return e.message;
    return e.toString();
  }

  void _maybePromptByokSettings(Object e) {
    if (e is! ByokNotConfiguredFailure || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    // Shared notice instead of a raw SnackBar: keeps the message full width and
    // the CTA styling consistent with every other AI error surface.
    AppNotice.warning(
      context,
      formatByokNotConfiguredMessage(e, l10n),
      action: SnackBarAction(
        label: l10n.settingsAiProvidersTileTitle,
        onPressed: () => context.push(aiProvidersSettingsPath),
      ),
    );
  }

  Future<void> _pickAudio() async {
    final l10n = AppLocalizations.of(context)!;
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['wav', 'mp3', 'm4a', 'webm', 'ogg', 'flac'],
    );
    if (!mounted) return;
    if (f == null) return;
    Uint8List? bytes;
    try {
      bytes = await f.readAsBytes();
    } on Object {
      bytes = null;
    }
    final path = f.path;
    if (bytes == null && path != null && path.isNotEmpty) {
      bytes = await File(path).readAsBytes();
    }
    if (bytes == null) {
      _append('${l10n.error}: could not read file bytes.');
      return;
    }
    setState(() {
      _pickedAudio = bytes;
      _pickedName = f.name;
    });
    _append('Selected: ${f.name} (${bytes.length} bytes)');
  }

  Future<void> _runAsr() async {
    final l10n = AppLocalizations.of(context)!;
    final bytes = _pickedAudio;
    if (bytes == null) {
      _append('${l10n.error}: pick an audio file first.');
      return;
    }
    try {
      final result = await ref
          .read(asrServiceProvider)
          .transcribe(AsrRequest(audioBytes: bytes, filename: _pickedName));
      _append('ASR text:\n${result.text}');
    } catch (e, st) {
      _log.warning('ASR failed', e, st);
      _maybePromptByokSettings(e);
      _append('ASR ${_err(e)}');
    }
  }

  Future<void> _runChat() async {
    try {
      final messages = <ChatMessage>[
        if (_systemCtrl.text.trim().isNotEmpty)
          ChatMessage(
            role: ChatMessage.roleSystem,
            content: _systemCtrl.text.trim(),
          ),
        ChatMessage(role: ChatMessage.roleUser, content: _userCtrl.text.trim()),
      ];
      final reply = await ref
          .read(chatServiceProvider)
          .complete(messages: messages);
      _append('Chat reply:\n$reply');
    } catch (e, st) {
      _log.warning('Chat failed', e, st);
      _maybePromptByokSettings(e);
      _append('Chat ${_err(e)}');
    }
  }

  Future<void> _runTranslate() async {
    try {
      final r = await ref
          .read(translationServiceProvider)
          .translate(
            text: _translateTextCtrl.text.trim(),
            sourceLanguage: _translateSourceCtrl.text.trim(),
            targetLanguage: _translateTargetCtrl.text.trim(),
          );
      _append('Translation:\n${r.translatedText}');
    } catch (e, st) {
      _log.warning('Translate failed', e, st);
      _maybePromptByokSettings(e);
      _append('Translate ${_err(e)}');
    }
  }

  Future<void> _runDictionary() async {
    try {
      final r = await ref
          .read(dictionaryServiceProvider)
          .lookup(
            word: _dictWordCtrl.text.trim(),
            sourceLanguage: _dictSourceCtrl.text.trim(),
            targetLanguage: _dictTargetCtrl.text.trim(),
          );
      final buf = StringBuffer()
        ..writeln('${r.word} (${r.sourceLanguage} → ${r.targetLanguage})');
      if (r.lemma != null) buf.writeln('lemma: ${r.lemma}');
      if (r.ipa != null) buf.writeln('ipa: ${r.ipa}');
      for (var i = 0; i < r.senses.length; i++) {
        final s = r.senses[i];
        buf.writeln('\n[$i] ${s.partOfSpeech ?? ''}');
        buf.writeln(s.definition);
        if (s.translation != null) buf.writeln('⇄ ${s.translation}');
      }
      _append(buf.toString());
    } catch (e, st) {
      _log.warning('Dictionary failed', e, st);
      _maybePromptByokSettings(e);
      _append('Dictionary ${_err(e)}');
    }
  }

  Future<void> _runAssessment() async {
    final l10n = AppLocalizations.of(context)!;
    final bytes = _pickedAudio;
    if (bytes == null) {
      _append(
        '${l10n.error}: pick a WAV (or other) file first; assessment uses the same pick as ASR.',
      );
      return;
    }
    final refText = _assessRefCtrl.text.trim();
    if (refText.isEmpty) {
      _append('${l10n.error}: enter reference text.');
      return;
    }
    try {
      final r = await ref
          .read(assessmentServiceProvider)
          .assess(
            AssessmentRequest(
              audioBytes: bytes,
              referenceText: refText,
              language: _assessLangCtrl.text.trim(),
            ),
          );
      final scores = r.detail.primaryScores;
      final buf = StringBuffer('Pronunciation assessment\n');
      if (scores != null) {
        buf.writeln(
          'PronScore: ${scores.pronScore.toStringAsFixed(1)} · '
          'Accuracy: ${scores.accuracyScore.toStringAsFixed(1)} · '
          'Fluency: ${scores.fluencyScore.toStringAsFixed(1)} · '
          'Completeness: ${scores.completenessScore.toStringAsFixed(1)}',
        );
        if (scores.prosodyScore != null) {
          buf.writeln('Prosody: ${scores.prosodyScore!.toStringAsFixed(1)}');
        }
      }
      buf.writeln('Display: ${r.detail.displayText}');
      final words = r.detail.nBest.isEmpty ? null : r.detail.nBest.first.words;
      if (words != null && words.isNotEmpty) {
        buf.writeln('\nWords:');
        for (final w in words) {
          buf.writeln(
            '  · ${w.word}  acc=${w.pronunciationAssessment.accuracyScore.toStringAsFixed(0)}  '
            '${w.pronunciationAssessment.errorType}',
          );
        }
      }
      _append(buf.toString());
    } catch (e, st) {
      _log.warning('Assessment failed', e, st);
      _maybePromptByokSettings(e);
      if (isAzureSpeechException(e)) {
        _append('Assessment ${formatAzureSpeechError(e)}');
      } else {
        _append('Assessment ${_err(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final configs = ref.watch(aiModalityConfigCtrlProvider);
    final llmLabel = formatPlaygroundProviderLabel(l10n, configs.llm);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiPlaygroundTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.aiPlaygroundIntro, style: tt.bodyMedium),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.aiPlaygroundActiveProviders,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _ProviderRow(
                    label: l10n.settingsAiProvidersModalityLlm,
                    providerLabel: llmLabel,
                  ),
                  _ProviderRow(
                    label: l10n.settingsAiProvidersModalityAsr,
                    providerLabel: formatPlaygroundProviderLabel(
                      l10n,
                      configs.asr,
                    ),
                  ),
                  _ProviderRow(
                    label: l10n.settingsAiProvidersModalityTts,
                    providerLabel: formatPlaygroundProviderLabel(
                      l10n,
                      configs.tts,
                    ),
                  ),
                  _ProviderRow(
                    label: l10n.settingsAiProvidersModalityAssessment,
                    providerLabel: formatPlaygroundProviderLabel(
                      l10n,
                      configs.assessment,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(aiProvidersSettingsPath),
                      child: Text(l10n.settingsAiProvidersTileTitle),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(
            text: l10n.aiPlaygroundSectionAsr,
            providerLabel: formatPlaygroundProviderLabel(l10n, configs.asr),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _pickAudio,
                child: Text(l10n.aiPlaygroundPickAudio),
              ),
              FilledButton(
                onPressed: _runAsr,
                child: Text(l10n.aiPlaygroundTranscribe),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            text: l10n.aiPlaygroundSectionChat,
            providerLabel: llmLabel,
          ),
          TextField(
            controller: _systemCtrl,
            decoration: InputDecoration(labelText: l10n.aiPlaygroundChatSystem),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _userCtrl,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.aiPlaygroundChatUser),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _runChat,
              child: Text(l10n.aiPlaygroundSendChat),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            text: l10n.aiPlaygroundSectionTranslation,
            providerLabel: llmLabel,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _translateSourceCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.aiPlaygroundTranslateSource,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _translateTargetCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.aiPlaygroundTranslateTarget,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _translateTextCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.aiPlaygroundTranslateText,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: _runTranslate,
              child: Text(l10n.aiPlaygroundTranslate),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            text: l10n.aiPlaygroundSectionDictionary,
            providerLabel: llmLabel,
          ),
          TextField(
            controller: _dictWordCtrl,
            decoration: InputDecoration(labelText: l10n.aiPlaygroundDictWord),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dictSourceCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.aiPlaygroundDictSource,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _dictTargetCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.aiPlaygroundDictTarget,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: _runDictionary,
              child: Text(l10n.aiPlaygroundDictLookup),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            text: l10n.aiPlaygroundSectionTtsAssessment,
            providerLabel: formatPlaygroundProviderLabel(
              l10n,
              configs.assessment,
            ),
          ),
          Text(l10n.aiPlaygroundAssessmentTtsNote, style: tt.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _assessRefCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.aiPlaygroundAssessmentReference,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _assessLangCtrl,
            decoration: InputDecoration(
              labelText: l10n.aiPlaygroundAssessmentLanguage,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: _runAssessment,
              child: Text(l10n.aiPlaygroundAssess),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _SectionTitle(text: l10n.aiPlaygroundOutput)),
              TextButton(
                onPressed: () => setState(() => _output = ''),
                child: Text(l10n.aiPlaygroundClearOutput),
              ),
            ],
          ),
          SelectableText(_output.isEmpty ? '—' : _output, style: tt.bodySmall),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, this.providerLabel});

  final String text;
  final String? providerLabel;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (providerLabel != null) ...[
            const SizedBox(width: 8),
            Text(
              providerLabel!,
              style: tt.labelMedium?.copyWith(color: cs.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.label, required this.providerLabel});

  final String label;
  final String providerLabel;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: tt.bodyMedium)),
          Text(
            providerLabel,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
