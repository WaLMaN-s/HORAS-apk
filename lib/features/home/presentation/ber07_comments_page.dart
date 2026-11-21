import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/app_limits.dart';
import 'package:horas/features/home/presentation/home_feed_controller.dart';
import 'package:horas/features/home/presentation/home_models.dart';
import 'package:material_ui/material_ui.dart';

/// BER-07 Komentar bergaya Threads/Instagram:
/// - Dapat dibuka sebagai halaman penuh maupun Bottom Sheet modal (`showSheet`)
/// - Daftar komentar bersih borderless dengan garis penghubung thread ke balasan
/// - Balasan satu tingkat, batas 1.000 karakter & 60 komentar/jam (`BER-R5`)
class Ber07CommentsPage extends StatelessWidget {
  const Ber07CommentsPage({required this.postId, super.key});

  final String postId;

  /// Membuka daftar komentar langsung sebagai Bottom Sheet ala Instagram/Threads.
  static Future<void> showSheet(
    BuildContext context, {
    required String postId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTopRadius,
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.74,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          expand: false,
          builder: (ctx, scrollController) {
            return _CommentsView(
              postId: postId,
              isSheet: true,
              externalScrollController: scrollController,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CommentsView(postId: postId, isSheet: false);
  }
}

class _CommentsView extends ConsumerStatefulWidget {
  const _CommentsView({
    required this.postId,
    required this.isSheet,
    this.externalScrollController,
  });

  final String postId;
  final bool isSheet;
  final ScrollController? externalScrollController;

  @override
  ConsumerState<_CommentsView> createState() => _CommentsViewState();
}

class _CommentsViewState extends ConsumerState<_CommentsView> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  Post? _post;
  List<Comment> _comments = const <Comment>[];
  Comment? _replyingTo;
  bool _isLoading = true;
  bool _isSubmitting = false;
  AppError? _loadError;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final postRes = await ref
        .read(postRepositoryProvider)
        .getPostById(widget.postId);
    final commentRes = await ref
        .read(commentRepositoryProvider)
        .getComments(widget.postId);
    if (!mounted) return;

    postRes.fold(
      onOk: (post) {
        commentRes.fold(
          onOk: (list) => setState(() {
            _post = post;
            _comments = list;
            _isLoading = false;
          }),
          onErr: (err) => setState(() {
            _post = post;
            _loadError = err;
            _isLoading = false;
          }),
        );
      },
      onErr: (err) => setState(() {
        _loadError = err;
        _isLoading = false;
      }),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_inputController.text.trim().isEmpty || _isSubmitting) return;
    HapticFeedback.lightImpact().ignore();
    setState(() {
      _isSubmitting = true;
      _inputError = null;
    });
    final res = await ref
        .read(commentRepositoryProvider)
        .addComment(
          postId: widget.postId,
          text: _inputController.text,
          parentCommentId: _replyingTo?.id,
        );
    if (!mounted) return;

    res.fold(
      onOk: (created) {
        _inputController.clear();
        setState(() {
          _comments = <Comment>[..._comments, created];
          _replyingTo = null;
          _isSubmitting = false;
          if (_post != null) {
            _post = _post!.copyWith(commentCount: _post!.commentCount + 1);
            ref
                .read(homeFeedControllerProvider.notifier)
                .replaceUpdatedPost(_post!);
          }
        });
      },
      onErr: (err) {
        setState(() {
          _isSubmitting = false;
          _inputError = err.message;
        });
      },
    );
  }

  Future<void> _confirmDeleteComment(Comment comment) async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.ber07DeleteCommentTitle,
      message: AppStrings.ber07DeleteCommentMessage,
      confirmLabel: AppStrings.actionDelete,
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    final res = await ref
        .read(commentRepositoryProvider)
        .deleteComment(comment.id);
    if (!mounted) return;
    res.fold(
      onOk: (_) => _loadData(),
      onErr: (err) => AppToast.show(
        context,
        message: err.message,
        variant: AppToastVariant.error,
      ),
    );
  }

