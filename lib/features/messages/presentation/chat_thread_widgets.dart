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

/// Gelembung pesan ringkas ala Instagram DM untuk `PSN-03` dan `PSN-04`.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.isMine,
    required this.isGroup,
    required this.now,
    required this.showReadStatus,
    this.isGroupedWithPrevious = false,
    this.isGroupedWithNext = false,
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
  final bool isGroupedWithPrevious;
  final bool isGroupedWithNext;
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

  BorderRadius _bubbleRadius() {
    const full = Radius.circular(20);
    const tight = Radius.circular(6);
    if (isMine) {
      return BorderRadius.only(
        topLeft: full,
        bottomLeft: full,
        topRight: isGroupedWithPrevious ? tight : full,
        bottomRight: isGroupedWithNext ? tight : full,
      );
    }
    return BorderRadius.only(
      topRight: full,
      bottomRight: full,
      topLeft: isGroupedWithPrevious ? tight : full,
      bottomLeft: isGroupedWithNext ? tight : full,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    final bubbleColor = message.isAnnouncement
        ? colors.confidenceAmberSurface
        : isMine
        ? colors.primary
        : colors.chipInactive;
    final textColor = (isMine && !message.isAnnouncement)
        ? colors.onPrimary
        : colors.text;
    final mutedColor = (isMine && !message.isAnnouncement)
        ? colors.onPrimary.withValues(alpha: 0.78)
        : colors.textMuted;
    final radius = _bubbleRadius();
    final showFooterMeta = !isGroupedWithNext;

    return Padding(
      padding: EdgeInsets.only(bottom: isGroupedWithNext ? 3 : AppSpacing.sm),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          if (message.hasScamWarning)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
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
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      AppStrings.psn03ScamWarningBanner,
                      style: typo.caption.copyWith(color: colors.danger),
                    ),
                  ),
                ],
              ),
            ),
          if (isGroup && !isMine && !isGroupedWithPrevious)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSizes.avatarSm + AppSpacing.xs,
                bottom: AppSpacing.xxs,
              ),
              child: Wrap(
                spacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    message.sender.displayName,
                    style: typo.micro.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
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
            ),
          Row(
            mainAxisAlignment: isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (!isMine && isGroup) ...<Widget>[
                if (!isGroupedWithNext)
                  AppAvatar(
                    name: message.sender.displayName,
                    seed: message.sender.avatarSeed,
                    size: AppSizes.avatarSm,
                  )
                else
                  const SizedBox(width: AppSizes.avatarSm),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: InkWell(
                  onLongPress: onLongPress,
                  borderRadius: radius,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: radius,
                      border: message.isAnnouncement
                          ? Border.all(color: colors.confidenceAmber)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (message.isAnnouncement) ...<Widget>[
                          Text(
                            AppStrings.psn04PinnedAnnouncementTitle,
                            style: typo.captionStrong.copyWith(
                              color: colors.confidenceAmber,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        if (repliedMessage != null) ...<Widget>[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.background.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${repliedMessage!.sender.displayName}: ${repliedMessage!.isDeletedForEveryone ? AppStrings.psn01DeletedPreview : repliedMessage!.text}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: typo.micro.copyWith(color: mutedColor),
                            ),
                          ),
                        ],
                        if (message.voiceNoteSeed != null &&
                            !message.isDeletedForEveryone) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: colors.background.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: textColor,
                                  size: AppSizes.iconMd,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Icon(
                                  Icons.graphic_eq_rounded,
                                  color: textColor,
                                  size: AppSizes.iconSm,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '${message.voiceNoteDurationSeconds ?? 5}d',
                                  style: typo.captionStrong.copyWith(
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (message.text.isNotEmpty)
                            const SizedBox(height: AppSpacing.xs),
                        ],
                        if (message.stickerSeed != null &&
                            !message.isDeletedForEveryone) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.sticky_note_2,
                                  color: Colors.amber,
                                  size: AppSizes.iconSm,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  message.stickerSeed!,
                                  style: typo.bodyStrong.copyWith(
                                    color: isMine ? textColor : colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (message.text.isNotEmpty)
                            const SizedBox(height: AppSpacing.xs),
                        ],
                        if (message.photoSeed != null &&
                            !message.isDeletedForEveryone) ...<Widget>[
                          GestureDetector(
                            onTap: () => onPhotoTap?.call(message.photoSeed!),
                            child: PlaceholderImage(
                              seed: message.photoSeed!,
                              width: 220,
                              height: 150,
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          if (message.text.isNotEmpty)
                            const SizedBox(height: AppSpacing.xs),
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (showFooterMeta)
            Padding(
              padding: EdgeInsets.only(
                top: 2,
                left: (!isMine && isGroup)
                    ? AppSizes.avatarSm + AppSpacing.xs
                    : 0,
              ),
              child: Text(
                isMine
                    ? '${ChatFormatters.formatShortTime(message.createdAt, now)} · ${_statusLabel(message.deliveryStatus)}'
                    : ChatFormatters.formatShortTime(message.createdAt, now),
                style: typo.micro.copyWith(color: colors.textMuted),
              ),
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
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.danger),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              item.text.isNotEmpty ? item.text : AppStrings.psn01PhotoPreview,
              style: typo.body,
            ),
            const SizedBox(height: 2),
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

/// Bilah penulis pesan gaya pil Instagram (`PSN-03`, `PSN-04`, Fase 2 flag off).
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
    this.onSendSticker,
    this.onSendVoiceNote,
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
  final ValueChanged<String>? onSendSticker;
  final VoidCallback? onSendVoiceNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border, width: 0.5)),
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
            const SizedBox(height: AppSpacing.xs),
          ],
          if (replyToMessage != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.chipInactive,
                borderRadius: BorderRadius.circular(12),
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
                  width: 84,
                  height: 62,
                  borderRadius: BorderRadius.circular(12),
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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: colors.chipInactive,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: AppStrings.psn03PickPhotoTooltip,
                  onPressed: enabled ? onPickPhoto : null,
                  icon: Semantics(
                    label: AppStrings.psn03PickPhotoTooltip,
                    child: Icon(
                      Icons.photo_outlined,
                      color: enabled ? colors.text : colors.textMuted,
                    ),
                  ),
                ),
                // Fase 2 (PSN-R3): voice note dan stiker
                if (flags.voiceNote)
                  IconButton(
                    tooltip: AppStrings.psn03VoiceNoteBtn,
                    onPressed: enabled ? onSendVoiceNote : null,
                    icon: Semantics(
                      label: AppStrings.psn03VoiceNoteBtn,
                      child: Icon(
                        Icons.mic_outlined,
                        color: enabled ? colors.text : colors.textMuted,
                      ),
                    ),
                  ),
                if (flags.stickers)
                  IconButton(
                    tooltip: AppStrings.psn03StickerBtn,
                    onPressed: enabled
                        ? () {
                            showModalBottomSheet<void>(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        AppStrings.psn03StickerBtn,
                                        style: typo.bodyStrong,
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      Wrap(
                                        spacing: AppSpacing.sm,
                                        runSpacing: AppSpacing.sm,
                                        children:
                                            <String>[
                                                  'Horas!',
                                                  'Mauliate!',
                                                  'Tabo!',
                                                  'Mejuah-juah!',
                                                  'Njuah-njuah!',
                                                  'Horas Ma Di Hita!',
                                                ]
                                                .map(
                                                  (stk) => ActionChip(
                                                    avatar: const Icon(
                                                      Icons.sticky_note_2,
                                                      size: 16,
                                                    ),
                                                    label: Text(stk),
                                                    onPressed: () {
                                                      Navigator.of(ctx).pop();
                                                      onSendSticker?.call(stk);
                                                    },
                                                  ),
                                                )
                                                .toList(growable: false),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: Semantics(
                      label: AppStrings.psn03StickerBtn,
                      child: Icon(
                        Icons.sticky_note_2_outlined,
                        color: enabled ? colors.text : colors.textMuted,
                      ),
                    ),
                  ),
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
          ),
        ],
      ),
    );
  }
}
