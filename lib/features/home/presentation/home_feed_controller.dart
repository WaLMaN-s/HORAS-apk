import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/domain/models/models.dart';

/// State untuk layar Feed Beranda (`BER-01`).
final class HomeFeedState {
  const HomeFeedState({
    this.posts = const <Post>[],
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
    this.isOfflineWithCache = false,
    this.currentUserId,
    this.myProfile,
  });

  final List<Post> posts;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final AppError? error;
  final bool isOfflineWithCache;
  final String? currentUserId;
  final Profil? myProfile;

  HomeFeedState copyWith({
    List<Post>? posts,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    AppError? error,
    bool clearError = false,
    bool? isOfflineWithCache,
    String? currentUserId,
    Profil? myProfile,
  }) {
    return HomeFeedState(
      posts: posts ?? this.posts,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: clearError ? null : (error ?? this.error),
      isOfflineWithCache: isOfflineWithCache ?? this.isOfflineWithCache,
      currentUserId: currentUserId ?? this.currentUserId,
      myProfile: myProfile ?? this.myProfile,
    );
  }
}

/// Controller Riverpod untuk Feed Beranda (`BER-01`, `BER-R1`, `AC-15`).
class HomeFeedController extends Notifier<HomeFeedState> {
  static const int _pageSize = 8;

  @override
  HomeFeedState build() {
    ref.watch(authSessionEpochProvider);
    Future<void>.microtask(loadInitial);
    return HomeFeedState(
      currentUserId: ref.read(authRepositoryProvider).currentUserId,
    );
  }

  Future<void> loadInitial() async {
    final postRepo = ref.read(postRepositoryProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final profileRepo = ref.read(profileRepositoryProvider);

    state = state.copyWith(
      isInitialLoading: true,
      clearError: true,
      isOfflineWithCache: false,
      currentUserId: authRepo.currentUserId,
    );

    final feedFuture = postRepo.getFeed(page: 1, pageSize: _pageSize);
    final profileFuture = profileRepo.getMyProfile();
    final res = await feedFuture;
    final profileRes = await profileFuture;
    final loadedProfile = profileRes is Ok<Profil> ? profileRes.value : null;

    res.fold(
      onOk: (items) {
        state = state.copyWith(
          posts: items,
          isInitialLoading: false,
          hasMore: items.length >= _pageSize,
          currentPage: 1,
          clearError: true,
          isOfflineWithCache: false,
          myProfile: loadedProfile,
        );
      },
      onErr: (err) {
        if (err is OfflineError) {
          final cached = postRepo.getCachedFeedPage1();
          if (cached.isNotEmpty) {
            // AC-15: Data tersimpan tampil dengan penanda dan tombol Coba lagi
            state = state.copyWith(
              posts: cached,
              isInitialLoading: false,
              hasMore: false,
              error: err,
              isOfflineWithCache: true,
              myProfile: loadedProfile,
            );
            return;
          }
        }
        state = state.copyWith(
          isInitialLoading: false,
          error: err,
          isOfflineWithCache: false,
          myProfile: loadedProfile,
        );
      },
    );
  }

  Future<void> refresh() async {
    ref.read(storiesRefreshTickProvider.notifier).bump();
    await loadInitial();
  }

  /// Sinkronisasi langsung perubahan profil diri sendiri ke header komposer & daftar postingan.
  void syncMyProfile(Profil updated) {
    final nextPosts = state.posts
        .map(
          (p) => p.author.id == updated.id
              ? p.copyWith(
                  author: p.author.copyWith(
                    displayName: updated.displayName,
                    avatarSeed: updated.avatarSeed,
                    city: updated.city,
                    bio: updated.bio,
                  ),
                )
              : p,
        )
        .toList(growable: false);
    state = state.copyWith(
      myProfile: updated,
      currentUserId: updated.id,
      posts: nextPosts,
    );
    ref.read(storiesRefreshTickProvider.notifier).bump();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isInitialLoading) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.currentPage + 1;
    final res = await ref
        .read(postRepositoryProvider)
        .getFeed(page: nextPage, pageSize: _pageSize);

    res.fold(
      onOk: (items) {
        final merged = <Post>[...state.posts, ...items];
        state = state.copyWith(
          posts: merged,
          isLoadingMore: false,
          hasMore: items.length >= _pageSize,
          currentPage: nextPage,
        );
      },
      onErr: (_) {
        state = state.copyWith(isLoadingMore: false);
      },
    );
  }

  void prependCreatedPost(Post post) {
    final nextList = <Post>[post, ...state.posts.where((p) => p.id != post.id)];
    state = state.copyWith(
      posts: nextList,
      clearError: true,
      isOfflineWithCache: false,
    );
  }

  void replaceUpdatedPost(Post updated) {
    final nextList = state.posts
        .map((p) => p.id == updated.id ? updated : p)
        .toList(growable: false);
    state = state.copyWith(posts: nextList);
  }

  void removePostFromList(String postId) {
    final nextList = state.posts
        .where((p) => p.id != postId)
        .toList(growable: false);
    state = state.copyWith(posts: nextList);
  }

  Future<Result<Post>> toggleLike(String postId) async {
    final res = await ref.read(postRepositoryProvider).toggleLike(postId);
    if (res is Ok<Post>) {
      replaceUpdatedPost(res.value);
    }
    return res;
  }

  Future<Result<Post>> toggleSave(String postId) async {
    final res = await ref.read(postRepositoryProvider).toggleSavePost(postId);
    if (res is Ok<Post>) {
      replaceUpdatedPost(res.value);
    }
    return res;
  }

  Future<Result<void>> deletePost(String postId) async {
    final res = await ref.read(postRepositoryProvider).deletePost(postId);
    if (res.isOk) {
      removePostFromList(postId);
    }
    return res;
  }

  Future<Result<Post>> editPostText({
    required String postId,
    required String newText,
  }) async {
    final res = await ref
        .read(postRepositoryProvider)
        .editPostText(postId: postId, newText: newText);
    if (res is Ok<Post>) {
      replaceUpdatedPost(res.value);
    }
    return res;
  }

  /// Aksi Bisukan akun atau Blokir memakai `BlockRepository` sesuai ketentuan prompt.
  Future<Result<Block>> blockOrMuteUser(String targetUserId) async {
    final res = await ref.read(blockRepositoryProvider).blockUser(targetUserId);
    if (res.isOk) {
      final filtered = state.posts
          .where((p) => p.author.id != targetUserId)
          .toList(growable: false);
      state = state.copyWith(posts: filtered);
    }
    return res;
  }
}

/// Provider global untuk [HomeFeedController].
final homeFeedControllerProvider =
    NotifierProvider<HomeFeedController, HomeFeedState>(HomeFeedController.new);

/// Pemicu muat-ulang daftar Story (`BER-01` & `BER-03`) saat cerita baru dibuat atau profil berubah.
class StoriesRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final storiesRefreshTickProvider =
    NotifierProvider<StoriesRefreshTickNotifier, int>(
      StoriesRefreshTickNotifier.new,
    );
