import 'package:go_router/go_router.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:horas/features/home/presentation/ber01_feed_page.dart';
import 'package:horas/features/home/presentation/ber04_create_post_page.dart';
import 'package:horas/features/home/presentation/ber05_media_picker_page.dart';
import 'package:horas/features/home/presentation/ber06_post_detail_page.dart';
import 'package:horas/features/home/presentation/ber07_comments_page.dart';
import 'package:horas/features/home/presentation/ber08_likes_page.dart';
import 'package:horas/features/home/presentation/ber09_search_page.dart';
import 'package:horas/features/home/presentation/ber10_search_results_page.dart';
import 'package:horas/features/home/presentation/home_models.dart';
import 'package:material_ui/material_ui.dart';

export 'ber01_feed_page.dart';
export 'ber04_create_post_page.dart';
export 'ber05_media_picker_page.dart';
export 'ber06_post_detail_page.dart';
export 'ber07_comments_page.dart';
export 'ber08_likes_page.dart';
export 'ber09_search_page.dart';
export 'ber10_search_results_page.dart';
export 'home_feed_controller.dart';
export 'home_models.dart';

/// Builder halaman modul Beranda (`BER-01`, `BER-04` .. `BER-10` — Prompt 4).
///
/// Halaman Fase 2 (`BER-02`, `BER-03`) tetap ditangani oleh [SegeraPage]
/// yang memeriksa `FeatureFlags.stories` dan menyembunyikannya saat `false`.
class HomeModulePageRouter extends StatelessWidget {
  const HomeModulePageRouter({
    required this.pageSpec,
    required this.routerState,
    super.key,
    this.tabIndex,
  });

  final PageSpec pageSpec;
  final GoRouterState routerState;
  final int? tabIndex;

  @override
  Widget build(BuildContext context) {
    final postId = routerState.uri.queryParameters['id'] ?? '';
    final query = routerState.uri.queryParameters['q'] ?? '';

    if (pageSpec.id == AppPages.ber01.id) {
      return Ber01FeedPage(tabIndex: tabIndex ?? 0);
    }
    if (pageSpec.id == AppPages.ber04.id) {
      return const Ber04CreatePostPage();
    }
    if (pageSpec.id == AppPages.ber05.id) {
      final initialMedia =
          routerState.extra as List<SelectedMediaItem>? ??
          const <SelectedMediaItem>[];
      return Ber05MediaPickerPage(initialMedia: initialMedia);
    }
    if (pageSpec.id == AppPages.ber06.id) {
      return Ber06PostDetailPage(postId: postId);
    }
    if (pageSpec.id == AppPages.ber07.id) {
      return Ber07CommentsPage(postId: postId);
    }
    if (pageSpec.id == AppPages.ber08.id) {
      return Ber08LikesPage(postId: postId);
    }
    if (pageSpec.id == AppPages.ber09.id) {
      return const Ber09SearchPage();
    }
    if (pageSpec.id == AppPages.ber10.id) {
      return Ber10SearchResultsPage(initialQuery: query);
    }
    return SegeraPage(pageSpec: pageSpec, tabIndex: tabIndex);
  }
}
