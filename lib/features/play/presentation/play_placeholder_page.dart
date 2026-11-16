import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:horas/features/play/presentation/man01_play_page.dart';
import 'package:horas/features/play/presentation/man02_filter_page.dart';
import 'package:horas/features/play/presentation/man03_create_session_page.dart';
import 'package:horas/features/play/presentation/man04_session_detail_page.dart';
import 'package:horas/features/play/presentation/man05_participants_page.dart';
import 'package:horas/features/play/presentation/man06_patungan_page.dart';
import 'package:horas/features/play/presentation/man07_courts_list_page.dart';
import 'package:horas/features/play/presentation/man08_court_detail_page.dart';
import 'package:horas/features/play/presentation/man09_history_page.dart';
import 'package:material_ui/material_ui.dart';

/// Controller fondasi modul Main (MAN-01 .. MAN-09).
final playModulePagesProvider = Provider<AppModule>((ref) => AppModule.play);

/// Router halaman nyata modul Main (`MAN-01` .. `MAN-09`, Prompt 7).
class PlayModulePageRouter extends StatelessWidget {
  const PlayModulePageRouter({
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
    final query = routerState.uri.queryParameters;
    final sessionId = query['sessionId'] ?? query['id'] ?? '';
    final courtId = query['courtId'] ?? query['id'];

    if (pageSpec.id == AppPages.man01.id) {
      return Man01PlayPage(tabIndex: tabIndex ?? 3);
    }
    if (pageSpec.id == AppPages.man02.id) {
      return const Man02FilterPage();
    }
    if (pageSpec.id == AppPages.man03.id) {
      return const Man03CreateSessionPage();
    }
    if (pageSpec.id == AppPages.man04.id) {
      return Man04SessionDetailPage(sessionId: sessionId);
    }
    if (pageSpec.id == AppPages.man05.id) {
      return Man05ParticipantsPage(sessionId: sessionId);
    }
    if (pageSpec.id == AppPages.man06.id) {
      return Man06PatunganPage(sessionId: sessionId);
    }
    if (pageSpec.id == AppPages.man07.id) {
      return const Man07CourtsListPage();
    }
    if (pageSpec.id == AppPages.man08.id) {
      return Man08CourtDetailPage(
        courtId: courtId,
        proposeMode: query['propose'] == 'true',
      );
    }
    if (pageSpec.id == AppPages.man09.id) {
      return const Man09HistoryPage();
    }

    return SegeraPage(pageSpec: pageSpec, tabIndex: tabIndex);
  }
}
