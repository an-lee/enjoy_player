/// Edit profile: username, avatar, read-only Enjoy ID / email / Mixin ID.
library;

import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/presentation/loading_icon.dart';
import 'package:enjoy_player/core/layout/enjoy_page_kind.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_page.dart';
import 'package:enjoy_player/core/utils/avatar_url.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/avatar_pick_constraints.dart';
import 'package:enjoy_player/features/auth/domain/update_profile_request.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/profile_identity_row.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _saving = false;
  String? _hydratedForProfileId;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarFilename;
  String? _pendingAvatarContentType;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _applyProfile(UserProfile p) {
    _name.text = p.name;
  }

  void _clearPendingAvatar() {
    _pendingAvatarBytes = null;
    _pendingAvatarFilename = null;
    _pendingAvatarContentType = null;
  }

  Future<void> _pickAvatar(AppLocalizations l10n) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (file == null) return;
    Uint8List? bytes;
    try {
      bytes = await file.readAsBytes();
    } on Object {
      bytes = null;
    }
    if (bytes == null || bytes.isEmpty) {
      if (mounted) AppNotice.error(context, l10n.profileAvatarEmpty);
      return;
    }
    final failure = validateAvatarPick(
      byteLength: bytes.length,
      filename: file.name,
      contentType: avatarContentTypeForFilename(file.name),
    );
    if (failure != null) {
      if (!mounted) return;
      final message = switch (failure) {
        AvatarPickFailure.empty => l10n.profileAvatarEmpty,
        AvatarPickFailure.tooLarge => l10n.profileAvatarTooLarge,
        AvatarPickFailure.unsupportedType => l10n.profileAvatarUnsupportedType,
      };
      AppNotice.error(context, message);
      return;
    }
    setState(() {
      _pendingAvatarBytes = bytes;
      _pendingAvatarFilename = file.name;
      _pendingAvatarContentType = avatarContentTypeForFilename(file.name);
    });
  }

  Future<void> _save(UserProfile profile, AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    final nameChanged = name != profile.name;
    final hasAvatar = _pendingAvatarBytes != null;
    if (!nameChanged && !hasAvatar) {
      if (mounted) await Navigator.of(context).maybePop();
      return;
    }

    setState(() => _saving = true);
    // True only while the avatar upload step is in flight / failed.
    var failedOnAvatarStep = false;
    try {
      if (nameChanged) {
        await ref
            .read(authCtrlProvider.notifier)
            .updateProfile(UpdateProfileRequest(name: name));
      }
      if (hasAvatar) {
        failedOnAvatarStep = true;
        await ref
            .read(authCtrlProvider.notifier)
            .updateAvatar(
              bytes: _pendingAvatarBytes!,
              filename: _pendingAvatarFilename ?? 'avatar.jpg',
              contentType: _pendingAvatarContentType,
            );
        // Only discard local preview after a successful upload.
        _clearPendingAvatar();
        failedOnAvatarStep = false;
      }
      if (mounted) {
        AppNotice.success(context, l10n.profileSaveSuccess);
        await Navigator.of(context).maybePop();
      }
    } on AuthFailure catch (e) {
      if (mounted) {
        final fallback = failedOnAvatarStep
            ? l10n.profileAvatarUploadFailed
            : l10n.errorGenericLoadFailed;
        AppNotice.error(context, e.message.isNotEmpty ? e.message : fallback);
      }
    } catch (_) {
      if (mounted) {
        AppNotice.error(
          context,
          failedOnAvatarStep
              ? l10n.profileAvatarUploadFailed
              : l10n.errorGenericLoadFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authCtrlProvider);

    return EnjoyPage(
      kind: EnjoyPageKind.form,
      title: l10n.profileEditTitle,
      showBack: true,
      body: (context, metrics) => auth.when(
        data: (state) {
          if (state is! AuthSignedIn) {
            return Center(child: Text(l10n.authSignInTitle));
          }
          final p = state.profile;
          if (_hydratedForProfileId != p.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _applyProfile(p);
              setState(() => _hydratedForProfileId = p.id);
            });
          }

          final mixinValue = (p.mixinId != null && p.mixinId!.trim().isNotEmpty)
              ? p.mixinId!.trim()
              : l10n.profileMixinNotLinked;
          final mixinCopyable =
              p.mixinId != null && p.mixinId!.trim().isNotEmpty;

          final remoteAvatar = rasterAvatarUrl(p.avatarUrl);
          ImageProvider? avatarImage;
          if (_pendingAvatarBytes != null) {
            avatarImage = MemoryImage(_pendingAvatarBytes!);
          } else if (remoteAvatar != null && remoteAvatar.isNotEmpty) {
            avatarImage = CachedNetworkImageProvider(remoteAvatar);
          }

          return SingleChildScrollView(
            padding: metrics.padding(top: t.space16, bottom: t.space32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 48,
                                  color: cs.primary,
                                )
                              : null,
                        ),
                        SizedBox(height: t.space12),
                        TextButton.icon(
                          onPressed: _saving ? null : () => _pickAvatar(l10n),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(l10n.profileChangeAvatar),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: t.space24),
                  TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: l10n.profileFieldName,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.profileFieldRequired
                        : null,
                  ),
                  SizedBox(height: t.space16),
                  ProfileIdentityRow(
                    label: l10n.profileFieldEnjoyId,
                    value: p.id,
                    copyable: true,
                  ),
                  ProfileIdentityRow(
                    label: l10n.profileFieldEmail,
                    value: p.email,
                    copyable: p.email.isNotEmpty,
                  ),
                  ProfileIdentityRow(
                    label: l10n.profileFieldMixinId,
                    value: mixinValue,
                    copyable: mixinCopyable,
                  ),
                  SizedBox(height: t.space32),
                  EnjoyButton.primary(
                    onPressed: _saving ? null : () => _save(p, l10n),
                    child: _saving
                        ? const LoadingIcon(size: 22)
                        : Text(l10n.profileSave),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorGenericLoadFailed)),
      ),
    );
  }
}
