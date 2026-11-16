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
import 'package:material_ui/material_ui.dart';

/// BER-08 Daftar Suka: menampilkan siapa yang menyukai postingan,
/// dan tidak menampilkan akun yang saling memblokir dengan pelihat (BER-R6).
class Ber08LikesPage extends ConsumerStatefulWidget {
  const Ber08LikesPage({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<Ber08LikesPage> createState() => _Ber08LikesPageState();
}

class _Ber08LikesPageState extends ConsumerState<Ber08LikesPage> {
  List<Like> _likes = const <Like>[];
  AppError? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLikes();
  }

  Future<void> _loadLikes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final res = await ref
        .read(postRepositoryProvider)
        .getPostLikes(widget.postId);
    if (!mounted) return;
    res.fold(
      onOk: (list) => setState(() {
        _likes = list;
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
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.ber08Title, style: typo.h2)),
      body: SafeArea(
        child: _isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : _error != null
            ? StateView.fromError(
                _error!,
                onRetry: _loadLikes,
                onBack: () => context.go(AppPages.berandaPath),
              )
            : _likes.isEmpty
            ? StateView.empty(
                message: AppStrings.ber08EmptyMessage,
                actionLabel: AppStrings.actionRetry,
                onAction: _loadLikes,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                itemCount: _likes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final user = _likes[index].user;
                  final partuturan = user.partuturan;
                  final showBadge =
                      partuturan != null && !partuturan.modeNetral;

                  return Material(
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.cardRadius,
                      side: BorderSide(color: colors.border),
                    ),
                    child: InkWell(
                      borderRadius: AppRadius.cardRadius,
                      onTap: () => context.push(
                        '${AppPages.sek04.routePath}?id=${user.id}',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: <Widget>[
                            AppAvatar(
                              name: user.displayName,
                              seed: user.avatarSeed,
                              size: AppSizes.avatarMd,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    user.displayName,
                                    style: typo.bodyStrong,
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    '${user.marga} · ${user.city}',
                                    style: typo.caption,
                                  ),
                                ],
                              ),
                            ),
                            if (showBadge)
                              PartuturanBadge(
                                result: partuturan,
                                onTap: () => context.push(
                                  '${AppPages.tar05.routePath}?userId=${user.id}',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
