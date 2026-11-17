import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:horas/features/nearby/presentation/sek01_nearby_page.dart';
import 'package:horas/features/nearby/presentation/sek02_people_list_page.dart';
import 'package:horas/features/nearby/presentation/sek03_people_filter_page.dart';
import 'package:horas/features/nearby/presentation/sek04_person_profile_page.dart';
import 'package:horas/features/nearby/presentation/sek05_communities_list_page.dart';
import 'package:horas/features/nearby/presentation/sek06_community_detail_page.dart';
import 'package:horas/features/nearby/presentation/sek07_create_community_page.dart';
import 'package:horas/features/nearby/presentation/sek08_manage_community_page.dart';
import 'package:horas/features/nearby/presentation/sek09_event_detail_page.dart';
import 'package:horas/features/nearby/presentation/sek10_church_list_page.dart';
import 'package:horas/features/nearby/presentation/sek11_church_detail_page.dart';
import 'package:horas/features/nearby/presentation/sek12_search_page.dart';
import 'package:material_ui/material_ui.dart';

export 'nearby_controller.dart';
export 'nearby_models.dart';
export 'nearby_widgets.dart';
export 'sek01_nearby_page.dart';
export 'sek02_people_list_page.dart';
export 'sek03_people_filter_page.dart';
export 'sek04_person_profile_page.dart';
export 'sek05_communities_list_page.dart';
export 'sek06_community_detail_page.dart';
export 'sek07_create_community_page.dart';
export 'sek08_manage_community_page.dart';
export 'sek09_event_detail_page.dart';
export 'sek10_church_list_page.dart';
export 'sek11_church_detail_page.dart';
export 'sek12_search_page.dart';

/// Builder halaman modul Sekitar (`SEK-01` .. `SEK-12`).
///
/// Halaman Fase 2 (`SEK-09`, `SEK-10`, `SEK-11`) ditangani bila `FeatureFlags` terkait bernilai `true`,
/// dan menampilkan [SegeraPage] yang menyembunyikan UI saat `false`.
class NearbyModulePageRouter extends ConsumerWidget {
  const NearbyModulePageRouter({
    required this.pageSpec,
    required this.routerState,
    super.key,
    this.tabIndex,
  });

  final PageSpec pageSpec;
  final GoRouterState routerState;
  final int? tabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider);
    if (!pageSpec.isAvailable(flags)) {
      return SegeraPage(pageSpec: pageSpec, tabIndex: tabIndex);
    }

    final id = routerState.uri.queryParameters['id'] ?? '';

    if (pageSpec.id == AppPages.sek01.id) {
      return Sek01NearbyPage(tabIndex: tabIndex ?? 1);
    }
    if (pageSpec.id == AppPages.sek02.id) {
      return const Sek02PeopleListPage();
    }
    if (pageSpec.id == AppPages.sek03.id) {
      return const Sek03PeopleFilterPage();
    }
    if (pageSpec.id == AppPages.sek04.id) {
      return Sek04PersonProfilePage(userId: id);
    }
    if (pageSpec.id == AppPages.sek05.id) {
      return const Sek05CommunitiesListPage();
    }
    if (pageSpec.id == AppPages.sek06.id) {
      return Sek06CommunityDetailPage(communityId: id);
    }
    if (pageSpec.id == AppPages.sek07.id) {
      return const Sek07CreateCommunityPage();
    }
    if (pageSpec.id == AppPages.sek08.id) {
      return Sek08ManageCommunityPage(communityId: id);
    }
    if (pageSpec.id == AppPages.sek09.id) {
      return Sek09EventDetailPage(eventId: id);
    }
    if (pageSpec.id == AppPages.sek10.id) {
      return const Sek10ChurchListPage();
    }
    if (pageSpec.id == AppPages.sek11.id) {
      return Sek11ChurchDetailPage(churchId: id);
    }
    if (pageSpec.id == AppPages.sek12.id) {
      return const Sek12SearchPage();
    }
    return SegeraPage(pageSpec: pageSpec, tabIndex: tabIndex);
  }
}
