import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/utils/relative_time_formatter.dart';
import 'package:horas/core/widgets/app_avatar.dart';
import 'package:horas/core/widgets/app_toast.dart';
import 'package:horas/core/widgets/partuturan_badge.dart';
import 'package:horas/core/widgets/placeholder_image.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// Kartu postingan bergaya Threads untuk `BER-01`, `BER-06`, `SEK-04`, dan `AKN-01`/`AKN-03`.
class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    required this.now,
    required this.isOwnPost,
    super.key,
    this.onAuthorTap,
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
  final VoidCallback? onAuthorTap;
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

  void _openAuthorProfile(BuildContext context) {
    if (onAuthorTap != null) {
      onAuthorTap!();
      return;
    }
    if (isOwnPost) {
      context.go(AppPages.akunPath);
    } else {
      context.push('${AppPages.sek04.routePath}?id=${post.author.id}');
    }
  }

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
    final hasSubInfo =
        showPartuturan ||
        author.isSameMarga ||
        locationLabel.isNotEmpty ||
        post.isEdited;

    return RepaintBoundary(
      child: Material(
        color: colors.surface,
        child: InkWell(
          onTap: onTapCard,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.md,
              AppSpacing.screenMargin,
              AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  button: true,
                  label: AppStrings.ber01AuthorProfileSemantics(
                    author.displayName,
                  ),
                  child: InkWell(
                    onTap: () => _openAuthorProfile(context),
                    borderRadius: AppRadius.pillRadius,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: AppSizes.minTouchTarget,
                        minHeight: AppSizes.minTouchTarget,
                      ),
                      child: Center(
                        child: AppAvatar(
                          name: author.displayName,
                          seed: author.avatarSeed,
                          size: AppSizes.avatarMd,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: AppStrings.ber01AuthorProfileSemantics(
                                author.displayName,
                              ),
                              child: InkWell(
                                onTap: () => _openAuthorProfile(context),
                                borderRadius: AppRadius.buttonRadius,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: AppSizes.minTouchTarget,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              author.displayName,
                                              style: typo.bodyStrong,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Text(
                                            relativeTime,
                                            style: typo.caption,
                                          ),
                                        ],
                                      ),
                                      if (hasSubInfo) ...<Widget>[
                                        const SizedBox(
                                          height: AppSpacing.xxs + 1,
                                        ),
                                        Wrap(
                                          spacing: AppSpacing.xs,
                                          runSpacing: AppSpacing.xxs,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: <Widget>[
                                            if (showPartuturan)
                                              PartuturanBadge(
                                                result: partuturan,
                                                onTap: () => context.push(
                                                  '${AppPages.tar05.routePath}?userId=${author.id}',
                                                ),
                                              )
                                            else if (author.isSameMarga)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: AppSpacing.sm,
                                                      vertical: AppSpacing.xxs,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colors.chipInactive,
                                                  borderRadius:
                                                      AppRadius.pillRadius,
                                                ),
                                                child: Text(
                                                  AppStrings.termSemarga,
                                                  style: typo.micro,
                                                ),
                                              ),
                                            if (locationLabel.isNotEmpty)
                                              Text(
                                                (showPartuturan ||
                                                        author.isSameMarga)
                                                    ? '· $locationLabel'
                                                    : locationLabel,
                                                style: typo.micro,
                                              ),
                                            if (post.isEdited)
                                              Text(
                                                '· ${AppStrings.ber01EditedBadge}',
                                                style: typo.micro,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
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
                      if (post.moderationStatus ==
                          PostModerationStatus.underReview) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
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
                      if (post.text.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        _PostContentText(text: post.text),
                      ],
                      if (post.media.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                        _PostMediaGallery(
                          media: post.media,
                          onMediaTap: onTapCard,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: <Widget>[
                          _ActionIconTextButton(
                            icon: post.isLikedByMe
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            iconColor: post.isLikedByMe
                                ? colors.buttonPrimary
                                : colors.textMuted,
                            label: post.likeCount > 0
                                ? '${post.likeCount}'
                                : '',
                            semanticsLabel:
                                '${AppStrings.ber01LikeAction} (${post.likeCount})',
                            onTap: onLikeTap,
                            onLongPress: onLikesCountTap,
                          ),
                          _ActionIconTextButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            iconColor: colors.textMuted,
                            label: post.commentCount > 0
                                ? '${post.commentCount}'
                                : '',
                            semanticsLabel:
                                '${AppStrings.ber01CommentAction} (${post.commentCount})',
                            onTap: onCommentTap,
                          ),
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
                                await Clipboard.setData(
                                  ClipboardData(text: link),
                                );
                                if (context.mounted) {
                                  AppToast.show(
                                    context,
                                    message: AppStrings.ber01ShareCopiedToast,
                                    variant: AppToastVariant.info,
                                  );
                                }
                              },
                              icon: Icon(
                                Icons.send_outlined,
                                size: AppSizes.iconSm + 2,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostContentText extends StatelessWidget {
  const _PostContentText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;

    if (!text.contains('#')) {
      return Text(text, style: typo.body);
    }

    final colors = context.colors;
    final words = text.split(' ');
    final spans = <InlineSpan>[];

    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      final isLast = i == words.length - 1;
      final space = isLast ? '' : ' ';

      if (word.startsWith('#') && word.length > 1) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final query = Uri.encodeComponent(word);
                context.push('${AppPages.ber10.routePath}?q=$query');
              },
              child: Text(
                '$word$space',
                style: typo.body.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: '$word$space', style: typo.body));
      }
    }

    return Text.rich(TextSpan(children: spans));
  }
}

class _PostMediaGallery extends StatelessWidget {
  const _PostMediaGallery({required this.media, this.onMediaTap});

  final List<PostMedia> media;
  final VoidCallback? onMediaTap;

  Widget _buildMediaItem(
    BuildContext context,
    PostMedia item, {
    double? width,
    double? height,
  }) {
    Widget imageWidget = PlaceholderImage(
      seed: item.seed,
      width: width ?? double.infinity,
      height: height,
      borderRadius: AppRadius.photoRadius,
    );

    if (item.isVideo) {
      imageWidget = Stack(
        alignment: Alignment.center,
        children: <Widget>[
          imageWidget,
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          if (item.durationSeconds > 0)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Text(
                  '${item.durationSeconds}d',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return imageWidget;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.colors.border.withValues(alpha: 0.35);

    if (media.length == 1) {
      final item = media.first;
      return GestureDetector(
        onTap: onMediaTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.photoRadius,
            border: Border.all(color: borderColor, width: AppSizes.strokeThin),
          ),
          child: AspectRatio(
            aspectRatio: item.aspectRatio.clamp(0.8, 1.65),
            child: _buildMediaItem(context, item),
          ),
        ),
      );
    }

    return SizedBox(
      height: 224,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: media.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = media[index];
          return GestureDetector(
            onTap: onMediaTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.photoRadius,
                border: Border.all(
                  color: borderColor,
                  width: AppSizes.strokeThin,
                ),
              ),
              child: _buildMediaItem(context, item, width: 232, height: 224),
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: AppSizes.iconMd, color: iconColor),
                if (label.isNotEmpty) ...<Widget>[
                  const SizedBox(width: AppSpacing.xs),
                  Text(label, style: typo.captionStrong),
                ],
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
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: AppSizes.minTouchTarget,
          height: AppSizes.minTouchTarget,
          child: Align(
            alignment: Alignment.topRight,
            child: Icon(
              Icons.more_horiz_rounded,
              size: AppSizes.iconMd,
              color: colors.textMuted,
            ),
          ),
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
