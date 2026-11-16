import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/nearby/presentation/nearby_controller.dart';
import 'package:horas/features/nearby/presentation/nearby_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-05 Daftar Komunitas: jelajah dan cari (`SEK-R7`, `AC-13`).
///
/// Jenis Gereja (Fase 2) disembunyikan dan komunitas Tertutup tidak tampil bagi non-anggota.
class Sek05CommunitiesListPage extends ConsumerStatefulWidget {
  const Sek05CommunitiesListPage({super.key});

  @override
  ConsumerState<Sek05CommunitiesListPage> createState() =>
      _Sek05CommunitiesListPageState();
}

class _Sek05CommunitiesListPageState
    extends ConsumerState<Sek05CommunitiesListPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  CommunityType? _selectedType;
  bool _isLoading = true;
  AppError? _error;
  List<Community> _communities = const <Community>[];

  static const List<CommunityType> _phase1Types = <CommunityType>[
    CommunityType.punguanMarga,
    CommunityType.city,
    CommunityType.campusOrProfession,
    CommunityType.interest,
  ];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final query = _searchCtrl.text.trim();
    final res = query.isEmpty
        ? await ref
              .read(communityRepositoryProvider)
              .getCommunities(type: _selectedType)
        : await ref
              .read(searchRepositoryProvider)
              .searchCommunities(query: query, type: _selectedType);

    if (!mounted) return;
    if (res is Err<List<Community>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }

    final list = (res as Ok<List<Community>>).value
        .where((c) => c.type != CommunityType.church)
        .toList(growable: false);
    setState(() {
      _isLoading = false;
      _communities = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nearbyState = ref.watch(nearbyControllerProvider);
    final nearbyController = ref.read(nearbyControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.sek05Title),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.sek01CreateCommunityBtn,
            onPressed: () async {
              await context.push(AppPages.sek07.routePath);
              if (mounted) await _load();
            },
            icon: Semantics(
              label: AppStrings.sek01CreateCommunityBtn,
              child: const Icon(Icons.add_circle_outline_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.sm,
              AppSpacing.screenMargin,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  controller: _searchCtrl,
                  hintText: AppStrings.sek12SearchHint,
                  textInputAction: TextInputAction.search,
                  leadingIcon: Icons.search_rounded,
                  onSubmitted: (_) => _load(),
                  onChanged: (_) => setState(() {}),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? Icons.close_rounded
                      : null,
                  suffixSemanticsLabel: AppStrings.semanticsClose,
                  onSuffixTap: _searchCtrl.text.isNotEmpty
                      ? () {
                          _searchCtrl.clear();
                          _load();
                        }
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      AppChip(
                        label: AppStrings.sek03AllCities.replaceAll(
                          'Kota',
                          'Semua',
                        ),
                        isSelected: _selectedType == null,
                        onTap: () {
                          setState(() => _selectedType = null);
                          _load();
                        },
                      ),
                      for (final type in _phase1Types) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        AppChip(
                          label: type.label,
                          isSelected: _selectedType == type,
                          onTap: () {
                            setState(() => _selectedType = type);
                            _load();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(context, nearbyState, nearbyController)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NearbyState nearbyState,
    NearbyController nearbyController,
  ) {
    if (nearbyState.locationPermissionDenied) {
      return StateView.permissionDenied(
        benefitMessage: AppStrings.sek01LocationPermissionBenefit,
        onOpenSettings: () async {
          final picked = await showManualAreaPickerSheet(
            context: context,
            cities: nearbyState.availableCities,
            selectedCity: nearbyState.selectedCity,
          );
          if (picked != null && picked.isNotEmpty) {
            await nearbyController.setSelectedCity(picked);
            await _load();
          }
        },
        onContinueWithoutPermission: () async {
          await nearbyController.continueWithManualArea();
          await _load();
        },
      );
    }

    if (_isLoading) {
      return const SingleChildScrollView(
        child: StateView.loading(itemCount: 4),
      );
    }

    if (_error != null) {
      return StateView.fromError(_error!, onRetry: _load);
    }

    if (_communities.isEmpty) {
      return StateView.empty(
        message: AppStrings.sek01EmptyCommunitiesMessage,
        actionLabel: AppStrings.sek01CreateCommunityBtn,
        onAction: () => context.push(AppPages.sek07.routePath),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          AppSpacing.sm,
          AppSpacing.screenMargin,
          AppSpacing.xxl,
        ),
        itemCount: _communities.length,
        itemBuilder: (context, index) {
          final comm = _communities[index];
          return CommunityCard(
            community: comm,
            onTap: () =>
                context.push('${AppPages.sek06.routePath}?id=${comm.id}'),
          );
        },
      ),
    );
  }
}
