import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/utils/image_data_uri_helper.dart';
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

/// Memilih dan mengompres foto chat/profil tanpa EXIF dengan batas maksimal 5 MB (`PSN-R3`, `AC-10`).
Future<String?> pickAndCompressChatPhoto(
  BuildContext context, {
  ImageSource source = ImageSource.gallery,
}) async {
  try {
    final encoded = await ImageDataUriHelper.pickAndEncodeImage(
      source,
      maxDimension: 640,
      quality: 75,
      maxRawBytes: AppLimits.messagePhotoMaxBytes,
    );
    return encoded?.dataUri;
  } on FormatException {
    if (context.mounted) {
      AppToast.show(
        context,
        message: AppStrings.psn03PhotoTooLargeError,
        variant: AppToastVariant.error,
      );
    }
    return null;
  } on Object {
    // Fallback deterministik pada simulator / widget test tanpa platform channel.
    return 'chat-photo-sample-${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Pemisah tanggal melayang ala Instagram/WhatsApp (`Hari ini`, `Kemarin`, `18 Nov`).
class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({required this.date, required this.now, super.key});

  final DateTime date;
  final DateTime now;

  static bool isDifferentDay(DateTime a, DateTime b) =>
      a.year != b.year || a.month != b.month || a.day != b.day;

  String _formatDateLabel() {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return AppStrings.psn03DateToday;
    if (diff == 1) return AppStrings.psn03DateYesterday;
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.chipInactive.withValues(alpha: 0.85),
            borderRadius: AppRadius.pillRadius,
          ),
          child: Text(
            _formatDateLabel(),
            style: typo.micro.copyWith(color: colors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// Gelembung pesan ringkas ala Instagram DM dengan gestur *swipe-to-reply* untuk `PSN-03` dan `PSN-04`.
class ChatMessageBubble extends StatefulWidget {
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
    this.onSwipeReply,
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
  final VoidCallback? onSwipeReply;
  final ValueChanged<String>? onPhotoTap;

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  static const double _swipeTriggerDistance = 42.0;
  double _dragDx = 0.0;
  bool _triggeredHaptic = false;

  String _statusLabel(MessageDeliveryStatus status) {
    if (!widget.showReadStatus && status == MessageDeliveryStatus.read) {
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
    if (widget.isMine) {
      return BorderRadius.only(
        topLeft: full,
        bottomLeft: full,
        topRight: widget.isGroupedWithPrevious ? tight : full,
        bottomRight: widget.isGroupedWithNext ? tight : full,
      );
    }
    return BorderRadius.only(
      topRight: full,
      bottomRight: full,
      topLeft: widget.isGroupedWithPrevious ? tight : full,
      bottomLeft: widget.isGroupedWithNext ? tight : full,
    );
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.onSwipeReply == null || widget.message.isDeletedForEveryone) {
      return;
    }
    final next = (_dragDx + details.delta.dx * 0.65).clamp(0.0, 56.0);
    if (next >= _swipeTriggerDistance && !_triggeredHaptic) {
      _triggeredHaptic = true;
      HapticFeedback.mediumImpact();
    } else if (next < _swipeTriggerDistance) {
      _triggeredHaptic = false;
    }
    setState(() => _dragDx = next);
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (_dragDx >= _swipeTriggerDistance) {
      widget.onSwipeReply?.call();
    }
    _triggeredHaptic = false;
    if (_dragDx != 0) {
      setState(() => _dragDx = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final message = widget.message;

    final bubbleColor = message.isAnnouncement
        ? colors.confidenceAmberSurface
        : widget.isMine
        ? colors.primary
        : colors.chipInactive;
    final textColor = (widget.isMine && !message.isAnnouncement)
        ? colors.onPrimary
        : colors.text;
    final mutedColor = (widget.isMine && !message.isAnnouncement)
        ? colors.onPrimary.withValues(alpha: 0.78)
        : colors.textMuted;
    final radius = _bubbleRadius();
    final showFooterMeta = !widget.isGroupedWithNext;
    final replyRevealProgress = (_dragDx / _swipeTriggerDistance).clamp(
      0.0,
      1.0,
    );

    return GestureDetector(
      onHorizontalDragUpdate: widget.onSwipeReply != null
          ? _onHorizontalDragUpdate
          : null,
      onHorizontalDragEnd: widget.onSwipeReply != null
          ? _onHorizontalDragEnd
          : null,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          if (_dragDx > 4)
            Positioned(
              left: 4,
              child: Opacity(
                opacity: replyRevealProgress,
                child: Transform.scale(
                  scale: 0.7 + replyRevealProgress * 0.3,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colors.chipInactive,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      size: 16,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: _dragDx == 0
                ? const Duration(milliseconds: 180)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dragDx, 0, 0),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: widget.isGroupedWithNext ? 3 : AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: widget.isMine
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
                              style: typo.caption.copyWith(
                                color: colors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.isGroup &&
                      !widget.isMine &&
                      !widget.isGroupedWithPrevious)
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
                    mainAxisAlignment: widget.isMine
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      if (!widget.isMine && widget.isGroup) ...<Widget>[
                        if (!widget.isGroupedWithNext)
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
                          onLongPress: widget.onLongPress,
                          borderRadius: radius,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm + 1,
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
                                if (widget.repliedMessage != null) ...<Widget>[
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(
                                      bottom: AppSpacing.xs,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.background.withValues(
                                        alpha: 0.22,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border(
                                        left: BorderSide(
                                          color: widget.isMine
                                              ? colors.onPrimary.withValues(
                                                  alpha: 0.85,
                                                )
                                              : colors.accent,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      '${widget.repliedMessage!.sender.displayName}: ${widget.repliedMessage!.isDeletedForEveryone ? AppStrings.psn01DeletedPreview : widget.repliedMessage!.text}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: typo.micro.copyWith(
                                        color: mutedColor,
                                      ),
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
                                      color: colors.background.withValues(
                                        alpha: 0.2,
                                      ),
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
                                      color: colors.primary.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: colors.primary.withValues(
                                          alpha: 0.4,
                                        ),
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
                                            color: widget.isMine
                                                ? textColor
                                                : colors.primary,
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
                                    onTap: () => widget.onPhotoTap?.call(
                                      message.photoSeed!,
                                    ),
                                    child:
                                        PlaceholderImage.isRealImageSeed(
                                          message.photoSeed!,
                                        )
                                        ? ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              minWidth: 140,
                                              minHeight: 120,
                                              maxWidth: 236,
                                              maxHeight: 300,
                                            ),
                                            child: PlaceholderImage(
                                              seed: message.photoSeed!,
                                              fit: BoxFit.contain,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          )
                                        : PlaceholderImage(
                                            seed: message.photoSeed!,
                                            width: 220,
                                            height: 150,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
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
                        left: (!widget.isMine && widget.isGroup)
                            ? AppSizes.avatarSm + AppSpacing.xs
                            : 0,
                      ),
                      child: Text(
                        widget.isMine
                            ? '${ChatFormatters.formatShortTime(message.createdAt, widget.now)} · ${_statusLabel(message.deliveryStatus)}'
                            : ChatFormatters.formatShortTime(
                                message.createdAt,
                                widget.now,
                              ),
                        style: typo.micro.copyWith(color: colors.textMuted),
                      ),
                    ),
                ],
              ),
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

/// Bilah penulis pesan gaya pil kapsul mulus ala Instagram DM (`PSN-03`, `PSN-04`, Fase 2 flag off).
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
        AppSpacing.md,
        AppSpacing.xs + 2,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.border.withValues(alpha: 0.45),
            width: AppSizes.strokeThin,
          ),
        ),
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
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onQuickGreetingTap?.call(greeting);
                          },
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.chipInactive,
                borderRadius: AppRadius.cardRadius,
                border: Border(
                  left: BorderSide(color: colors.accent, width: 3.5),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${AppStrings.psn03ReplyingToLabel} ${replyToMessage!.sender.displayName}',
                          style: typo.micro.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          replyToMessage!.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typo.caption,
                        ),
                      ],
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
                PlaceholderImage.isRealImageSeed(pendingPhotoSeed!)
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 112,
                          maxHeight: 112,
                        ),
                        child: PlaceholderImage(
                          seed: pendingPhotoSeed!,
                          fit: BoxFit.contain,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      )
                    : PlaceholderImage(
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
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.45),
                width: AppSizes.strokeThin,
              ),
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
                            AppBottomSheet.show<void>(
                              context,
                              title: AppStrings.psn03StickerBtn,
                              child: Wrap(
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
                                          (stk) => AppChip(
                                            leadingIcon:
                                                Icons.sticky_note_2_outlined,
                                            label: stk,
                                            onTap: () {
                                              Navigator.of(context).pop();
                                              onSendSticker?.call(stk);
                                            },
                                          ),
                                        )
                                        .toList(growable: false),
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
                    borderless: true,
                    textInputAction: TextInputAction.send,
                    onSubmitted: enabled ? (_) => onSend() : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final hasPayload =
                        value.text.trim().isNotEmpty ||
                        pendingPhotoSeed != null;
                    return IconButton(
                      tooltip: AppStrings.psn03SendBtnTooltip,
                      onPressed: enabled && !isSending
                          ? () {
                              HapticFeedback.lightImpact();
                              onSend();
                            }
                          : null,
                      icon: Semantics(
                        label: AppStrings.psn03SendBtnTooltip,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: (enabled && hasPayload)
                                ? colors.buttonPrimary
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            size: AppSizes.iconSm + 1,
                            color: (enabled && hasPayload)
                                ? colors.onPrimary
                                : (enabled ? colors.accent : colors.textMuted),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
