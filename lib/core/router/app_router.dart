import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/main_shell_scaffold.dart';
import 'package:horas/core/widgets/state_view.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/repositories/repositories.dart';
import 'package:horas/features/account/presentation/account_placeholder_page.dart';
import 'package:horas/features/auth/presentation/auth_placeholder_page.dart';
import 'package:horas/features/home/presentation/home_placeholder_page.dart';
import 'package:horas/features/messages/presentation/messages_placeholder_page.dart';
import 'package:horas/features/nearby/presentation/nearby_placeholder_page.dart';
import 'package:horas/features/play/presentation/play_placeholder_page.dart';
import 'package:horas/features/system/presentation/system_placeholder_page.dart';
import 'package:horas/features/tarombo/presentation/tarombo_placeholder_page.dart';
import 'package:material_ui/material_ui.dart';

/// Skema deep link resmi HORAS (PRD 4.6, Tahap 6).
const String kHorasDeepLinkScheme = 'horas';

/// Menormalkan URI deep link `horas://...` menjadi path internal `go_router`.
String normalizeHorasDeepLink(Uri uri) {
  if (uri.scheme.toLowerCase() != kHorasDeepLinkScheme) {
    return uri.path.isEmpty ? AppPages.berandaPath : uri.path;
  }
  final host = uri.host.trim();
  final rawPath = uri.path.trim();
  if (host.isEmpty || host == 'app') {
    if (rawPath.isEmpty || rawPath == '/') {
      return AppPages.berandaPath;
    }
    return rawPath.startsWith('/') ? rawPath : '/$rawPath';
  }
  final combined = '/$host${rawPath.startsWith('/') ? rawPath : '/$rawPath'}';
  return combined.endsWith('/') && combined.length > 1
      ? combined.substring(0, combined.length - 1)
      : combined;
}

