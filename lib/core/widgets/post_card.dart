import 'dart:async';

import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'package:go_router/go_router.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/utils/relative_time_formatter.dart';
import 'package:horas/core/widgets/app_avatar.dart';
import 'package:horas/core/widgets/app_bottom_sheet.dart';
import 'package:horas/core/widgets/app_toast.dart';
import 'package:horas/core/widgets/partuturan_badge.dart';
import 'package:horas/core/widgets/photo_lightbox_page.dart';
import 'package:horas/core/widgets/placeholder_image.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// Kartu postingan bergaya Threads + Instagram untuk `BER-01`, `BER-06`, `SEK-04`, dan `AKN-01`/`AKN-03`.
class PostCard extends StatefulWidget {
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

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showHeartBurst = false;
  bool _likeBounce = false;
  Timer? _heartTimer;
  Timer? _bounceTimer;

  @override
  void dispose() {
    _heartTimer?.cancel();
    _bounceTimer?.cancel();
    super.dispose();
  }

  void _openAuthorProfile(BuildContext context) {
    if (widget.onAuthorTap != null) {
      widget.onAuthorTap!();
      return;
    }
    if (widget.isOwnPost) {
      context.go(AppPages.akunPath);
    } else {
      context.push('${AppPages.sek04.routePath}?id=${widget.post.author.id}');
    }
  }

  void _triggerLike({required bool fromDoubleTap}) {
    if (fromDoubleTap) {
      HapticFeedback.mediumImpact();
      _heartTimer?.cancel();
      setState(() => _showHeartBurst = true);
      _heartTimer = Timer(const Duration(milliseconds: 680), () {
        if (mounted) setState(() => _showHeartBurst = false);
      });
      if (!widget.post.isLikedByMe) {
        widget.onLikeTap?.call();
      }
    } else {
      HapticFeedback.lightImpact();
      _bounceTimer?.cancel();
      setState(() => _likeBounce = true);
      _bounceTimer = Timer(const Duration(milliseconds: 170), () {
        if (mounted) setState(() => _likeBounce = false);
      });
      widget.onLikeTap?.call();
    }
  }

