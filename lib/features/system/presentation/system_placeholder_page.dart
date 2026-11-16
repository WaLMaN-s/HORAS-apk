import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:horas/domain/models/system_models.dart';
import 'package:horas/features/system/presentation/sis01_notifications_page.dart';
import 'package:horas/features/system/presentation/sis02_report_page.dart';
import 'package:horas/features/system/presentation/sis03_report_status_page.dart';
import 'package:horas/features/system/presentation/sis04_help_center_page.dart';
import 'package:horas/features/system/presentation/sis05_contact_support_page.dart';
import 'package:horas/features/system/presentation/sis06_verification_submit_page.dart';
import 'package:horas/features/system/presentation/sis07_verification_status_page.dart';
import 'package:horas/features/system/presentation/sis08_guidelines_page.dart';
import 'package:material_ui/material_ui.dart';

/// Controller fondasi modul Sistem (SIS-01 .. SIS-08).
final systemModulePagesProvider = Provider<AppModule>(
  (ref) => AppModule.system,
);

/// Router halaman nyata modul Sistem (`SIS-01` .. `SIS-08`, Prompt 9).
class SystemModulePageRouter extends StatelessWidget {
  const SystemModulePageRouter({
    required this.pageSpec,
    required this.routerState,
    super.key,
  });

  final PageSpec pageSpec;
  final GoRouterState routerState;

  ReportTargetType _parseTargetType(String? raw) {
    for (final t in ReportTargetType.values) {
      if (t.name == raw) return t;
    }
    return ReportTargetType.user;
  }

  @override
  Widget build(BuildContext context) {
    final query = routerState.uri.queryParameters;

    if (pageSpec.id == AppPages.sis01.id) {
      return const Sis01NotificationsPage();
    }
    if (pageSpec.id == AppPages.sis02.id) {
      return Sis02ReportPage(
        targetType: _parseTargetType(query['targetType']),
        targetId: query['targetId'] ?? query['id'] ?? '',
        targetUserId: query['userId'],
      );
    }
    if (pageSpec.id == AppPages.sis03.id) {
      return const Sis03ReportStatusPage();
    }
    if (pageSpec.id == AppPages.sis04.id) {
      return const Sis04HelpCenterPage();
    }
    if (pageSpec.id == AppPages.sis05.id) {
      return Sis05ContactSupportPage(initialCategory: query['category']);
    }
    if (pageSpec.id == AppPages.sis06.id) {
      return Sis06VerificationSubmitPage(
        initialCommunityId: query['communityId'],
      );
    }
    if (pageSpec.id == AppPages.sis07.id) {
      return const Sis07VerificationStatusPage();
    }
    if (pageSpec.id == AppPages.sis08.id) {
      return const Sis08GuidelinesPage();
    }

    return SegeraPage(pageSpec: pageSpec);
  }
}
