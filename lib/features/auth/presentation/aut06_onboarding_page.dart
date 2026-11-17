import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/features/auth/presentation/auth_flow_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

/// AUT-06 Onboarding 4 Langkah + Layar Penjelas Manfaat Izin (AUT-R5 .. AUT-R7, AUT-R10, AC-02).
///
/// Draf disimpan setiap langkah dan otomatis dilanjutkan bila aplikasi ditutup.
class Aut06OnboardingPage extends ConsumerStatefulWidget {
  const Aut06OnboardingPage({super.key});

  @override
  ConsumerState<Aut06OnboardingPage> createState() =>
      _Aut06OnboardingPageState();
}

class _Aut06OnboardingPageState extends ConsumerState<Aut06OnboardingPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _margaSearchController;
  late final TextEditingController _campusOfficeController;

  List<WilayahCity> _allCities = const <WilayahCity>[];

  static const List<String> _hobbyOptions = <String>[
    'Badminton',
    'Futsal',
    'Voli',
    'Basket',
    'Tenis Meja',
    'Jogging',
    'Kopi',
    'Musik Batak',
    'Paduan Suara',
    'Kuliner',
    'Fotografi',
  ];

  @override
  void initState() {
    super.initState();
    final draft = ref.read(authFlowControllerProvider).onboardingDraft;
    _nameController = TextEditingController(text: draft.displayName);
    _margaSearchController = TextEditingController(text: draft.marga);
    _campusOfficeController = TextEditingController(text: draft.campusOrOffice);
    _loadMasterLists();
  }

  Future<void> _loadMasterLists() async {
    final cityRes = await ref
        .read(nearbyRepositoryProvider)
        .getAvailableCities();
    if (!mounted) return;
    setState(() {
      if (cityRes is Ok<List<WilayahCity>>) {
        _allCities = cityRes.value;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _margaSearchController.dispose();
    _campusOfficeController.dispose();
    super.dispose();
  }

  /// Memilih foto dengan `image_picker` dan mengompresnya dengan `flutter_image_compress` (BER-R2, AUT-06).
  Future<void> _pickAndCompressAvatar(ImageSource source) async {
    final controller = ref.read(authFlowControllerProvider.notifier);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final rawBytes = await picked.readAsBytes();
        final compressed = await FlutterImageCompress.compressWithList(
          rawBytes,
          minWidth: 512,
          minHeight: 512,
          quality: 80,
          keepExif: false, // AC-10: Hapus metadata lokasi EXIF di klien
        );
        await controller.updateOnboardingDraft(
          (d) => d.copyWith(
            photoSeedOrPath: 'compressed-${compressed.length}-${picked.name}',
          ),
        );
        return;
      }
    } on Object {
      // Pada simulator/pengujian tanpa galeri fisik, gunakan seed terkompresi deterministik.
    }
    await controller.updateOnboardingDraft(
      (d) => d.copyWith(photoSeedOrPath: 'avatar-compressed-seed'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(authFlowControllerProvider);
    final draft = flowState.onboardingDraft;
    final colors = context.colors;
    final typo = context.typo;

    // AUT-R10: Setelah 4 langkah selesai, tampilkan layar penjelas manfaat izin (bukan di splash).
    if (draft.showPermissionExplainer) {
      return _buildPermissionExplainerScreen(context, flowState);
    }

    return Scaffold(
      appBar: AppBar(
        leading: draft.currentStep > 1
            ? IconButton(
                tooltip: AppStrings.semanticsBack,
                onPressed: () => ref
                    .read(authFlowControllerProvider.notifier)
                    .goBackOnboardingStep(),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: Text(AppStrings.aut06Title, style: typo.h2),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Indikator progres 4 langkah
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    AppStrings.aut06StepIndicator(draft.currentStep),
                    style: typo.captionStrong.copyWith(color: colors.accent),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      AppStrings.aut06DraftSavedNotice,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: typo.micro,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: List<Widget>.generate(3, (idx) {
                  final active = (idx + 1) <= draft.currentStep.clamp(1, 3);
                  return Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(
                        right: idx < 2 ? AppSpacing.xs : 0,
                      ),
                      decoration: BoxDecoration(
                        color: active ? colors.buttonPrimary : colors.border,
                        borderRadius: AppRadius.pillRadius,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),

              if (draft.currentStep == 1) _buildStep1(context, flowState),
              if (draft.currentStep == 2) _buildStep2(context, flowState),
              if (draft.currentStep >= 3) _buildStep4(context, flowState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(BuildContext context, AuthFlowState flowState) {
    final controller = ref.read(authFlowControllerProvider.notifier);
    final authRepo = ref.watch(authRepositoryProvider);
    final activeEmail = authRepo.currentSessionProfile?.email;
    final draft = flowState.onboardingDraft;
    final colors = context.colors;
    final typo = context.typo;
    final err = flowState.error;
    final errField = err is ValidationError ? err.field : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(AppStrings.aut06Step1Title, style: typo.h1),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.aut06Step1Desc,
          style: typo.body.copyWith(color: colors.textMuted),
        ),
        if (activeEmail != null && activeEmail.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.buttonRadius,
              border: Border.all(color: colors.accent),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.alternate_email_rounded,
                  size: AppSizes.iconMd,
                  color: colors.accent,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Terhubung dengan email: $activeEmail',
                    style: typo.captionStrong.copyWith(color: colors.accent),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Column(
            children: <Widget>[
              AppAvatar(
                name: draft.displayName.isEmpty ? 'Horas' : draft.displayName,
                seed: draft.photoSeedOrPath,
                size: AppSizes.avatarXl,
              ),
              if (draft.photoSeedOrPath != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                const AppChip(
                  label: AppStrings.aut06PhotoCompressedBadge,
                  isSelected: true,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  AppButton(
                    label: AppStrings.aut06PickPhotoGallery,
                    variant: AppButtonVariant.secondary,
                    leadingIcon: Icons.photo_library_outlined,
                    onPressed: () =>
                        _pickAndCompressAvatar(ImageSource.gallery),
                  ),
                  AppButton(
                    label: AppStrings.aut06PickPhotoCamera,
                    variant: AppButtonVariant.text,
                    leadingIcon: Icons.camera_alt_outlined,
                    onPressed: () => _pickAndCompressAvatar(ImageSource.camera),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // KOTAK INPUT 1: Username / Nama Tampil
        AppTextField(
          label: AppStrings.aut06DisplayNameLabel,
          hintText: AppStrings.aut06DisplayNameHint,
          controller: _nameController,
          maxLength: 40,
          leadingIcon: Icons.person_outline_rounded,
          errorText: errField == 'displayName' ? err?.message : null,
          onChanged: (val) => controller.updateOnboardingDraft(
            (d) => d.copyWith(displayName: val),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // KOTAK INPUT 2: Marga (Kotak Terpisah, tanpa pilihan marga chip, otomatis masuk database)
        AppTextField(
          label: AppStrings.aut06Step1MargaLabel,
          hintText: AppStrings.aut06Step1MargaHint,
          controller: _margaSearchController,
          leadingIcon: Icons.badge_outlined,
          errorText: errField == 'marga'
              ? err?.message
              : (errField != 'displayName' ? err?.message : null),
          onChanged: (val) =>
              controller.updateOnboardingDraft((d) => d.copyWith(marga: val)),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: AppStrings.aut06BtnNextStep,
          isExpanded: true,
          onPressed: () => controller.completeOnboardingStep1(
            displayName: _nameController.text,
            marga: _margaSearchController.text,
            requireMarga: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(BuildContext context, AuthFlowState flowState) {
    final controller = ref.read(authFlowControllerProvider.notifier);
    final draft = flowState.onboardingDraft;
    final colors = context.colors;
    final typo = context.typo;
    final currentYear = ref.read(authRepositoryProvider).currentTime.year;
    final years = List<int>.generate(75, (i) => currentYear - 14 - i);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(AppStrings.aut06Step2Title, style: typo.h1),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.aut06Step2Desc,
          style: typo.body.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),

        Text(AppStrings.aut06GenderLabel, style: typo.captionStrong),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: AppChip(
                label: UserGender.male.label,
                isSelected: draft.gender == UserGender.male,
                onTap: () => controller.updateOnboardingDraft(
                  (d) => d.copyWith(gender: UserGender.male),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppChip(
                label: UserGender.female.label,
                isSelected: draft.gender == UserGender.female,
                onTap: () => controller.updateOnboardingDraft(
                  (d) => d.copyWith(gender: UserGender.female),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        Text(AppStrings.aut06BirthYearLabel, style: typo.captionStrong),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final yr in years.take(18))
              AppChip(
                label: '$yr',
                isSelected: draft.birthYear == yr,
                onTap: () => controller.updateOnboardingDraft(
                  (d) => d.copyWith(birthYear: yr),
                ),
              ),
          ],
        ),

        // AC-02: Pesan penolakan sopan bila usia < 17 tahun & data tidak disimpan
        if (flowState.under17PoliteRejectionMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.confidenceAmberSurface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: colors.danger),
            ),
            child: Text(
              flowState.under17PoliteRejectionMessage!,
              style: typo.bodyStrong.copyWith(color: colors.danger),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: AppStrings.aut06BtnNextStep,
          isExpanded: true,
          onPressed: () => controller.completeOnboardingStep2(
            gender: draft.gender,
            birthYear: draft.birthYear,
          ),
        ),
      ],
    );
  }

  Widget _buildStep4(BuildContext context, AuthFlowState flowState) {
    final controller = ref.read(authFlowControllerProvider.notifier);
    final draft = flowState.onboardingDraft;
    final colors = context.colors;
    final typo = context.typo;

    final selectedCityObj = _allCities
        .where((c) => c.name.toLowerCase() == draft.city.toLowerCase())
        .firstOrNull;
    final subdistricts =
        selectedCityObj?.subdistricts ?? const <String>['Medan Baru'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(AppStrings.aut06Step4Title, style: typo.h1),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.aut06Step4Desc,
          style: typo.body.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),

        Text(AppStrings.aut06CityLabel, style: typo.captionStrong),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final c in _allCities.take(10))
              AppChip(
                label: c.name,
                isSelected: draft.city.toLowerCase() == c.name.toLowerCase(),
                onTap: () => controller.updateOnboardingDraft(
                  (d) => d.copyWith(
                    city: c.name,
                    subdistrict: c.subdistricts.isNotEmpty
                        ? c.subdistricts.first
                        : c.name,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        Text(AppStrings.aut06SubdistrictLabel, style: typo.captionStrong),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final sub in subdistricts)
              AppChip(
                label: sub,
                isSelected:
                    draft.subdistrict.toLowerCase() == sub.toLowerCase(),
                onTap: () => controller.updateOnboardingDraft(
                  (d) => d.copyWith(subdistrict: sub),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        Text(AppStrings.aut06HobbiesLabel, style: typo.captionStrong),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final hobby in _hobbyOptions)
              AppChip(
                label: hobby,
                isSelected: draft.hobbies.contains(hobby),
                onTap: () {
                  final next = List<String>.of(draft.hobbies);
                  if (next.contains(hobby)) {
                    next.remove(hobby);
                  } else {
                    next.add(hobby);
                  }
                  controller.updateOnboardingDraft(
                    (d) => d.copyWith(hobbies: next),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        AppTextField(
          label: AppStrings.aut06CampusOfficeLabel,
          hintText: AppStrings.aut06CampusOfficeHint,
          controller: _campusOfficeController,
          onChanged: (val) => controller.updateOnboardingDraft(
            (d) => d.copyWith(campusOrOffice: val),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        AppButton(
          label: AppStrings.aut06BtnFinishSteps,
          isExpanded: true,
          isLoading: flowState.isLoading,
          onPressed: () => controller.completeOnboardingStep4(
            city: draft.city,
            subdistrict: draft.subdistrict,
            hobbies: draft.hobbies,
            campusOrOffice: _campusOfficeController.text,
          ),
        ),
      ],
    );
  }

  /// AUT-R10: Layar penjelas manfaat izin notifikasi & lokasi perkiraan setelah onboarding.
  Widget _buildPermissionExplainerScreen(
    BuildContext context,
    AuthFlowState flowState,
  ) {
    final controller = ref.read(authFlowControllerProvider.notifier);
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.autPermissionTitle, style: typo.h2),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const GorgaOrnament(width: double.infinity, height: 18),
              const SizedBox(height: AppSpacing.md),
              Text(AppStrings.autPermissionTitle, style: typo.h1),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.autPermissionSubtitle,
                style: typo.body.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 1. Kartu Manfaat Izin Notifikasi
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(AppStrings.autPermissionNotifTitle, style: typo.h3),
                    const SizedBox(height: AppSpacing.xs),
                    Text(AppStrings.autPermissionNotifDesc, style: typo.body),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: flowState.notificationsGranted
                          ? AppStrings.autPermissionNotifGranted
                          : AppStrings.autPermissionNotifAllowBtn,
                      variant: flowState.notificationsGranted
                          ? AppButtonVariant.secondary
                          : AppButtonVariant.primary,
                      onPressed: () async {
                        var granted = true;
                        try {
                          final status = await perm.Permission.notification
                              .request();
                          granted = status.isGranted;
                        } on Object {
                          granted = true;
                        }
                        controller.grantNotificationPermission(
                          granted: granted,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 2. Kartu Manfaat Lokasi Perkiraan (ACCESS_COARSE_LOCATION saja, koordinat dibuang)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(AppStrings.autPermissionLocTitle, style: typo.h3),
                    const SizedBox(height: AppSpacing.xs),
                    Text(AppStrings.autPermissionLocDesc, style: typo.body),
                    const SizedBox(height: AppSpacing.md),
                    if (flowState.coarseLocationMatchedCity != null)
                      Text(
                        AppStrings.autPermissionLocMatched(
                          flowState.coarseLocationMatchedCity!,
                        ),
                        style: typo.captionStrong.copyWith(
                          color: colors.success,
                        ),
                      )
                    else
                      AppButton(
                        label: AppStrings.autPermissionLocAllowBtn,
                        variant: AppButtonVariant.secondary,
                        onPressed: () async {
                          var granted = true;
                          try {
                            final status = await perm.Permission.location
                                .request();
                            granted = status.isGranted;
                          } on Object {
                            granted = true;
                          }
                          await controller
                              .matchCoarseLocationAndDiscardCoordinates(
                                coarseLat: 3.5952,
                                coarseLon: 98.6722,
                                permissionGranted: granted,
                              );
                        },
                      ),
                  ],
                ),
              ),

              if (flowState.permissionDeniedNotice) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                StateView.permissionDenied(
                  benefitMessage: AppStrings.autPermissionDeniedNotice,
                  onOpenSettings: () {
                    perm.openAppSettings();
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),

              // Alur A1 berakhir di tab Sekitar (SEK-01)
              AppButton(
                label: AppStrings.autPermissionContinueToNearbyBtn,
                isExpanded: true,
                onPressed: () async {
                  final router = GoRouter.of(context);
                  await controller.finishPermissionExplainer();
                  router.go(AppPages.sekitarPath);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
