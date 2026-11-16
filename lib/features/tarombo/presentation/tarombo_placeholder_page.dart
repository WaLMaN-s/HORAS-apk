import 'package:go_router/go_router.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:horas/features/tarombo/presentation/tar01_dashboard_page.dart';
import 'package:horas/features/tarombo/presentation/tar02_tree_page.dart';
import 'package:horas/features/tarombo/presentation/tar03_member_form_page.dart';
import 'package:horas/features/tarombo/presentation/tar04_member_detail_page.dart';
import 'package:horas/features/tarombo/presentation/tar05_relationship_detail_page.dart';
import 'package:horas/features/tarombo/presentation/tar06_check_partuturan_page.dart';
import 'package:horas/features/tarombo/presentation/tar07_confirmations_page.dart';
import 'package:material_ui/material_ui.dart';

export 'tar01_dashboard_page.dart';
export 'tar02_tree_page.dart';
export 'tar03_member_form_page.dart';
export 'tar04_member_detail_page.dart';
export 'tar05_relationship_detail_page.dart';
export 'tar06_check_partuturan_page.dart';
export 'tar07_confirmations_page.dart';
export 'tarombo_consent_sheet.dart';
export 'tarombo_controller.dart';

/// Builder halaman modul Tarombo (`TAR-01` .. `TAR-07` — Prompt 6).
///
/// Halaman Fase 2 (`TAR-08` Kamus Partuturan) tetap ditangani oleh [SegeraPage]
/// yang memeriksa `FeatureFlags.partuturanDictionary` dan menyembunyikannya saat `false`.
class TaromboModulePageRouter extends StatelessWidget {
  const TaromboModulePageRouter({
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
    final params = routerState.uri.queryParameters;
    final id = params['id'] ?? '';
    final userId = params['userId'] ?? '';

    if (pageSpec.id == AppPages.tar01.id) {
      return Tar01DashboardPage(tabIndex: tabIndex ?? 2);
    }
    if (pageSpec.id == AppPages.tar02.id) {
      return const Tar02TreePage();
    }
    if (pageSpec.id == AppPages.tar03.id) {
      return Tar03MemberFormPage(memberId: id, initialTypeRaw: params['type']);
    }
    if (pageSpec.id == AppPages.tar04.id) {
      return Tar04MemberDetailPage(memberId: id);
    }
    if (pageSpec.id == AppPages.tar05.id) {
      return Tar05RelationshipDetailPage(targetUserId: userId);
    }
    if (pageSpec.id == AppPages.tar06.id) {
      return const Tar06CheckPartuturanPage();
    }
    if (pageSpec.id == AppPages.tar07.id) {
      return Tar07ConfirmationsPage(
        initialTargetUserId: params['targetId'],
        initialClaimedTerm: params['term'],
      );
    }
    return SegeraPage(pageSpec: pageSpec, tabIndex: tabIndex);
  }
}
