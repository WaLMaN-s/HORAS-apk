import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// AKN-05 Pengikut & AKN-06 Mengikuti (berbagi satu widget berparameter).
class Akn05Akn06FollowsPage extends ConsumerStatefulWidget {
  const Akn05Akn06FollowsPage({required this.followersMode, super.key});

  final bool followersMode;

  @override
  ConsumerState<Akn05Akn06FollowsPage> createState() =>
      _Akn05Akn06FollowsPageState();
}

class _Akn05Akn06FollowsPageState extends ConsumerState<Akn05Akn06FollowsPage> {
  List<PersonSummary> _users = const <PersonSummary>[];
  bool _isLoading = true;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final uid = ref.read(authRepositoryProvider).currentUserId ?? '';
    final repo = ref.read(followRepositoryProvider);
    final res = widget.followersMode
        ? await repo.getFollowers(uid)
        : await repo.getFollowing(uid);
    if (!mounted) return;
    if (res is Err<List<PersonSummary>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }
    setState(() {
      _users = (res as Ok<List<PersonSummary>>).value;
      _isLoading = false;
    });
  }

  Future<void> _unfollow(String targetId) async {
    await ref.read(followRepositoryProvider).unfollowUser(targetId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.followersMode
        ? AppStrings.akn05Title
        : AppStrings.akn06Title;
    final emptyMessage = widget.followersMode
        ? AppStrings.akn05EmptyFollowers
        : AppStrings.akn06EmptyFollowing;

    Widget body;
    if (_isLoading) {
      body = const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _load);
    } else if (_users.isEmpty) {
      body = StateView.empty(
        message: emptyMessage,
        actionLabel: AppStrings.actionExploreNearby,
        onAction: () => context.go(AppPages.sek01.routePath),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _users.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (ctx, index) {
            final u = _users[index];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                onTap: () => context
                    .push('${AppPages.sek04.routePath}?userId=${u.id}')
                    .ignore(),
                leading: AppAvatar(name: u.displayName, seed: u.avatarSeed),
                title: Text(
                  '${u.displayName} · ${u.marga}',
                  style: context.typo.bodyStrong,
                ),
                subtitle: Text(
                  u.city,
                  style: context.typo.caption.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                trailing: widget.followersMode
                    ? null
                    : TextButton(
                        onPressed: () => _unfollow(u.id),
                        child: const Text(AppStrings.akn06UnfollowBtn),
                      ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: body),
    );
  }
}
