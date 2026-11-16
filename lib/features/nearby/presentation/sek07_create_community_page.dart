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
import 'package:horas/features/nearby/presentation/nearby_controller.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-07 Buat Komunitas (`SEK-R7`, `SEK-R8`, `SEK-R9`, `SEK-R11`).
///
/// Jenis Gereja adalah Fase 2 dan tidak ditampilkan. Akun minimal 7 hari,
/// maksimal 5 komunitas per akun, nama 3–60 unik per jenis+kota, deskripsi maks 500.
class Sek07CreateCommunityPage extends ConsumerStatefulWidget {
  const Sek07CreateCommunityPage({super.key});

  @override
  ConsumerState<Sek07CreateCommunityPage> createState() =>
      _Sek07CreateCommunityPageState();
}

class _Sek07CreateCommunityPageState
    extends ConsumerState<Sek07CreateCommunityPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _margaCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  CommunityType _selectedType = CommunityType.interest;
  CommunityAccessType _selectedAccess = CommunityAccessType.open;
  late String _selectedCity;
  bool _submitting = false;
  String? _errorMsg;

  static const List<CommunityType> _phase1Types = <CommunityType>[
    CommunityType.punguanMarga,
    CommunityType.city,
    CommunityType.campusOrProfession,
    CommunityType.interest,
  ];

  @override
  void initState() {
    super.initState();
    _selectedCity = ref.read(nearbyControllerProvider).selectedCity;
    if (_selectedCity.isEmpty) {
      _selectedCity = 'Medan';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _margaCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorMsg = null;
    });

    final res = await ref
        .read(communityRepositoryProvider)
        .createCommunity(
          name: _nameCtrl.text,
          type: _selectedType,
          accessType: _selectedAccess,
          city: _selectedCity,
          description: _descCtrl.text,
          margaName: _selectedType == CommunityType.punguanMarga
              ? _margaCtrl.text
              : null,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res is Err<Community>) {
      setState(() => _errorMsg = res.failure.message);
      return;
    }

    final created = (res as Ok<Community>).value;
    await ref.read(nearbyControllerProvider.notifier).loadInitial();
    if (!mounted) return;
    AppToast.show(
      context,
      message: AppStrings.sek07CreatedToast,
      variant: AppToastVariant.success,
    );
    context.pushReplacement('${AppPages.sek06.routePath}?id=${created.id}');
  }

  @override
  Widget build(BuildContext context) {
    final nearbyState = ref.watch(nearbyControllerProvider);
    final colors = context.colors;
    final typo = context.typo;
    final cities = nearbyState.availableCities.isNotEmpty
        ? nearbyState.availableCities.map((c) => c.name).toList()
        : <String>[_selectedCity];

    if (!cities.contains(_selectedCity)) {
      cities.insert(0, _selectedCity);
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sek07Title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: <Widget>[
          Text(AppStrings.sek07TypeLabel, style: typo.bodyStrong),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final t in _phase1Types)
                AppChip(
                  label: t.label,
                  isSelected: _selectedType == t,
                  onTap: () => setState(() => _selectedType = t),
                ),
            ],
          ),
          if (_selectedType == CommunityType.punguanMarga) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.chipInactive,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: colors.border),
              ),
              child: Text(
                AppStrings.sek07PunguanUnverifiedNote,
                style: typo.caption,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _margaCtrl,
              label: AppStrings.sek07MargaNameLabel,
              hintText: AppStrings.sek03MargaLabel,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _nameCtrl,
            label: AppStrings.sek07NameLabel,
            hintText: AppStrings.sek07NameHint,
            maxLength: AppLimits.communityNameMaxChars,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.sek07CityLabel, style: typo.bodyStrong),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<String>(
            initialValue: _selectedCity,
            decoration: const InputDecoration(),
            items: <DropdownMenuItem<String>>[
              for (final city in cities)
                DropdownMenuItem<String>(value: city, child: Text(city)),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedCity = val);
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _descCtrl,
            label: AppStrings.sek07DescLabel,
            hintText: AppStrings.sek07DescHint,
            maxLines: 4,
            maxLength: AppLimits.communityDescMaxChars,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.sek07AccessLabel, style: typo.bodyStrong),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<CommunityAccessType>(
            segments: const <ButtonSegment<CommunityAccessType>>[
              ButtonSegment<CommunityAccessType>(
                value: CommunityAccessType.open,
                label: Text(AppStrings.sek05AccessOpen),
              ),
              ButtonSegment<CommunityAccessType>(
                value: CommunityAccessType.approvalRequired,
                label: Text(AppStrings.sek05AccessApproval),
              ),
              ButtonSegment<CommunityAccessType>(
                value: CommunityAccessType.closed,
                label: Text(AppStrings.sek05AccessClosed),
              ),
            ],
            selected: <CommunityAccessType>{_selectedAccess},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                setState(() => _selectedAccess = selection.first);
              }
            },
          ),
          if (_errorMsg != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.1),
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: colors.danger),
              ),
              child: Text(
                _errorMsg!,
                style: typo.caption.copyWith(color: colors.danger),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: AppStrings.sek07SubmitBtn,
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
