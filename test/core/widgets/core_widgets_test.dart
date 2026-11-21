import 'package:flutter_test/flutter_test.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('Tahap 5 - Komponen Dasar (core/widgets)', () {
    testWidgets('AppButton menangani status normal, loading, dan disabled', (
      tester,
    ) async {
      var tapped = 0;

      await pumpHorasWidget(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppButton(label: AppStrings.termKenalan, onPressed: () => tapped++),
            AppButton(
              label: AppStrings.termIkuti,
              variant: AppButtonVariant.secondary,
              isLoading: true,
              onPressed: () => tapped++,
            ),
            AppButton(
              label: AppStrings.termPesan,
              variant: AppButtonVariant.text,
              isDisabled: true,
              onPressed: () => tapped++,
            ),
          ],
        ),
      );

      await tester.tap(find.text(AppStrings.termKenalan));
      await tester.pump();
      expect(tapped, 1);

      // Tombol loading dan disabled tidak memicu onPressed
      await tester.tap(find.text(AppStrings.termIkuti));
      await tester.tap(find.text(AppStrings.termPesan));
      await tester.pump();
      expect(tapped, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AppTextField menangani status default, focus, dan error', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpHorasWidget(
        tester,
        AppTextField(
          label: AppStrings.aut03Title,
          hintText: '+62 812 3456 7890',
          errorText: 'Format nomor belum sesuai',
          controller: controller,
          suffixIcon: Icons.clear_rounded,
          onSuffixTap: controller.clear,
        ),
      );

      expect(find.text(AppStrings.aut03Title), findsOneWidget);
      expect(find.text('Format nomor belum sesuai'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '+628123456');
      await tester.pump();
      expect(controller.text, '+628123456');

      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();
      expect(controller.text, isEmpty);
    });

    testWidgets('AppChip menampilkan label pill dan merespons ketukan', (
      tester,
    ) async {
      var selected = false;
      await pumpHorasWidget(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return AppChip(
              label: AppStrings.termSemarga,
              isSelected: selected,
              onTap: () => setState(() => selected = !selected),
            );
          },
        ),
      );

      expect(find.text(AppStrings.termSemarga), findsOneWidget);
      await tester.tap(find.text(AppStrings.termSemarga));
      await tester.pump();
      expect(selected, isTrue);
    });

    testWidgets('AppAvatar dan AvatarStack menampilkan inisial serta +N', (
      tester,
    ) async {
      await pumpHorasWidget(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppAvatar(name: 'Rudi Simanjuntak'),
            AvatarStack(
              names: <String>[
                'Rudi Simanjuntak',
                'Dewi Sitorus',
                'Bona Nainggolan',
              ],
              maxVisible: 2,
              totalCount: 6,
            ),
          ],
        ),
      );

      expect(find.text('RS'), findsWidgets);
      expect(find.text('DS'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
    });

    testWidgets('SkeletonBox merender kerangka animasi tanpa error', (
      tester,
    ) async {
      await pumpHorasWidget(tester, const SkeletonBox(width: 120, height: 20));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SkeletonBox), findsOneWidget);
    });

    testWidgets('PlaceholderImage merender gradien berbasis seed tanpa aset', (
      tester,
    ) async {
      await pumpHorasWidget(
        tester,
        const PlaceholderImage(
          seed: 'danau-toba-1',
          width: 200,
          height: 100,
          caption: 'Danau Toba',
        ),
      );
      expect(find.text('Danau Toba'), findsOneWidget);
      expect(find.byType(PlaceholderImage), findsOneWidget);
    });

    testWidgets('HorasLogo dan GorgaOrnament tampil dengan benar', (
      tester,
    ) async {
      await pumpHorasWidget(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            HorasLogo(showRoof: true, showTagline: true),
            GorgaOrnament(placement: GorgaPlacement.headerBand),
            GorgaOrnament(placement: GorgaPlacement.cornerTopRight),
          ],
        ),
      );

      expect(find.text(AppStrings.appWordmark), findsOneWidget);
      expect(find.text(AppStrings.appTagline), findsOneWidget);
      expect(find.byType(GorgaOrnament), findsNWidgets(2));
    });

    testWidgets(
      'VerifiedBadge menampilkan Terverifikasi & Belum diverifikasi',
      (tester) async {
        await pumpHorasWidget(
          tester,
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              VerifiedBadge(isVerified: true, showLabel: true),
              VerifiedBadge(isVerified: false),
            ],
          ),
        );

        expect(find.text(AppStrings.termTerverifikasi), findsOneWidget);
        expect(find.text(AppStrings.termBelumDiverifikasi), findsOneWidget);
      },
    );

    testWidgets('SectionHeader merender judul dan tombol aksi', (tester) async {
      var tapped = false;
      await pumpHorasWidget(
        tester,
        SectionHeader(
          title: 'Orang Batak di Sekitarmu',
          onActionTap: () => tapped = true,
        ),
      );

      expect(find.text('Orang Batak di Sekitarmu'), findsOneWidget);
      await tester.tap(find.text(AppStrings.actionSeeAll));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('ConfirmDialog, AppToast, dan AppBottomSheet berfungsi', (
      tester,
    ) async {
      bool? confirmed;

      await pumpHorasWidget(
        tester,
        Builder(
          builder: (context) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppButton(
                  label: 'Buka Dialog',
                  onPressed: () async {
                    confirmed = await ConfirmDialog.show(
                      context,
                      title: 'Keluar Komunitas?',
                      message: 'Kamu dapat bergabung kembali kapan saja.',
                      confirmLabel: 'Ya, Keluar',
                      isDestructive: true,
                    );
                  },
                ),
                AppButton(
                  label: 'Tampilkan Toast',
                  onPressed: () {
                    AppToast.show(
                      context,
                      message: 'Tersimpan',
                      variant: AppToastVariant.success,
                    );
                  },
                ),
                AppButton(
                  label: 'Buka Sheet',
                  onPressed: () {
                    AppBottomSheet.show<void>(
                      context,
                      title: 'Filter Marga',
                      child: const Text('Isi Filter'),
                    );
                  },
                ),
              ],
            );
          },
        ),
      );

      // Uji ConfirmDialog
      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar Komunitas?'), findsOneWidget);
      await tester.tap(find.text('Ya, Keluar'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);

      // Uji AppToast
      await tester.tap(find.text('Tampilkan Toast'));
      await tester.pump();
      expect(find.text('Tersimpan'), findsOneWidget);

      // Uji AppBottomSheet
      await tester.tap(find.text('Buka Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Filter Marga'), findsOneWidget);
      expect(find.text('Isi Filter'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets('StateView mencakup seluruh 7 varian standar PRD 5.2', (
      tester,
    ) async {
      var actionCount = 0;

      // 1. Loading (skeleton)
      await pumpHorasWidget(tester, const StateView.loading(itemCount: 2));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(SkeletonBox), findsWidgets);

      // 2. Empty (satu kalimat + satu tombol aksi)
      await pumpHorasWidget(
        tester,
        StateView.empty(
          message: 'Belum ada sesi, buat yang pertama.',
          actionLabel: AppStrings.man03Title,
          onAction: () => actionCount++,
        ),
      );
      expect(find.text('Belum ada sesi, buat yang pertama.'), findsOneWidget);
      await tester.tap(find.text(AppStrings.man03Title));
      await tester.pump();
      expect(actionCount, 1);

      // 3. Offline (Coba lagi)
      await pumpHorasWidget(
        tester,
        StateView.offline(onRetry: () => actionCount++),
      );
      expect(find.text(AppStrings.stateOfflineTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.actionRetry));
      await tester.pump();
      expect(actionCount, 2);

      // 4. Server Error (kode referensi)
      await pumpHorasWidget(
        tester,
        StateView.serverError(
          referenceCode: 'HRS-12AB34',
          onRetry: () => actionCount++,
        ),
      );
      expect(
        find.text(AppStrings.stateServerErrorReference('HRS-12AB34')),
        findsOneWidget,
      );

      // 5. Permission Denied (manfaat + buka pengaturan)
      await pumpHorasWidget(
        tester,
        StateView.permissionDenied(
          benefitMessage: AppStrings.statePermissionDeniedDefaultBenefit,
          onOpenSettings: () => actionCount++,
          onContinueWithoutPermission: () => actionCount++,
        ),
      );
      expect(find.text(AppStrings.actionOpenSettings), findsOneWidget);
      await tester.tap(find.text(AppStrings.actionOpenSettings));
      await tester.pump();
      expect(actionCount, 3);

      // 6. Content Unavailable (netral tanpa membocorkan alasan)
      await pumpHorasWidget(
        tester,
        StateView.contentUnavailable(onBack: () => actionCount++),
      );
      expect(
        find.text(AppStrings.stateContentUnavailableMessage),
        findsOneWidget,
      );

      // 7. Account Restricted (alasan umum + jalur banding)
      await pumpHorasWidget(
        tester,
        StateView.accountRestricted(
          generalReason: AppStrings.stateAccountRestrictedDefaultReason,
          onAppeal: () => actionCount++,
        ),
      );
      expect(find.text(AppStrings.actionSubmitAppeal), findsOneWidget);
      await tester.tap(find.text(AppStrings.actionSubmitAppeal));
      await tester.pump();
      expect(actionCount, 4);
    });

    testWidgets(
      'AppButton tonal/compact & PhotoLightboxPage merender dan menutup dengan benar',
      (tester) async {
        var tonalTapped = 0;

        await pumpHorasWidget(
          tester,
          Builder(
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppButton(
                  label: AppStrings.akn02Title,
                  variant: AppButtonVariant.tonal,
                  compact: true,
                  onPressed: () => tonalTapped++,
                ),
                AppButton(
                  label: 'Buka Lightbox',
                  onPressed: () {
                    PhotoLightboxPage.show(
                      context,
                      seeds: const <String>['toba-1', 'toba-2'],
                      title: 'Danau Toba',
                    );
                  },
                ),
              ],
            ),
          ),
        );

        await tester.tap(find.text(AppStrings.akn02Title));
        await tester.pump();
        expect(tonalTapped, 1);

        await tester.tap(find.text('Buka Lightbox'));
        await tester.pumpAndSettle();
        expect(find.byType(PhotoLightboxPage), findsOneWidget);
        expect(find.text('Danau Toba'), findsOneWidget);

        await tester.tap(find.byTooltip(AppStrings.ber01PhotoViewerClose));
        await tester.pumpAndSettle();
        expect(find.byType(PhotoLightboxPage), findsNothing);
      },
    );
  });
}