  Future<void> _toggleCommentsDisabled() async {
    final post = _post;
    if (post == null) return;
    final res = await ref
        .read(commentRepositoryProvider)
        .setCommentsDisabled(postId: post.id, disabled: !post.commentsDisabled);
    if (!mounted) return;
    res.fold(
      onOk: (updated) {
        setState(() => _post = updated);
        ref
            .read(homeFeedControllerProvider.notifier)
            .replaceUpdatedPost(updated);
      },
      onErr: (err) => AppToast.show(
        context,
        message: err.message,
        variant: AppToastVariant.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final authRepo = ref.watch(authRepositoryProvider);
    final currentUid = authRepo.currentUserId;
    final now = authRepo.currentTime;
    final isPostAuthor = _post != null && _post!.author.id == currentUid;
    final myProfile = authRepo.currentSessionProfile;
    final hasText = _inputController.text.trim().isNotEmpty;

    final topLevel = _comments
        .where((c) => c.parentCommentId == null)
        .toList(growable: false);

    final bodyContent = Column(
      children: <Widget>[
        if (widget.isSheet) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: AppRadius.pillRadius,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    AppStrings.ber07SheetTitle(_comments.length),
                    style: typo.h3,
                  ),
                ),
                if (isPostAuthor)
                  TextButton(
                    onPressed: _toggleCommentsDisabled,
                    child: Text(
                      _post!.commentsDisabled
                          ? AppStrings.ber07EnableComments
                          : AppStrings.ber07DisableComments,
                      style: typo.micro.copyWith(color: colors.accent),
                    ),
                  ),
                IconButton(
                  tooltip: AppStrings.semanticsClose,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    size: AppSizes.iconMd,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: AppSizes.strokeThin,
            color: colors.border.withValues(alpha: 0.55),
          ),
        ],
        Expanded(
          child: _isLoading
              ? const SingleChildScrollView(
                  child: StateView.loading(itemCount: 3),
                )
              : _loadError != null
              ? StateView.fromError(
                  _loadError!,
                  onRetry: _loadData,
                  onBack: () {
                    if (widget.isSheet) {
                      Navigator.of(context).pop();
                    } else {
                      context.go(AppPages.berandaPath);
                    }
                  },
                )
              : topLevel.isEmpty
              ? StateView.empty(
                  message: AppStrings.ber07EmptyMessage,
                  actionLabel: AppStrings.actionRetry,
                  onAction: _loadData,
                )
              : ListView.separated(
                  controller: widget.externalScrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenMargin,
                    vertical: AppSpacing.md,
                  ),
                  itemCount: topLevel.length,
                  separatorBuilder: (_, _) => Divider(
                    height: AppSpacing.lg,
                    color: colors.border.withValues(alpha: 0.35),
                  ),
                  itemBuilder: (context, index) {
                    final parent = topLevel[index];
                    final replies = _comments
                        .where((c) => c.parentCommentId == parent.id)
                        .toList(growable: false);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _CommentTile(
                          comment: parent,
                          now: now,
                          isReply: false,
                          hasReplies: replies.isNotEmpty,
                          canDelete:
                              currentUid != null &&
                              (parent.author.id == currentUid || isPostAuthor),
                          canReply: !(_post?.commentsDisabled ?? false),
                          onReply: () {
                            setState(() => _replyingTo = parent);
                            _inputFocusNode.requestFocus();
                          },
                          onDelete: () => _confirmDeleteComment(parent),
                        ),
                        for (final reply in replies)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.xl + AppSpacing.xs,
                              top: AppSpacing.sm,
                            ),
                            child: _CommentTile(
                              comment: reply,
                              now: now,
                              isReply: true,
                              hasReplies: false,
                              canDelete:
                                  currentUid != null &&
                                  (reply.author.id == currentUid ||
                                      isPostAuthor),
                              canReply: false, // BER-R5: balasan 1 tingkat
                              onDelete: () => _confirmDeleteComment(reply),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        if (_post != null && _post!.commentsDisabled)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            color: colors.chipInactive,
            child: Text(
              AppStrings.ber07CommentsDisabledBanner,
              textAlign: TextAlign.center,
              style: typo.captionStrong,
            ),
          )
        else if (_post != null)
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.sm,
              AppSpacing.screenMargin,
              MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                top: BorderSide(
                  color: colors.border.withValues(alpha: 0.55),
                  width: AppSizes.strokeThin,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_replyingTo != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.chipInactive,
                      borderRadius: AppRadius.buttonRadius,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            AppStrings.ber07ReplyingTo(
                              _replyingTo!.author.displayName,
                            ),
                            style: typo.captionStrong.copyWith(
                              color: colors.accent,
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: AppStrings.semanticsClose,
                          child: InkWell(
                            onTap: () => setState(() => _replyingTo = null),
                            borderRadius: AppRadius.pillRadius,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              child: Icon(
                                Icons.close_rounded,
                                size: AppSizes.iconSm,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (myProfile != null) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: AppAvatar(
                          name: myProfile.displayName,
                          seed: myProfile.avatarSeed,
                          size: AppSizes.avatarSm,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.chipInactive,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: AppTextField(
                          hintText: AppStrings.ber07InputHint,
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          maxLines: 3,
                          maxLength: AppLimits.commentMaxChars,
                          errorText: _inputError,
                          borderless: true,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _submitComment(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Semantics(
                      button: true,
                      label: AppStrings.ber07SendTooltip,
                      child: IconButton(
                        constraints: const BoxConstraints(
                          minWidth: AppSizes.minTouchTarget,
                          minHeight: AppSizes.minTouchTarget,
                        ),
                        tooltip: AppStrings.ber07SendTooltip,
                        onPressed: (_isSubmitting || !hasText)
                            ? null
                            : _submitComment,
                        icon: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: hasText
                                ? colors.buttonPrimary
                                : colors.chipInactive,
                            shape: BoxShape.circle,
                          ),
                          child: _isSubmitting
                              ? Padding(
                                  padding: const EdgeInsets.all(9),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.onPrimary,
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_upward_rounded,
                                  size: AppSizes.iconSm + 2,
                                  color: hasText
                                      ? colors.onPrimary
                                      : colors.textMuted,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_inputController.text.length >
                    AppLimits.commentMaxChars - 120)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_inputController.text.length}/${AppLimits.commentMaxChars}',
                        style: typo.micro,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    if (widget.isSheet) {
      return Material(color: colors.surface, child: bodyContent);
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(AppStrings.ber07Title, style: typo.h2),
        actions: <Widget>[
          if (isPostAuthor)
            Semantics(
              button: true,
              label: _post!.commentsDisabled
                  ? AppStrings.ber07EnableComments
                  : AppStrings.ber07DisableComments,
              child: TextButton(
                onPressed: _toggleCommentsDisabled,
                child: Text(
                  _post!.commentsDisabled
                      ? AppStrings.ber07EnableComments
                      : AppStrings.ber07DisableComments,
                  style: typo.captionStrong.copyWith(color: colors.accent),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(child: bodyContent),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.now,
    required this.isReply,
    required this.hasReplies,
    required this.canDelete,
    required this.canReply,
    this.onReply,
    this.onDelete,
  });

  final Comment comment;
  final DateTime now;
  final bool isReply;
  final bool hasReplies;
  final bool canDelete;
  final bool canReply;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Semantics(
                button: true,
                label: AppStrings.ber01AuthorProfileSemantics(
                  comment.author.displayName,
                ),
                child: InkWell(
                  onTap: () => context.push(
                    '${AppPages.sek04.routePath}?id=${comment.author.id}',
                  ),
                  borderRadius: AppRadius.pillRadius,
                  child: AppAvatar(
                    name: comment.author.displayName,
                    seed: comment.author.avatarSeed,
                    size: isReply ? AppSizes.avatarXs : AppSizes.avatarSm,
                  ),
                ),
              ),
              if (hasReplies) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: colors.border.withValues(alpha: 0.7),
                      borderRadius: AppRadius.pillRadius,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push(
                          '${AppPages.sek04.routePath}?id=${comment.author.id}',
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: comment.author.displayName,
                                style: typo.captionStrong,
                              ),
                              TextSpan(
                                text: ' · ${comment.author.marga}',
                                style: typo.micro.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      RelativeTimeFormatter.format(comment.createdAt, now),
                      style: typo.micro,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs + 1),
                Text(comment.text, style: typo.body),
                if (canReply || canDelete) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      if (canReply)
                        GestureDetector(
                          onTap: onReply,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.md,
                              top: AppSpacing.xxs,
                              bottom: AppSpacing.xxs,
                            ),
                            child: Text(
                              AppStrings.ber07ReplyAction,
                              style: typo.micro.copyWith(
                                color: colors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      if (canDelete)
                        GestureDetector(
                          onTap: onDelete,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xxs,
                            ),
                            child: Text(
                              AppStrings.actionDelete,
                              style: typo.micro.copyWith(
                                color: colors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
