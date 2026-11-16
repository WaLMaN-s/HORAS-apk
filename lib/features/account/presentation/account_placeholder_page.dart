import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:horas/features/account/presentation/akn01_my_profile_page.dart';
import 'package:horas/features/account/presentation/akn02_edit_profile_page.dart';
import 'package:horas/features/account/presentation/akn03_akn04_my_posts_pages.dart';
import 'package:horas/features/account/presentation/akn05_akn06_follows_pages.dart';
import 'package:horas/features/account/presentation/akn07_settings_page.dart';
import 'package:horas/features/account/presentation/akn08_privacy_page.dart';
import 'package:horas/features/account/presentation/akn09_security_page.dart';
import 'package:horas/features/account/presentation/akn10_notification_prefs_page.dart';
import 'package:horas/features/account/presentation/akn11_blocked_users_page.dart';
import 'package:horas/features/account/presentation/akn12_connections_page.dart';
import 'package:horas/features/account/presentation/akn13_data_export_page.dart';
import 'package:horas/features/account/presentation/akn14_delete_account_page.dart';
import 'package:horas/features/account/presentation/akn15_about_page.dart';
import 'package:material_ui/material_ui.dart';

/// Controller fondasi modul Akun (AKN-01 .. AKN-15).
final accountModulePagesProvider = Provider<AppModule>(
  (ref) => AppModule.account,
);

/// Router halaman nyata modul Akun (`AKN-01` .. `AKN-15`, Prompt 9).
class AccountModulePageRouter extends StatelessWidget {
  const AccountModulePageRouter({
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
    if (pageSpec.id == AppPages.akn01.id) {
      return Akn01MyProfilePage(tabIndex: tabIndex ?? 4);
    }
    if (pageSpec.id == AppPages.akn02.id) {
      return const Akn02EditProfilePage();
    }
    if (pageSpec.id == AppPages.akn03.id) {
      return const Akn03Akn04PostsPage(savedOnly: false);
    }
    if (pageSpec.id == AppPages.akn04.id) {
      return const Akn03Akn04PostsPage(savedOnly: true);
    }
    if (pageSpec.id == AppPages.akn05.id) {
      return const Akn05Akn06FollowsPage(followersMode: true);
    }
    if (pageSpec.id == AppPages.akn06.id) {
      return const Akn05Akn06FollowsPage(followersMode: false);
    }
    if (pageSpec.id == AppPages.akn07.id) {
      return const Akn07SettingsPage();
    }
    if (pageSpec.id == AppPages.akn08.id) {
      return const Akn08PrivacyPage();
    }
    if (pageSpec.id == AppPages.akn09.id) {
      return const Akn09SecurityPage();
    }
    if (pageSpec.id == AppPages.akn10.id) {
      return const Akn10NotificationPrefsPage();
    }
    if (pageSpec.id == AppPages.akn11.id) {
      return const Akn11BlockedUsersPage();
    }
    if (pageSpec.id == AppPages.akn12.id) {
      return const Akn12ConnectionsPage();
    }
    if (pageSpec.id == AppPages.akn13.id) {
      return const Akn13DataExportPage();
    }
    if (pageSpec.id == AppPages.akn14.id) {
      return const Akn14DeleteAccountPage();
    }
    if (pageSpec.id == AppPages.akn15.id) {
      return const Akn15AboutPage();
    }

    return SegeraPage(pageSpec: pageSpec, tabIndex: tabIndex);
  }
}