/// Pembuat [GoRouter] aplikasi HORAS dengan `StatefulShellRoute` 5 tab & Guard Autentikasi.
GoRouter createAppRouter({
  String initialLocation = AppPages.berandaPath,
  AuthRepository? authRepository,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      final uri = state.uri;
      if (uri.scheme.toLowerCase() == kHorasDeepLinkScheme) {
        return normalizeHorasDeepLink(uri);
      }
      if (uri.path == '/') {
        return AppPages.berandaPath;
      }

      // Guard Router Autentikasi & Onboarding (Prompt 3)
      if (authRepository != null) {
        final isAuthRoute = uri.path.startsWith('/auth/');
        final isPublicGuideline = uri.path == AppPages.sis08.routePath;
        final profile = authRepository.currentSessionProfile;

        if (profile == null) {
          if (!isAuthRoute && !isPublicGuideline) {
            return AppPages.aut02.routePath;
          }
          return null;
        }

        if (profile.accountStatus == AccountStatus.suspended ||
            profile.accountStatus == AccountStatus.restricted ||
            profile.accountStatus == AccountStatus.permanentlyBanned) {
          if (uri.path != AppPages.aut01.routePath &&
              uri.path != AppPages.sis05.routePath) {
            return AppPages.aut01.routePath;
          }
          return null;
        }

        if (!profile.onboardingCompleted) {
          if (uri.path != AppPages.aut06.routePath) {
            return AppPages.aut06.routePath;
          }
          return null;
        }
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: StateView.contentUnavailable(
        onBack: () => context.go(AppPages.berandaPath),
      ),
    ),
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScaffold(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          // Tab 0: Beranda (BER-01, BER-04 .. BER-10 — Selesai di Prompt 4)
          StatefulShellBranch(
            routes: <RouteBase>[
              _buildTabBranchRouteWithState(
                rootSpec: AppPages.ber01,
                childSpecs: AppPages.homePages.skip(1).toList(),
                rootBuilder: (spec, state) => HomeModulePageRouter(
                  pageSpec: spec,
                  routerState: state,
                  tabIndex: 0,
                ),
                childBuilder: (spec, state) =>
                    HomeModulePageRouter(pageSpec: spec, routerState: state),
              ),
            ],
          ),
          // Tab 1: Sekitar (SEK-01 .. SEK-08, SEK-12 — Selesai di Prompt 5)
          StatefulShellBranch(
            routes: <RouteBase>[
              _buildTabBranchRouteWithState(
                rootSpec: AppPages.sek01,
                childSpecs: AppPages.nearbyPages.skip(1).toList(),
                rootBuilder: (spec, state) => NearbyModulePageRouter(
                  pageSpec: spec,
                  routerState: state,
                  tabIndex: 1,
                ),
                childBuilder: (spec, state) =>
                    NearbyModulePageRouter(pageSpec: spec, routerState: state),
              ),
            ],
          ),
          // Tab 2: Pesan (PSN-01 .. PSN-06 — di tengah bilah navigasi bawah)
          StatefulShellBranch(
            routes: <RouteBase>[
              _buildTabBranchRouteWithState(
                rootSpec: AppPages.psn01,
                childSpecs: AppPages.messagePages.skip(1).toList(),
                rootBuilder: (spec, state) => MessagesModulePageRouter(
                  pageSpec: spec,
                  routerState: state,
                  tabIndex: 2,
                ),
                childBuilder: (spec, state) => MessagesModulePageRouter(
                  pageSpec: spec,
                  routerState: state,
                ),
              ),
            ],
          ),
          // Tab 3: Main (MAN-01 .. MAN-09 — Selesai di Prompt 7)
          StatefulShellBranch(
            routes: <RouteBase>[
              _buildTabBranchRouteWithState(
                rootSpec: AppPages.man01,
                childSpecs: AppPages.playPages.skip(1).toList(),
                rootBuilder: (spec, state) => PlayModulePageRouter(
                  pageSpec: spec,
                  routerState: state,
                  tabIndex: 3,
                ),
                childBuilder: (spec, state) =>
                    PlayModulePageRouter(pageSpec: spec, routerState: state),
              ),
            ],
          ),
          // Tab 4: Akun (AKN-01 .. AKN-15 — Selesai di Prompt 9)
          StatefulShellBranch(
            routes: <RouteBase>[
              _buildTabBranchRouteWithState(
                rootSpec: AppPages.akn01,
                childSpecs: AppPages.accountPages.skip(1).toList(),
                rootBuilder: (spec, state) => AccountModulePageRouter(
                  pageSpec: spec,
                  routerState: state,
                  tabIndex: 4,
                ),
                childBuilder: (spec, state) =>
                    AccountModulePageRouter(pageSpec: spec, routerState: state),
              ),
            ],
          ),
        ],
      ),
      // Rute modul Autentikasi (AUT-01 .. AUT-07 — Selesai di Prompt 3)
      for (final spec in AppPages.authPages)
        GoRoute(
          path: spec.routePath,
          name: spec.id,
          builder: (context, state) => AuthModulePageRouter(pageSpec: spec),
        ),
      // Rute modul Tarombo (TAR-01 .. TAR-08 — diakses lewat Akun > Pengaturan)
      for (final spec in AppPages.taromboPages)
        GoRoute(
          path: spec.routePath,
          name: spec.id,
          builder: (context, state) =>
              TaromboModulePageRouter(pageSpec: spec, routerState: state),
        ),
      // Rute modul Sistem (SIS-01 .. SIS-08 — Selesai di Prompt 9)
      for (final spec in AppPages.systemPages)
        GoRoute(
          path: spec.routePath,
          name: spec.id,
          builder: (context, state) =>
              SystemModulePageRouter(pageSpec: spec, routerState: state),
        ),
      // Alias /report menuju SIS-02 Laporkan
      GoRoute(
        path: '/report',
        builder: (context, state) => SystemModulePageRouter(
          pageSpec: AppPages.sis02,
          routerState: state,
        ),
      ),
      // Alias /verification menuju SIS-06 Ajukan Verifikasi
      GoRoute(
        path: '/verification',
        builder: (context, state) => SystemModulePageRouter(
          pageSpec: AppPages.sis06,
          routerState: state,
        ),
      ),
    ],
  );
}

GoRoute _buildTabBranchRouteWithState({
  required PageSpec rootSpec,
  required List<PageSpec> childSpecs,
  required Widget Function(PageSpec spec, GoRouterState state) rootBuilder,
  required Widget Function(PageSpec spec, GoRouterState state) childBuilder,
}) {
  final prefix = '${rootSpec.routePath}/';
  return GoRoute(
    path: rootSpec.routePath,
    name: rootSpec.id,
    builder: (context, state) => rootBuilder(rootSpec, state),
    routes: <RouteBase>[
      for (final child in childSpecs)
        GoRoute(
          path: child.routePath.startsWith(prefix)
              ? child.routePath.substring(prefix.length)
              : child.routePath,
          name: child.id,
          builder: (context, state) => childBuilder(child, state),
        ),
    ],
  );
}

/// Provider global untuk instance [GoRouter].
final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final router = createAppRouter(authRepository: authRepo);
  ref.onDispose(router.dispose);
  return router;
});
