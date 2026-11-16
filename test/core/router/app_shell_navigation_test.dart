import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horas/app.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/app_router.dart';
import 'package:horas/core/router/shell_navigation_controller.dart';
import 'package:horas/features/account/presentation/akn01_my_profile_page.dart';
import 'package:horas/features/account/presentation/akn02_edit_profile_page.dart';
import 'package:horas/features/home/presentation/ber01_feed_page.dart';
import 'package:horas/features/messages/presentation/psn01_conversations_page.dart';
import 'package:horas/features/nearby/presentation/sek01_nearby_page.dart';
import 'package:horas/features/play/presentation/man01_play_page.dart';

void main() {
  testWidgets(
    'Membuka aplikasi HORAS dan berpindah antar 5 tab serta ketuk ulang tab',
    (tester) async {
      final container = ProviderContainer(
        overrides: [enableMockNetworkLatencyProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HorasApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Tab 0 (bawaan): Beranda (BER-01 Feed)
      expect(find.byType(Ber01FeedPage), findsOneWidget);
      expect(container.read(shellNavigationProvider).lastTabIndex, 0);

      // Pindah ke Tab 1: Sekitar (SEK-01)
      await tester.tap(find.text(AppStrings.tabSekitar));
      await tester.pumpAndSettle();
      expect(find.byType(Sek01NearbyPage), findsOneWidget);
      expect(container.read(shellNavigationProvider).lastTabIndex, 1);

      // Pindah ke Tab 2: Pesan (PSN-01) di tengah bilah bawah
      await tester.tap(find.text(AppStrings.tabPesan));
      await tester.pumpAndSettle();
      expect(find.byType(Psn01ConversationsPage), findsOneWidget);
      expect(container.read(shellNavigationProvider).lastTabIndex, 2);

      // Pindah ke Tab 3: Main (MAN-01)
      await tester.tap(find.text(AppStrings.tabMain));
      await tester.pumpAndSettle();
      expect(find.byType(Man01PlayPage), findsOneWidget);
      expect(container.read(shellNavigationProvider).lastTabIndex, 3);

      // Pindah ke Tab 4: Akun (AKN-01)
      await tester.tap(find.text(AppStrings.tabAkun));
      await tester.pumpAndSettle();
      expect(find.byType(Akn01MyProfilePage), findsOneWidget);
      expect(container.read(shellNavigationProvider).lastTabIndex, 4);

      // Buka subhalaman AKN-02 Edit Profil di dalam tab Akun,
      // kemudian ketuk ulang tab Akun untuk memastikan kembali ke halaman awal tab (AKN-01).
      await tester.ensureVisible(find.text(AppStrings.akn02Title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.akn02Title));
      await tester.pumpAndSettle();
      expect(find.byType(Akn02EditProfilePage), findsOneWidget);

      await tester.tap(find.text(AppStrings.tabAkun));
      await tester.pumpAndSettle();
      expect(find.byType(Akn01MyProfilePage), findsOneWidget);

      // Kembali ke Tab 0: Beranda (BER-01 Feed)
      await tester.tap(find.text(AppStrings.tabBeranda));
      await tester.pumpAndSettle();
      expect(find.byType(Ber01FeedPage), findsOneWidget);
      expect(container.read(shellNavigationProvider).lastTabIndex, 0);
    },
  );

  test('Skema deep link horas:// dinormalkan ke rute internal', () {
    expect(
      normalizeHorasDeepLink(Uri.parse('horas://app/sekitar')),
      AppPages.sekitarPath,
    );
    expect(
      normalizeHorasDeepLink(Uri.parse('horas://tarombo/pohon')),
      AppPages.tar02.routePath,
    );
    expect(
      normalizeHorasDeepLink(Uri.parse('horas://app')),
      AppPages.berandaPath,
    );
  });
}
