import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/features/tarombo/presentation/tarombo_controller.dart';
import 'package:material_ui/material_ui.dart';

/// TAR-03 Tambah / Ubah Anggota Keluarga (`TAR-R2`, `TAR-R3`, `TAR-R11`).
///
/// Mendukung Ayah, Ibu, Kakek dari Ayah, dan Kakek dari Ibu agar kelengkapan 5 butir
/// (100%) tercapai. Menampilkan layar persetujuan `TAR-R2` terlebih dahulu bila belum
/// pernah disetujui. Tidak memuat foto maupun kontak (`TAR-R3`).
class Tar03MemberFormPage extends ConsumerStatefulWidget {
  const Tar03MemberFormPage({super.key, this.memberId, this.initialTypeRaw});

  final String? memberId;
  final String? initialTypeRaw;

  @override
  ConsumerState<Tar03MemberFormPage> createState() =>
      _Tar03MemberFormPageState();
}

class _Tar03MemberFormPageState extends ConsumerState<Tar03MemberFormPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _margaCtrl = TextEditingController();
  final TextEditingController _birthYearCtrl = TextEditingController();

  FamilyRelationType _relationType = FamilyRelationType.father;
  UserGender _gender = UserGender.male;
  LifeStatus _lifeStatus = LifeStatus.alive;
  bool _saving = false;
  bool _initializedFromExisting = false;
  String? _errorMsg;

  static const List<FamilyRelationType> _allowedTypes = <FamilyRelationType>[
    FamilyRelationType.father,
    FamilyRelationType.mother,
    FamilyRelationType.paternalGrandfather,
    FamilyRelationType.maternalGrandfather,
  ];

  @override
  void initState() {
    super.initState();
    for (final t in _allowedTypes) {
      if (t.name == widget.initialTypeRaw) {
        _relationType = t;
        _syncDefaultsForType(t);
        break;
      }
    }
  }

  void _syncDefaultsForType(FamilyRelationType type) {
    if (type == FamilyRelationType.mother) {
      _gender = UserGender.female;
    } else {
      _gender = UserGender.male;
    }
  }

  void _hydrateFromState(TaromboState state) {
    if (_initializedFromExisting) return;
    _initializedFromExisting = true;
    final id = widget.memberId;
    if (id != null && id.isNotEmpty) {
      final existing = state.members.where((m) => m.id == id).firstOrNull;
      if (existing != null) {
        _relationType = existing.relationType;
        _nameCtrl.text = existing.fullName;
        _margaCtrl.text = existing.marga;
        _gender = existing.gender;
        _lifeStatus = existing.lifeStatus;
        if (existing.birthYear != null) {
          _birthYearCtrl.text = '${existing.birthYear}';
        }
        return;
      }
    }

    // Isi bawaan marga dari profil sendiri bila Ayah/Kakek dari Ayah dipilih
    final profile = state.profile;
    if (profile != null && _margaCtrl.text.isEmpty) {
      if (_relationType == FamilyRelationType.father ||
          _relationType == FamilyRelationType.paternalGrandfather) {
        _margaCtrl.text = profile.marga;
      } else if ((_relationType == FamilyRelationType.mother ||
              _relationType == FamilyRelationType.maternalGrandfather) &&
          (profile.motherMarga ?? '').isNotEmpty) {
        _margaCtrl.text = profile.motherMarga!;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _margaCtrl.dispose();
    _birthYearCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    int? birthYear;
    final rawYear = _birthYearCtrl.text.trim();
    if (rawYear.isNotEmpty) {
      birthYear = int.tryParse(rawYear);
      if (birthYear == null || birthYear < 1850 || birthYear > 2026) {
        setState(
          () => _errorMsg = 'Tahun lahir opsional harus berupa tahun valid.',
        );
        return;
      }
    }

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    final res = await ref
        .read(taromboControllerProvider.notifier)
        .upsertMember(
          id: (widget.memberId ?? '').isEmpty ? null : widget.memberId,
          relationType: _relationType,
          fullName: _nameCtrl.text,
          marga: _margaCtrl.text,
          gender: _gender,
          birthYear: birthYear,
          lifeStatus: _lifeStatus,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (res is Err<FamilyMember>) {
      setState(() => _errorMsg = res.failure.message);
      return;
    }

    AppToast.show(
      context,
      message: AppStrings.tar03SavedToast,
      variant: AppToastVariant.success,
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taromboControllerProvider);
    _hydrateFromState(state);
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.tar03Title)),
      body: !state.hasGivenConsent
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(AppStrings.tarConsentTitle, style: typo.h2),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(AppStrings.tarConsentBody, style: typo.body),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: AppStrings.tarConsentAcceptBtn,
                    onPressed: () => ref
                        .read(taromboControllerProvider.notifier)
                        .giveConsent(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: AppStrings.tarConsentCancelBtn,
                    variant: AppButtonVariant.text,
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.chipInactive,
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    AppStrings.tar03NoPhotoOrContactNote,
                    style: typo.caption,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(AppStrings.tar03RelationLabel, style: typo.bodyStrong),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<FamilyRelationType>(
                  initialValue: _relationType,
                  decoration: const InputDecoration(),
                  items: <DropdownMenuItem<FamilyRelationType>>[
                    for (final type in _allowedTypes)
                      DropdownMenuItem<FamilyRelationType>(
                        value: type,
                        child: Text(type.label),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _relationType = val;
                        _syncDefaultsForType(val);
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _nameCtrl,
                  label: AppStrings.tar03FullNameLabel,
                  hintText: AppStrings.tar03FullNameHint,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _margaCtrl,
                  label: AppStrings.tar03MargaLabel,
                  hintText: AppStrings.tar03MargaHint,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(AppStrings.tar03GenderLabel, style: typo.bodyStrong),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<UserGender>(
                  segments: <ButtonSegment<UserGender>>[
                    for (final g in UserGender.values)
                      ButtonSegment<UserGender>(value: g, label: Text(g.label)),
                  ],
                  selected: <UserGender>{_gender},
                  onSelectionChanged: (sel) {
                    if (sel.isNotEmpty) setState(() => _gender = sel.first);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _birthYearCtrl,
                  label: AppStrings.tar03BirthYearLabel,
                  hintText: AppStrings.tar03BirthYearHint,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(AppStrings.tar03LifeStatusLabel, style: typo.bodyStrong),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<LifeStatus>(
                  segments: <ButtonSegment<LifeStatus>>[
                    for (final s in LifeStatus.values)
                      ButtonSegment<LifeStatus>(value: s, label: Text(s.label)),
                  ],
                  selected: <LifeStatus>{_lifeStatus},
                  onSelectionChanged: (sel) {
                    if (sel.isNotEmpty) setState(() => _lifeStatus = sel.first);
                  },
                ),
                if (_errorMsg != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _errorMsg!,
                    style: typo.caption.copyWith(color: colors.danger),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: AppStrings.tar03SaveBtn,
                  isLoading: _saving,
                  onPressed: _submit,
                ),
              ],
            ),
    );
  }
}
