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

/// BER-07 Komentar: daftar + balasan satu tingkat, kolom tulis maksimal 1.000 karakter,
/// batas 60 komentar/jam, hapus komentar sendiri, serta kontrol pembuat postingan
/// (matikan komentar & hapus komentar di postingannya — BER-R5).
class Ber07CommentsPage extends ConsumerStatefulWidget {
  const Ber07CommentsPage({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<Ber07CommentsPage> createState() => _Ber07CommentsPageState();
}

class _Ber07CommentsPageState extends ConsumerState<Ber07CommentsPage> {
  final TextEditingController _inputController = TextEditingController();
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
    super.dispose();
  }

  Future<void> _submitComment() async {
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

    final topLevel = _comments
        .where((c) => c.parentCommentId == null)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
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
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: _isLoading
                  ? const SingleChildScrollView(
                      child: StateView.loading(itemCount: 3),
                    )
                  : _loadError != null
                  ? StateView.fromError(
                      _loadError!,
                      onRetry: _loadData,
                      onBack: () => context.go(AppPages.berandaPath),
                    )
                  : topLevel.isEmpty
                  ? StateView.empty(
                      message: AppStrings.ber07EmptyMessage,
                      actionLabel: AppStrings.actionRetry,
                      onAction: _loadData,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.screenMargin),
                      itemCount: topLevel.length,
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
                              canDelete:
                                  currentUid != null &&
                                  (parent.author.id == currentUid ||
                                      isPostAuthor),
                              canReply: !(_post?.commentsDisabled ?? false),
                              onReply: () =>
                                  setState(() => _replyingTo = parent),
                              onDelete: () => _confirmDeleteComment(parent),
                            ),
                            for (final reply in replies)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: AppSpacing.xxl,
                                ),
                                child: _CommentTile(
                                  comment: reply,
                                  now: now,
                                  isReply: true,
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.sm,
                  AppSpacing.screenMargin,
                  AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_replyingTo != null)
                      Row(
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
                            child: IconButton(
                              tooltip: AppStrings.semanticsClose,
                              onPressed: () =>
                                  setState(() => _replyingTo = null),
                              icon: const Icon(
                                Icons.close_rounded,
                                size: AppSizes.iconSm,
                              ),
                            ),
                          ),
                        ],
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: AppTextField(
                            hintText: AppStrings.ber07InputHint,
                            controller: _inputController,
                            maxLines: 3,
                            maxLength: AppLimits.commentMaxChars,
                            errorText: _inputError,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Semantics(
                          button: true,
                          label: AppStrings.ber07SendTooltip,
                          child: IconButton(
                            constraints: const BoxConstraints(
                              minWidth: AppSizes.minTouchTarget,
                              minHeight: AppSizes.minTouchTarget,
                            ),
                            tooltip: AppStrings.ber07SendTooltip,
                            onPressed: _isSubmitting ? null : _submitComment,
                            icon: Icon(
                              Icons.send_rounded,
                              color: colors.buttonPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_inputController.text.length}/${AppLimits.commentMaxChars}',
                        style: typo.micro,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.now,
    required this.isReply,
    required this.canDelete,
    required this.canReply,
    this.onReply,
    this.onDelete,
  });

  final Comment comment;
  final DateTime now;
  final bool isReply;
  final bool canDelete;
  final bool canReply;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppAvatar(
            name: comment.author.displayName,
            seed: comment.author.avatarSeed,
            size: isReply ? AppSizes.avatarXs : AppSizes.avatarSm,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${comment.author.displayName} · ${comment.author.marga}',
                          style: typo.captionStrong,
                        ),
                      ),
                      Text(
                        RelativeTimeFormatter.format(comment.createdAt, now),
                        style: typo.micro,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(comment.text, style: typo.body),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      if (canReply)
                        AppButton(
                          label: AppStrings.ber07ReplyAction,
                          variant: AppButtonVariant.text,
                          onPressed: onReply,
                        ),
                      if (canDelete)
                        AppButton(
                          label: AppStrings.actionDelete,
                          variant: AppButtonVariant.text,
                          isDestructive: true,
                          onPressed: onDelete,
                        ),
                    ],
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
