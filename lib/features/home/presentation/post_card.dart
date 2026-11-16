import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/home/presentation/home_models.dart';
import 'package:material_ui/material_ui.dart';

/// Kartu postingan standar HORAS untuk `BER-01` Feed dan `BER-06` Detail Postingan.
class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    required this.now,
    required this.isOwnPost,
    super.key,
    this.onTapCard,
    this.onLikeTap,
    this.onCommentTap,
    this.onLikesCountTap,
    this.onSaveTap,
    this.onReportTap,
    this.onMuteTap,
    this.onBlockTap,
    this.onEditTextTap,
    this.onDeleteTap,
  });

  final Post post;
  final DateTime now;
  final bool isOwnPost;
  final VoidCallback? onTapCard;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onLikesCountTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onReportTap;
  final VoidCallback? onMuteTap;
  final VoidCallback? onBlockTap;
  final VoidCallback? onEditTextTap;
  final VoidCallback? onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final author = post.author;
    final partuturan = author.partuturan;
    final showPartuturan = partuturan != null && !partuturan.modeNetral;

    final relativeTime = RelativeTimeFormatter.format(post.createdAt, now);
    final locationLabel = (post.cityTag != null && post.cityTag!.isNotEmpty)
        ? post.cityTag!
        : author.city;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colors.border),
        boxShadow: AppShadows.softCard(colors.shadow),
      ),
      child: Material(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTapCard,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header: Avatar, Nama, Marga, Badge partuturan, Kota, Waktu, Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppAvatar(
                      name: author.displayName,
                      seed: author.avatarSeed,
                      size: AppSizes.avatarMd,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Text(author.displayName, style: typo.bodyStrong),
                              Text(
                                '· ${author.marga}',
                                style: typo.captionStrong.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                              if (showPartuturan)
                                PartuturanBadge(
                                  result: partuturan,
                                  onTap: () => context.push(
                                    '${AppPages.tar05.routePath}?userId=${author.id}',
                                  ),
                                ),
                              if (author.isSameMarga && !showPartuturan)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xxs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.chipInactive,
                                    borderRadius: AppRadius.pillRadius,
                                  ),
                                  child: Text(
                                    AppStrings.termSemarga,
                                    style: typo.micro,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Text(
                                '$locationLabel · $relativeTime',
                                style: typo.caption,
                              ),
                              if (post.isEdited)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs + AppSpacing.xxs,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.chipInactive,
                                    borderRadius: AppRadius.pillRadius,
                                  ),
                                  child: Text(
                                    AppStrings.ber01EditedBadge,
                                    style: typo.micro,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _PostOverflowMenu(
                      isOwnPost: isOwnPost,
                      onReportTap: onReportTap,
                      onMuteTap: onMuteTap,
                      onBlockTap: onBlockTap,
                      onEditTextTap: onEditTextTap,
                      onDeleteTap: onDeleteTap,
                    ),
                  ],
                ),

                // Status "Sedang ditinjau" bila ditahan filter kata/spam atau tautan akun baru (BER-R10, R11)
                if (post.moderationStatus ==
                    PostModerationStatus.underReview) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.confidenceAmberSurface,
                      borderRadius: AppRadius.buttonRadius,
                      border: Border.all(color: colors.confidenceAmber),
                    ),
                    child: Text(
                      AppStrings.ber01UnderReviewBadge,
                      style: typo.captionStrong.copyWith(
                        color: colors.confidenceAmber,
                      ),
                    ),
                  ),
                ],

                // Teks Postingan
                if (post.text.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(post.text, style: typo.body),
                ],

                // Galeri Foto
                if (post.media.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _PostMediaGallery(media: post.media),
                ],

                const SizedBox(height: AppSpacing.md),
                const Divider(),
                const SizedBox(height: AppSpacing.xs),

                // Baris Aksi: Suka, Komentar, Simpan, Bagikan
                Row(
                  children: <Widget>[
                    _ActionIconTextButton(
                      icon: post.isLikedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor: post.isLikedByMe
                          ? colors.buttonPrimary
                          : colors.textMuted,
                      label: '${post.likeCount}',
                      semanticsLabel:
                          '${AppStrings.ber01LikeAction} (${post.likeCount})',
                      onTap: onLikeTap,
                      onLongPress: onLikesCountTap,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _ActionIconTextButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: colors.textMuted,
                      label: '${post.commentCount}',
                      semanticsLabel:
                          '${AppStrings.ber01CommentAction} (${post.commentCount})',
                      onTap: onCommentTap,
                    ),
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: post.isSavedByMe
                          ? AppStrings.ber01SavedAction
                          : AppStrings.ber01SaveAction,
                      child: IconButton(
                        constraints: const BoxConstraints(
                          minWidth: AppSizes.minTouchTarget,
                          minHeight: AppSizes.minTouchTarget,
                        ),
                        tooltip: post.isSavedByMe
                            ? AppStrings.ber01SavedAction
                            : AppStrings.ber01SaveAction,
                        onPressed: onSaveTap,
                        icon: Icon(
                          post.isSavedByMe
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: AppSizes.iconMd,
                          color: post.isSavedByMe
                              ? colors.buttonPrimary
                              : colors.textMuted,
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: AppStrings.ber01ShareAction,
                      child: IconButton(
                        constraints: const BoxConstraints(
                          minWidth: AppSizes.minTouchTarget,
                          minHeight: AppSizes.minTouchTarget,
                        ),
                        tooltip: AppStrings.ber01ShareAction,
                        onPressed: () async {
                          final link =
                              'horas://app/beranda/postingan-detail?id=${post.id}';
                          await Clipboard.setData(ClipboardData(text: link));
                          if (context.mounted) {
                            AppToast.show(
                              context,
                              message: AppStrings.ber01ShareCopiedToast,
                              variant: AppToastVariant.info,
                            );
                          }
                        },
                        icon: Icon(
                          Icons.share_outlined,
                          size: AppSizes.iconMd,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostMediaGallery extends StatelessWidget {
  const _PostMediaGallery({required this.media});

  final List<PostMedia> media;

  @override
  Widget build(BuildContext context) {
    if (media.length == 1) {
      final item = media.first;
      return AspectRatio(
        aspectRatio: item.aspectRatio.clamp(0.75, 1.8),
        child: PlaceholderImage(
          seed: item.seed,
          width: double.infinity,
          borderRadius: AppRadius.photoRadius,
        ),
      );
    }

    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = media[index];
          return PlaceholderImage(
            seed: item.seed,
            width: 220,
            height: 196,
            borderRadius: AppRadius.photoRadius,
            caption: '${index + 1}/${media.length}',
          );
        },
      ),
    );
  }
}

class _ActionIconTextButton extends StatelessWidget {
  const _ActionIconTextButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.semanticsLabel,
    this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppRadius.buttonRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.minTouchTarget,
            minWidth: AppSizes.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: AppSizes.iconMd, color: iconColor),
                const SizedBox(width: AppSpacing.xs),
                Text(label, style: typo.captionStrong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostOverflowMenu extends StatelessWidget {
  const _PostOverflowMenu({
    required this.isOwnPost,
    this.onReportTap,
    this.onMuteTap,
    this.onBlockTap,
    this.onEditTextTap,
    this.onDeleteTap,
  });

  final bool isOwnPost;
  final VoidCallback? onReportTap;
  final VoidCallback? onMuteTap;
  final VoidCallback? onBlockTap;
  final VoidCallback? onEditTextTap;
  final VoidCallback? onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: AppStrings.ber01MenuTooltip,
      child: PopupMenuButton<String>(
        tooltip: AppStrings.ber01MenuTooltip,
        icon: Icon(
          Icons.more_horiz_rounded,
          size: AppSizes.iconMd,
          color: colors.textMuted,
        ),
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEditTextTap?.call();
            case 'delete':
              onDeleteTap?.call();
            case 'report':
              onReportTap?.call();
            case 'mute':
              onMuteTap?.call();
            case 'block':
              onBlockTap?.call();
          }
        },
        itemBuilder: (context) => <PopupMenuEntry<String>>[
          if (isOwnPost) ...<PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'edit',
              child: Text(AppStrings.ber01MenuEdit),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Text(AppStrings.ber01MenuDelete),
            ),
          ] else ...<PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'report',
              child: Text(AppStrings.ber01MenuReport),
            ),
            const PopupMenuItem<String>(
              value: 'mute',
              child: Text(AppStrings.ber01MenuMute),
            ),
            const PopupMenuItem<String>(
              value: 'block',
              child: Text(AppStrings.ber01MenuBlock),
            ),
          ],
        ],
      ),
    );
  }
}
