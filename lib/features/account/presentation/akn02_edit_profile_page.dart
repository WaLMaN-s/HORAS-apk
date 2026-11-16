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
    final profRes = await ref.read(profileRepositoryProvider).getMyProfile();
    final citiesRes = await ref
        .read(nearbyRepositoryProvider)
        .getAvailableCities();
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
      _isLoading = false;
    });
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
