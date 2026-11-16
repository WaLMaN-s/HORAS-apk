import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// AKN-03 Postingan Saya & AKN-04 Postingan Tersimpan (`AKN-R1`).
class Akn03Akn04PostsPage extends ConsumerStatefulWidget {
  const Akn03Akn04PostsPage({required this.savedOnly, super.key});

  final bool savedOnly;

  @override
  ConsumerState<Akn03Akn04PostsPage> createState() =>
      _Akn03Akn04PostsPageState();
}

class _Akn03Akn04PostsPageState extends ConsumerState<Akn03Akn04PostsPage> {
  List<Post> _posts = const <Post>[];
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

    final postRepo = ref.read(postRepositoryProvider);
    if (widget.savedOnly) {
      final res = await postRepo.getSavedPosts();
      if (!mounted) return;
      if (res is Err<List<SavedPost>>) {
        setState(() {
          _isLoading = false;
          _error = res.failure;
        });
        return;
      }
      setState(() {
        _posts = (res as Ok<List<SavedPost>>).value
            .map((s) => s.post)
            .toList(growable: false);
        _isLoading = false;
      });
      return;
    }

    final uid = ref.read(authRepositoryProvider).currentUserId ?? '';
    final res = await postRepo.getUserPosts(uid);
    if (!mounted) return;
    if (res is Err<List<Post>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }
    setState(() {
      _posts = (res as Ok<List<Post>>).value;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(authRepositoryProvider).currentTime;
    final uid = ref.read(authRepositoryProvider).currentUserId ?? '';
    final title = widget.savedOnly
        ? AppStrings.akn04Title
        : AppStrings.akn03Title;
    final emptyMsg = widget.savedOnly
        ? AppStrings.akn01EmptySaved
        : AppStrings.akn01EmptyPosts;

    Widget body;
    if (_isLoading) {
      body = const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _load);
    } else if (_posts.isEmpty) {
      body = StateView.empty(
        message: emptyMsg,
        actionLabel: AppStrings.actionRetry,
        onAction: _load,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _posts.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (ctx, index) {
            final post = _posts[index];
            return PostCard(
              post: post,
              now: now,
              isOwnPost: post.author.id == uid,
              onTapCard: () => context
                  .push('${AppPages.ber06.routePath}?postId=${post.id}')
                  .ignore(),
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
