import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/app_limits.dart';
import 'package:horas/features/messages/presentation/chat_thread_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// AKN-02 Edit Profil (`AKN-R2`).
class Akn02EditProfilePage extends ConsumerStatefulWidget {
  const Akn02EditProfilePage({super.key});

  @override
  ConsumerState<Akn02EditProfilePage> createState() =>
      _Akn02EditProfilePageState();
}

class _Akn02EditProfilePageState extends ConsumerState<Akn02EditProfilePage> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _subdistrictController = TextEditingController();
  final _hobbiesController = TextEditingController();
  final _campusController = TextEditingController();
  final _websiteController = TextEditingController();

  Profil? _profile;
  List<WilayahCity> _cities = const <WilayahCity>[];
  List<FamilyMember> _taromboMembers = const <FamilyMember>[];
  List<PartuturanClaim> _incomingClaims = const <PartuturanClaim>[];
  int _taromboCompleteness = 0;
  String _selectedCity = 'Medan';
  String _avatarSeed = 'avatar-u-01';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _subdistrictController.dispose();
    _hobbiesController.dispose();
    _campusController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profileRepo = ref.read(profileRepositoryProvider);
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    final taromboRepo = ref.read(taromboRepositoryProvider);

    final profFuture = profileRepo.getMyProfile();
    final citiesFuture = nearbyRepo.getAvailableCities();
    final membersFuture = taromboRepo.getMyFamilyMembers();
    final percentFuture = taromboRepo.getCompletenessPercent();
    final claimsFuture = taromboRepo.getIncomingClaims();

    final profRes = await profFuture;
    final citiesRes = await citiesFuture;
    final membersRes = await membersFuture;
    final percentRes = await percentFuture;
    final claimsRes = await claimsFuture;
    if (!mounted) return;
    if (profRes is Ok<Profil>) {
      final me = profRes.value;
      _profile = me;
      _nameController.text = me.displayName;
      _bioController.text = me.bio;
      _selectedCity = me.city;
      _subdistrictController.text = me.subdistrict;
      _hobbiesController.text = me.hobbies.join(', ');
      _campusController.text = me.campusOrOffice ?? '';
      _websiteController.text = me.websiteUrl ?? '';
      _avatarSeed = me.avatarSeed;
    }
    setState(() {
      _cities = citiesRes is Ok<List<WilayahCity>>
          ? citiesRes.value
          : const <WilayahCity>[];
      _taromboMembers = membersRes is Ok<List<FamilyMember>>
          ? membersRes.value
          : const <FamilyMember>[];
      _taromboCompleteness = percentRes is Ok<int> ? percentRes.value : 0;
      _incomingClaims = claimsRes is Ok<List<PartuturanClaim>>
          ? claimsRes.value
          : const <PartuturanClaim>[];
      _isLoading = false;
    });
  }

  Future<void> _openMotherMargaDialog() async {
    final ctrl = TextEditingController(text: _profile?.motherMarga ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.tar01EditMotherMargaBtn),
        content: AppTextField(
          controller: ctrl,
          label: AppStrings.tar01MotherMargaLabel,
          hintText: AppStrings.tar03MargaHint,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text.trim()),
            child: const Text(AppStrings.tar03SaveBtn),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (saved == null || !mounted) return;
    final res = await ref
        .read(profileRepositoryProvider)
        .updateMyProfile(motherMarga: saved);
    if (!mounted) return;
    if (res is Err<Profil>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await _load();
  }

  Future<void> _openAddTaromboMember() async {
    final taromboRepo = ref.read(taromboRepositoryProvider);
    if (!taromboRepo.hasGivenConsent) {
      final accepted = await ConfirmDialog.show(
        context,
        title: AppStrings.tarConsentTitle,
        message: AppStrings.tarConsentBody,
        confirmLabel: AppStrings.tarConsentAcceptBtn,
      );
      if (!accepted || !mounted) return;
      final consentRes = await taromboRepo.giveConsent();
      if (!mounted || consentRes.isErr) return;
    }
    if (!mounted) return;
    await context.push(AppPages.tar03.routePath);
    if (mounted) await _load();
  }

  Future<void> _changePhoto() async {
    final seed = await pickAndCompressChatPhoto(context);
    if (seed != null && mounted) {
      setState(() => _avatarSeed = seed);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    final hobbies = _hobbiesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    final res = await ref
        .read(profileRepositoryProvider)
        .updateMyProfile(
          displayName: _nameController.text.trim(),
          avatarSeed: _avatarSeed,
          bio: _bioController.text.trim(),
          city: _selectedCity,
          subdistrict: _subdistrictController.text.trim(),
          hobbies: hobbies,
          campusOrOffice: _campusController.text.trim().isEmpty
              ? null
              : _campusController.text.trim(),
          websiteUrl: _websiteController.text.trim().isEmpty
              ? null
              : _websiteController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res is Err<Profil>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    AppToast.show(
      context,
      message: AppStrings.akn02SavedToast,
      variant: AppToastVariant.success,
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.akn02Title)),
      body: SafeArea(
        child: _isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  Center(
                    child: Column(
                      children: <Widget>[
                        AppAvatar(
                          name: _profile?.displayName ?? AppStrings.appName,
                          seed: _avatarSeed,
                          size: AppSizes.avatarLg,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: AppStrings.akn02PickPhotoBtn,
                          variant: AppButtonVariant.text,
                          onPressed: _changePhoto,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _nameController,
                    label: AppStrings.akn02NameLabel,
                    helperText: AppStrings.akn02NameCooldownInfo,
                    maxLength: AppLimits.displayNameMaxChars,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _bioController,
                    label: AppStrings.akn02BioLabel,
                    maxLines: 3,
                    maxLength: AppLimits.bioMaxChars,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(AppStrings.akn02CityLabel, style: typo.bodyStrong),
                  const SizedBox(height: AppSpacing.xs),
                  if (_cities.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _cities.any((c) => c.name == _selectedCity)
                          ? _selectedCity
                          : _cities.first.name,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _cities
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c.name,
                              child: Text(c.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCity = v);
                      },
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _subdistrictController,
                    label: AppStrings.akn02SubdistrictLabel,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _hobbiesController,
                    label: AppStrings.akn02HobbiesLabel,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _campusController,
                    label: AppStrings.akn02CampusOfficeLabel,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _websiteController,
                    label: AppStrings.akn02WebsiteLabel,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Data identitas terkunci (AKN-R2)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: colors.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                AppStrings.akn02LockedIdentityTitle,
                                style: typo.bodyStrong,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (_profile != null)
                            Text(
                              '${_profile!.marga} · ${_profile!.subEthnic.displayName} · ${_profile!.gender.label}',
                              style: typo.body,
                            ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            AppStrings.akn02LockedIdentityHint,
                            style: typo.caption.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => context
                                  .push(
                                    '${AppPages.sis05.routePath}?category=${Uri.encodeComponent(AppStrings.sis05CategoryIdentity)}',
                                  )
                                  .ignore(),
                              child: const Text(AppStrings.sis05Title),
                            ),
                          ),
                          Text(
                            AppStrings.akn02PhoneHint,
                            style: typo.micro.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Bagian Tarombo & Silsilah terpadu di Edit Profil (tanpa Saran Kerabat)
                  _EditProfileTaromboSection(
                    profile: _profile,
                    members: _taromboMembers,
                    completenessPercent: _taromboCompleteness,
                    incomingClaimsCount: _incomingClaims.length,
                    onEditMotherMarga: _openMotherMargaDialog,
                    onOpenTree: () async {
                      await context.push(AppPages.tar02.routePath);
                      if (mounted) await _load();
                    },
                    onAddMember: _openAddTaromboMember,
                    onCheckPartuturan: () =>
                        context.push(AppPages.tar06.routePath).ignore(),
                    onOpenConfirmations: () async {
                      await context.push(AppPages.tar07.routePath);
                      if (mounted) await _load();
                    },
                    onOpenMemberDetail: (memberId) async {
                      await context.push(
                        '${AppPages.tar04.routePath}?id=$memberId',
                      );
                      if (mounted) await _load();
                    },
                    onOpenTaromboSettings: () async {
                      await context.push(AppPages.tar01.routePath);
                      if (mounted) await _load();
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: AppStrings.actionSave,
                    isExpanded: true,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _save,
                  ),
                ],
              ),
      ),
    );
  }
}

class _EditProfileTaromboSection extends StatelessWidget {
  const _EditProfileTaromboSection({
    required this.profile,
    required this.members,
    required this.completenessPercent,
    required this.incomingClaimsCount,
    required this.onEditMotherMarga,
    required this.onOpenTree,
    required this.onAddMember,
    required this.onCheckPartuturan,
    required this.onOpenConfirmations,
    required this.onOpenMemberDetail,
    required this.onOpenTaromboSettings,
  });

  final Profil? profile;
  final List<FamilyMember> members;
  final int completenessPercent;
  final int incomingClaimsCount;
  final VoidCallback onEditMotherMarga;
  final VoidCallback onOpenTree;
  final VoidCallback onAddMember;
  final VoidCallback onCheckPartuturan;
  final VoidCallback onOpenConfirmations;
  final ValueChanged<String> onOpenMemberDetail;
  final VoidCallback onOpenTaromboSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final motherMarga = (profile?.motherMarga ?? '').trim();
    final memberTypes = members.map((m) => m.relationType).toSet();

    final items = <(String, bool)>[
      (AppStrings.tar01ItemMotherMarga, motherMarga.isNotEmpty),
      (
        AppStrings.tar01ItemFather,
        memberTypes.contains(FamilyRelationType.father),
      ),
      (
        AppStrings.tar01ItemMother,
        memberTypes.contains(FamilyRelationType.mother),
      ),
      (
        AppStrings.tar01ItemPaternalGrandfather,
        memberTypes.contains(FamilyRelationType.paternalGrandfather),
      ),
      (
        AppStrings.tar01ItemMaternalGrandfather,
        memberTypes.contains(FamilyRelationType.maternalGrandfather),
      ),
    ];

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    AppStrings.akn02TaromboSectionTitle,
                    style: typo.h3,
                  ),
                ),
                Text(
                  AppStrings.tar01CompletenessPercent(completenessPercent),
                  style: typo.bodyStrong.copyWith(color: colors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(AppStrings.tar01CompletenessSubtitle, style: typo.caption),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppRadius.pillRadius,
              child: LinearProgressIndicator(
                value: (completenessPercent / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: colors.chipInactive,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final item in items)
                  AppChip(
                    label: item.$1,
                    isSelected: item.$2,
                    leadingIcon: item.$2
                        ? Icons.check_circle_outline_rounded
                        : Icons.circle_outlined,
                    customBackgroundColor: item.$2
                        ? colors.primary.withValues(alpha: 0.12)
                        : colors.chipInactive,
                    customForegroundColor: item.$2
                        ? colors.primary
                        : colors.textMuted,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${AppStrings.tar01MotherMargaLabel}: ${motherMarga.isEmpty ? AppStrings.tar01MotherMargaEmpty : motherMarga}',
                    style: typo.caption,
                  ),
                ),
                TextButton(
                  onPressed: onEditMotherMarga,
                  child: const Text(AppStrings.tar01EditMotherMargaBtn),
                ),
              ],
            ),
            if (members.isNotEmpty) ...<Widget>[
              Divider(color: colors.border),
              for (final member in members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(member.fullName, style: typo.bodyStrong),
                  subtitle: Text(
                    '${member.relationType.label} · ${member.marga}',
                    style: typo.caption,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onOpenMemberDetail(member.id),
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                AppButton(
                  label: AppStrings.tar01OpenTreeBtn,
                  leadingIcon: Icons.account_tree_outlined,
                  onPressed: onOpenTree,
                ),
                AppButton(
                  label: AppStrings.tar01AddMemberBtn,
                  variant: AppButtonVariant.secondary,
                  leadingIcon: Icons.person_add_alt_1_outlined,
                  onPressed: onAddMember,
                ),
                AppButton(
                  label: AppStrings.tar01CheckPartuturanBtn,
                  variant: AppButtonVariant.secondary,
                  leadingIcon: Icons.calculate_outlined,
                  onPressed: onCheckPartuturan,
                ),
                AppButton(
                  label: incomingClaimsCount > 0
                      ? '${AppStrings.tar01ConfirmationsBtn} ($incomingClaimsCount)'
                      : AppStrings.tar01ConfirmationsBtn,
                  variant: AppButtonVariant.secondary,
                  leadingIcon: Icons.verified_outlined,
                  onPressed: onOpenConfirmations,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenTaromboSettings,
                icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                label: const Text(AppStrings.akn02TaromboPrivacyBtn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