  Future<void> _copyPostLink(BuildContext context) async {
    final link = 'horas://app/beranda/postingan-detail?id=${widget.post.id}';
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      HapticFeedback.lightImpact().ignore();
      AppToast.show(
        context,
        message: AppStrings.ber01ShareCopiedToast,
        variant: AppToastVariant.info,
      );
    }
  }

  Future<void> _openOptionsSheet(BuildContext context) async {
    final colors = context.colors;
    final typo = context.typo;

    await AppBottomSheet.show<void>(
      context,
      title: AppStrings.ber01PostOptionsTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.chipInactive,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.link_rounded,
                size: AppSizes.iconMd - 2,
                color: colors.text,
              ),
            ),
            title: Text(AppStrings.ber01CopyLinkAction, style: typo.bodyStrong),
            onTap: () {
              Navigator.of(context).pop();
              _copyPostLink(context);
            },
          ),
          if (widget.isOwnPost) ...<Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.chipInactive,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_outlined,
                  size: AppSizes.iconMd - 2,
                  color: colors.text,
                ),
              ),
              title: Text(AppStrings.ber01MenuEdit, style: typo.bodyStrong),
              onTap: () {
                Navigator.of(context).pop();
                widget.onEditTextTap?.call();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: AppSizes.iconMd - 2,
                  color: colors.danger,
                ),
              ),
              title: Text(
                AppStrings.ber01MenuDelete,
                style: typo.bodyStrong.copyWith(color: colors.danger),
              ),
              onTap: () {
                Navigator.of(context).pop();
                widget.onDeleteTap?.call();
              },
            ),
          ] else ...<Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.chipInactive,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.volume_off_outlined,
                  size: AppSizes.iconMd - 2,
                  color: colors.text,
                ),
              ),
              title: Text(AppStrings.ber01MenuMute, style: typo.bodyStrong),
              onTap: () {
                Navigator.of(context).pop();
                widget.onMuteTap?.call();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.flag_outlined,
                  size: AppSizes.iconMd - 2,
                  color: colors.danger,
                ),
              ),
              title: Text(
                AppStrings.ber01MenuReport,
                style: typo.bodyStrong.copyWith(color: colors.danger),
              ),
              onTap: () {
                Navigator.of(context).pop();
                widget.onReportTap?.call();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.block_rounded,
                  size: AppSizes.iconMd - 2,
                  color: colors.danger,
                ),
              ),
              title: Text(
                AppStrings.ber01MenuBlock,
                style: typo.bodyStrong.copyWith(color: colors.danger),
              ),
              onTap: () {
                Navigator.of(context).pop();
                widget.onBlockTap?.call();
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final colors = context.colors;
    final typo = context.typo;
    final author = post.author;
    final partuturan = author.partuturan;
    final showPartuturan = partuturan != null && !partuturan.modeNetral;

    final relativeTime = RelativeTimeFormatter.format(
      post.createdAt,
      widget.now,
    );
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
          onTap: widget.onTapCard,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.md,
              AppSpacing.screenMargin,
              AppSpacing.sm,
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
                          Semantics(
                            button: true,
                            label: AppStrings.ber01MenuTooltip,
                            child: IconButton(
                              constraints: const BoxConstraints(
                                minWidth: AppSizes.minTouchTarget,
                                minHeight: AppSizes.minTouchTarget,
                              ),
                              padding: EdgeInsets.zero,
                              alignment: Alignment.topRight,
                              tooltip: AppStrings.ber01MenuTooltip,
                              onPressed: () => _openOptionsSheet(context),
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                size: AppSizes.iconMd,
                                color: colors.textMuted,
                              ),
                            ),
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
                        Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            _PostMediaGallery(
                              media: post.media,
                              authorName: author.displayName,
                              onDoubleTapLike: () =>
                                  _triggerLike(fromDoubleTap: true),
                              onOpenLightbox: (index) {
                                PhotoLightboxPage.show(
                                  context,
                                  seeds: post.media
                                      .map((m) => m.seed)
                                      .toList(growable: false),
                                  initialIndex: index,
                                  title: author.displayName,
                                );
                              },
                            ),
                            IgnorePointer(
                              child: AnimatedOpacity(
                                opacity: _showHeartBurst ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 180),
                                child: AnimatedScale(
                                  scale: _showHeartBurst ? 1.0 : 0.45,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutBack,
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.favorite_rounded,
                                      color: Colors.white,
                                      size: 56,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: <Widget>[
                          AnimatedScale(
                            scale: _likeBounce ? 1.24 : 1.0,
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutBack,
                            child: _ActionIconTextButton(
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
                              onTap: () => _triggerLike(fromDoubleTap: false),
                              onLongPress: widget.onLikesCountTap,
                            ),
                          ),
                          _ActionIconTextButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            iconColor: colors.textMuted,
                            label: post.commentCount > 0
                                ? '${post.commentCount}'
                                : '',
                            semanticsLabel:
                                '${AppStrings.ber01CommentAction} (${post.commentCount})',
                            onTap: widget.onCommentTap,
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
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                widget.onSaveTap?.call();
                              },
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
                              onPressed: () => _copyPostLink(context),
                              icon: Icon(
                                Icons.send_outlined,
                                size: AppSizes.iconSm + 2,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (post.likeCount > 0 && widget.onLikesCountTap != null)
                        GestureDetector(
                          onTap: widget.onLikesCountTap,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.xs,
                              bottom: AppSpacing.xs,
                            ),
                            child: Text(
                              AppStrings.ber01LikesSummary(post.likeCount),
                              style: typo.micro.copyWith(
                                color: colors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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

class _PostContentText extends StatefulWidget {
  const _PostContentText({required this.text});

  final String text;

  @override
  State<_PostContentText> createState() => _PostContentTextState();
}

class _PostContentTextState extends State<_PostContentText> {
  static const int _collapseCharThreshold = 220;
  bool _expanded = false;

  bool get _isLong {
    final text = widget.text;
    return text.length > _collapseCharThreshold ||
        '\n'.allMatches(text).length >= 5;
  }

  String _truncated(String text) {
    final lines = text.split('\n');
    if (lines.length > 5) {
      final firstFive = lines.take(5).join('\n');
      if (firstFive.length <= _collapseCharThreshold) {
        return '$firstFive...';
      }
    }
    if (text.length > _collapseCharThreshold) {
      return '${text.substring(0, _collapseCharThreshold).trimRight()}...';
    }
    return text;
  }

  Widget _renderRichText(BuildContext context, String content) {
    final typo = context.typo;
    if (!content.contains('#')) {
      return Text(content, style: typo.body);
    }

    final colors = context.colors;
    final words = content.split(' ');
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
                  color: colors.accent,
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

  @override
  Widget build(BuildContext context) {
    final display = (_isLong && !_expanded)
        ? _truncated(widget.text)
        : widget.text;
    final typo = context.typo;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _renderRichText(context, display),
        if (_isLong)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                _expanded ? AppStrings.ber01ShowLess : AppStrings.ber01ReadMore,
                style: typo.captionStrong.copyWith(color: colors.textMuted),
              ),
            ),
          ),
      ],
    );
  }
}

class _PostMediaGallery extends StatefulWidget {
  const _PostMediaGallery({
    required this.media,
    required this.authorName,
    required this.onDoubleTapLike,
    required this.onOpenLightbox,
  });

  final List<PostMedia> media;
  final String authorName;
  final VoidCallback onDoubleTapLike;
  final ValueChanged<int> onOpenLightbox;

  @override
  State<_PostMediaGallery> createState() => _PostMediaGalleryState();
}

class _PostMediaGalleryState extends State<_PostMediaGallery> {
  final ScrollController _scrollController = ScrollController();
  int _activeIndex = 0;
  static const double _multiItemWidth = 256;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final idx = (_scrollController.offset / (_multiItemWidth + AppSpacing.sm))
        .round()
        .clamp(0, widget.media.length - 1);
    if (idx != _activeIndex && mounted) {
      setState(() => _activeIndex = idx);
    }
  }

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
            width: 48,
            height: 48,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: AppRadius.pillRadius,
                ),
                child: Text(
                  '${item.durationSeconds}d',
                  style: context.typo.micro.copyWith(color: Colors.white),
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
    final colors = context.colors;
    final borderColor = colors.border.withValues(alpha: 0.4);

    if (widget.media.length == 1) {
      final item = widget.media.first;
      return GestureDetector(
        onTap: () => widget.onOpenLightbox(0),
        onDoubleTap: widget.onDoubleTapLike,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 244,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: widget.media.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = widget.media[index];
              return GestureDetector(
                onTap: () => widget.onOpenLightbox(index),
                onDoubleTap: widget.onDoubleTapLike,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.photoRadius,
                    border: Border.all(
                      color: borderColor,
                      width: AppSizes.strokeThin,
                    ),
                  ),
                  child: _buildMediaItem(
                    context,
                    item,
                    width: _multiItemWidth,
                    height: 244,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(widget.media.length, (i) {
            final active = i == _activeIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: active ? 16 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: active
                    ? colors.accent
                    : colors.border.withValues(alpha: 0.85),
                borderRadius: AppRadius.pillRadius,
              ),
            );
          }),
        ),
      ],
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
