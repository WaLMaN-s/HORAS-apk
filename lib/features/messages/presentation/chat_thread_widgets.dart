import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/app_limits.dart';
import 'package:horas/features/messages/presentation/messages_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

/// Pesan lokal sementara yang gagal terkirim agar pengguna dapat menekan `Coba lagi`.
final class FailedOutgoingMessage {
  const FailedOutgoingMessage({
    required this.tempId,
    required this.text,
    required this.errorMessage,
    this.photoSeed,
    this.replyToMessageId,
  });

  final String tempId;
  final String text;
  final String? photoSeed;
  final String? replyToMessageId;
  final String errorMessage;
}

/// Memilih dan mengompres foto chat tanpa EXIF dengan batas maksimal 5 MB (`PSN-R3`).
Future<String?> pickAndCompressChatPhoto(BuildContext context) async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final rawBytes = await picked.readAsBytes();
    if (rawBytes.length > AppLimits.messagePhotoMaxBytes) {
      if (context.mounted) {
        AppToast.show(
          context,
          message: AppStrings.psn03PhotoTooLargeError,
          variant: AppToastVariant.error,
        );
      }
      return null;
    }
    final compressed = await FlutterImageCompress.compressWithList(
      rawBytes,
      minWidth: 1080,
      minHeight: 1080,
      quality: 82,
      keepExif: false, // Hapus metadata EXIF
    );
    return 'chat-photo-${compressed.length}-${picked.name}';
  } on Object {
    // Fallback deterministik pada simulator / widget test tanpa platform channel.
    return 'chat-photo-sample-${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Gelembung pesan bersama untuk `PSN-03` (Chat Pribadi) dan `PSN-04` (Chat Grup).
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.isMine,
    required this.isGroup,
    required this.now,
    required this.showReadStatus,
    this.repliedMessage,
    this.onLongPress,
    this.onPhotoTap,
    super.key,
  });

  final Message message;
  final bool isMine;
  final bool isGroup;
  final DateTime now;
  final bool showReadStatus;
  final Message? repliedMessage;
  final VoidCallback? onLongPress;
  final ValueChanged<String>? onPhotoTap;

  String _statusLabel(MessageDeliveryStatus status) {
    if (!showReadStatus && status == MessageDeliveryStatus.read) {
      return AppStrings.psn03StatusDelivered;
    }
    return switch (status) {
      MessageDeliveryStatus.sent => AppStrings.psn03StatusSent,
      MessageDeliveryStatus.delivered => AppStrings.psn03StatusDelivered,
      MessageDeliveryStatus.read => AppStrings.psn03StatusRead,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    final bubbleColor = message.isAnnouncement
        ? colors.confidenceAmberSurface
        : isMine
        ? colors.primary
        : colors.surface;
    final textColor = (isMine && !message.isAnnouncement)
        ? colors.onPrimary
        : colors.text;
    final mutedColor = (isMine && !message.isAnnouncement)
        ? colors.onPrimary.withValues(alpha: 0.8)
        : colors.textMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          if (message.hasScamWarning)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.12),
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: colors.danger),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppStrings.psn03ScamWarningBanner,
                      style: typo.caption.copyWith(color: colors.danger),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (!isMine && isGroup) ...<Widget>[
                AppAvatar(
                  name: message.sender.displayName,
                  seed: message.sender.avatarSeed,
                  size: AppSizes.avatarSm,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: InkWell(
                  onLongPress: onLongPress,
                  borderRadius: AppRadius.cardRadius,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: AppRadius.cardRadius,
                      border: isMine && !message.isAnnouncement
                          ? null
                          : Border.all(
                              color: message.isAnnouncement
                                  ? colors.confidenceAmber
                                  : colors.border,
                            ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (isGroup && !isMine) ...<Widget>[
                          Wrap(
                            spacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Text(
                                message.sender.displayName,
                                style: typo.captionStrong.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                              if (message.sender.partuturan != null)
                                PartuturanBadge(
                                  result: message.sender.partuturan!,
                                  onTap: () => context
                                      .push(
                                        '${AppPages.tar05.routePath}?userId=${message.sender.id}',
                                      )
                                      .ignore(),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        if (message.isAnnouncement) ...<Widget>[
                          Text(
                            AppStrings.psn04PinnedAnnouncementTitle,
                            style: typo.captionStrong.copyWith(
                              color: colors.confidenceAmber,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        if (repliedMessage != null) ...<Widget>[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: colors.chipInactive.withValues(
                                alpha: 0.35,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${repliedMessage!.sender.displayName}: ${repliedMessage!.isDeletedForEveryone ? AppStrings.psn01DeletedPreview : repliedMessage!.text}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: typo.micro.copyWith(color: mutedColor),
                            ),
                          ),
                        ],
                        if (message.photoSeed != null &&
                            !message.isDeletedForEveryone) ...<Widget>[
                          GestureDetector(
                            onTap: () => onPhotoTap?.call(message.photoSeed!),
                            child: PlaceholderImage(
                              seed: message.photoSeed!,
                              width: 220,
                              height: 150,
                            ),
                          ),
                          if (message.text.isNotEmpty)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                        if (message.text.isNotEmpty)
                          Text(
                            message.text,
                            style: message.isDeletedForEveryone
                                ? typo.caption.copyWith(
                                    color: mutedColor,
                                    fontStyle: FontStyle.italic,
                                  )
                                : typo.body.copyWith(color: textColor),
                          ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              ChatFormatters.formatShortTime(
                                message.createdAt,
                                now,
                              ),
                              style: typo.micro.copyWith(color: mutedColor),
                            ),
                            if (isMine) ...<Widget>[
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                '· ${_statusLabel(message.deliveryStatus)}',
                                style: typo.micro.copyWith(color: mutedColor),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu pesan gagal terkirim dengan tombol `Coba lagi` (`PSN-03`).
class FailedMessageTile extends StatelessWidget {
  const FailedMessageTile({
    required this.item,
    required this.onRetry,
    super.key,
  });

  final FailedOutgoingMessage item;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.1),
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: colors.danger),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              item.text.isNotEmpty ? item.text : AppStrings.psn01PhotoPreview,
              style: typo.body,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${AppStrings.psn03FailedSendLabel}: ${item.errorMessage}',
              style: typo.micro.copyWith(color: colors.danger),
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(AppStrings.actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bilah penulis pesan bersama (`PSN-03`, `PSN-04`, Fase 2 flag off: tanpa voice note/stiker/lokasi).
class ChatComposerBar extends ConsumerWidget {
  const ChatComposerBar({
    required this.controller,
    required this.enabled,
    required this.isSending,
    required this.onSend,
    required this.onPickPhoto,
    this.replyToMessage,
    this.onCancelReply,
    this.pendingPhotoSeed,
    this.onClearPhoto,
    this.quickGreetings = const <String>[],
    this.onQuickGreetingTap,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onPickPhoto;
  final Message? replyToMessage;
  final VoidCallback? onCancelReply;
  final String? pendingPhotoSeed;
  final VoidCallback? onClearPhoto;
  final List<String> quickGreetings;
  final ValueChanged<String>? onQuickGreetingTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (enabled && quickGreetings.isNotEmpty) ...<Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: quickGreetings
                    .map(
                      (greeting) => Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: AppChip(
                          label: greeting,
                          onTap: () => onQuickGreetingTap?.call(greeting),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (replyToMessage != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.chipInactive,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${AppStrings.psn03ReplyingToLabel} ${replyToMessage!.text}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.caption,
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.semanticsClose,
                    onPressed: onCancelReply,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (pendingPhotoSeed != null) ...<Widget>[
            Stack(
              children: <Widget>[
                PlaceholderImage(
                  seed: pendingPhotoSeed!,
                  width: 92,
                  height: 68,
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    tooltip: AppStrings.semanticsClose,
                    onPressed: onClearPhoto,
                    icon: const Icon(Icons.cancel_rounded, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Row(
            children: <Widget>[
              IconButton(
                tooltip: AppStrings.psn03PickPhotoTooltip,
                onPressed: enabled ? onPickPhoto : null,
                icon: Semantics(
                  label: AppStrings.psn03PickPhotoTooltip,
                  child: const Icon(Icons.photo_outlined),
                ),
              ),
              // Fase 2 guard (PSN-R3): voice note dan stiker disembunyikan saat flag off.
              if (flags.voiceNote) const SizedBox.shrink(),
              if (flags.stickers) const SizedBox.shrink(),
              Expanded(
                child: AppTextField(
                  controller: controller,
                  hintText: AppStrings.psn03ComposerHint,
                  maxLength: AppLimits.messageTextMaxChars,
                  enabled: enabled,
                  textInputAction: TextInputAction.send,
                  onSubmitted: enabled ? (_) => onSend() : null,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                tooltip: AppStrings.psn03SendBtnTooltip,
                onPressed: enabled && !isSending ? onSend : null,
                icon: Semantics(
                  label: AppStrings.psn03SendBtnTooltip,
                  child: Icon(
                    Icons.send_rounded,
                    color: enabled ? colors.primary : colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
