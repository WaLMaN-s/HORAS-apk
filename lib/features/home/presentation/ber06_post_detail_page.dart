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
import 'package:horas/features/home/presentation/home_feed_controller.dart';
import 'package:material_ui/material_ui.dart';

/// BER-06 Detail Postingan (BER-R7, BER-R8, BER-R9, PRD 5.2).
///
/// Menangani suka, komentar, simpan, bagikan (tautan postingan terbatas tetap tidak dapat
/// dibuka tanpa hak), menu Laporkan (`/report`) / Bisukan / Blokir, edit teks ("Diedit"),
/// hapus dengan dialog konfirmasi, dan status konten tidak tersedia (netral).
class Ber06PostDetailPage extends ConsumerStatefulWidget {
  const Ber06PostDetailPage({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<Ber06PostDetailPage> createState() =>
      _Ber06PostDetailPageState();
}

class _Ber06PostDetailPageState extends ConsumerState<Ber06PostDetailPage> {
  Post? _post;
  AppError? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final res = await ref
        .read(postRepositoryProvider)
        .getPostById(widget.postId);
    if (!mounted) return;
    res.fold(
      onOk: (post) => setState(() {
        _post = post;
        _isLoading = false;
      }),
      onErr: (err) => setState(() {
        _error = err;
        _isLoading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    final authRepo = ref.watch(authRepositoryProvider);
    final now = authRepo.currentTime;
    final currentUid = authRepo.currentUserId;

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title: Text(AppStrings.ber06Title, style: typo.h2),
      ),
      body: SafeArea(
        child: _isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 1),
              )
            : _error != null || _post == null
            ? StateView.fromError(
                _error ??
                    const UnavailableError(
                      message: AppStrings.stateContentUnavailableMessage,
                    ),
                onRetry: _loadPost,
                onBack: () => context.go(AppPages.berandaPath),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: <Widget>[
                  PostCard(
                    post: _post!,
                    now: now,
                    isOwnPost: _post!.author.id == currentUid,
                    onLikeTap: () async {
                      final res = await ref
                          .read(homeFeedControllerProvider.notifier)
                          .toggleLike(_post!.id);
                      res.fold(
                        onOk: (updated) => setState(() => _post = updated),
                        onErr: (_) {},
                      );
                    },
                    onSaveTap: () async {
                      final res = await ref
                          .read(homeFeedControllerProvider.notifier)
                          .toggleSave(_post!.id);
                      res.fold(
                        onOk: (updated) => setState(() => _post = updated),
                        onErr: (_) {},
                      );
                    },
                    onCommentTap: () async {
                      await context.push(
                        '${AppPages.ber07.routePath}?id=${_post!.id}',
                      );
                      await _loadPost();
                    },
                    onLikesCountTap: () => context.push(
                      '${AppPages.ber08.routePath}?id=${_post!.id}',
                    ),
                    onReportTap: () => context.push('/report'),
                    onMuteTap: () => _confirmMuteOrBlock(isBlock: false),
                    onBlockTap: () => _confirmMuteOrBlock(isBlock: true),
                    onEditTextTap: _openEditTextSheet,
                    onDeleteTap: _confirmDelete,
                  ),
                  Divider(
                    height: AppSizes.strokeThin,
                    thickness: AppSizes.strokeThin,
                    color: context.colors.border.withValues(alpha: 0.55),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenMargin),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: AppButton(
                            label: AppStrings.ber06ViewLikesAction,
                            variant: AppButtonVariant.secondary,
                            isExpanded: true,
                            onPressed: () => context.push(
                              '${AppPages.ber08.routePath}?id=${_post!.id}',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            label:
                                '${AppStrings.ber07Title} (${_post!.commentCount})',
                            isExpanded: true,
                            onPressed: () async {
                              await context.push(
                                '${AppPages.ber07.routePath}?id=${_post!.id}',
                              );
                              await _loadPost();
                            },
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

  Future<void> _confirmMuteOrBlock({required bool isBlock}) async {
    final post = _post;
    if (post == null) return;
    final ok = await ConfirmDialog.show(
      context,
      title: isBlock
          ? AppStrings.ber01BlockConfirmTitle
          : AppStrings.ber01MuteConfirmTitle,
      message: isBlock
          ? AppStrings.ber01BlockConfirmMessage
          : AppStrings.ber01MuteConfirmMessage,
      confirmLabel: isBlock
          ? AppStrings.ber01MenuBlock
          : AppStrings.ber01MenuMute,
      isDestructive: isBlock,
    );
    if (!ok || !mounted) return;
    final res = await ref
        .read(homeFeedControllerProvider.notifier)
        .blockOrMuteUser(post.author.id);
    if (mounted && res.isOk) {
      AppToast.show(
        context,
        message: isBlock
            ? AppStrings.ber01AccountBlockedToast
            : AppStrings.ber01AccountMutedToast,
        variant: AppToastVariant.info,
      );
      context.pop();
    }
  }

  Future<void> _openEditTextSheet() async {
    final post = _post;
    if (post == null) return;
    final controller = TextEditingController(text: post.text);
    String? errMsg;

    await AppBottomSheet.show<void>(
      context,
      title: AppStrings.ber06EditTextTitle,
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                controller: controller,
                maxLines: 5,
                maxLength: 2000,
                errorText: errMsg,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: AppStrings.actionSave,
                isExpanded: true,
                onPressed: () async {
                  final res = await ref
                      .read(homeFeedControllerProvider.notifier)
                      .editPostText(postId: post.id, newText: controller.text);
                  if (!sheetContext.mounted) return;
                  res.fold(
                    onOk: (updated) {
                      setState(() => _post = updated);
                      Navigator.of(sheetContext).pop();
                    },
                    onErr: (err) => setSheetState(() => errMsg = err.message),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
  }

  Future<void> _confirmDelete() async {
    final post = _post;
    if (post == null) return;
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.ber01DeleteConfirmTitle,
      message: AppStrings.ber01DeleteConfirmMessage,
      confirmLabel: AppStrings.actionDelete,
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    final res = await ref
        .read(homeFeedControllerProvider.notifier)
        .deletePost(post.id);
    if (mounted && res.isOk) {
      AppToast.show(
        context,
        message: AppStrings.ber01PostDeletedToast,
        variant: AppToastVariant.success,
      );
      context.pop();
    }
  }
}
