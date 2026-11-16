import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/privacy_defaults.dart';
import 'package:material_ui/material_ui.dart';

/// AKN-08 Pengaturan Privasi per Bidang (`AKN-R3`, PRD 7.1).
class Akn08PrivacyPage extends ConsumerStatefulWidget {
  const Akn08PrivacyPage({super.key});

  @override
  ConsumerState<Akn08PrivacyPage> createState() => _Akn08PrivacyPageState();
}

class _Akn08PrivacyPageState extends ConsumerState<Akn08PrivacyPage> {
  PrivacySettings _settings = const PrivacySettings();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final res = await ref
        .read(privacyRepositoryProvider)
        .getMyPrivacySettings();
    if (!mounted) return;
    setState(() {
      if (res is Ok<PrivacySettings>) {
        _settings = res.value;
      }
      _isLoading = false;
    });
  }

  Future<void> _update(PrivacySettings next) async {
    setState(() {
      _settings = next;
      _isSaving = true;
    });
    final res = await ref
        .read(privacyRepositoryProvider)
        .updateMyPrivacySettings(next);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (res is Ok<PrivacySettings>) {
      AppToast.show(
        context,
        message: AppStrings.akn08SavedToast,
        variant: AppToastVariant.success,
      );
    }
  }

  String _visLabel(FieldVisibility vis) {
    return switch (vis) {
      FieldVisibility.everyone => AppStrings.akn08VisEveryone,
      FieldVisibility.connectedOnly => AppStrings.akn08VisConnected,
      FieldVisibility.onlyMe => AppStrings.akn08VisOnlyMe,
    };
  }

  String _allowanceLabel(ConnectionRequestAllowance allowance) {
    return switch (allowance) {
      ConnectionRequestAllowance.everyone => AppStrings.akn08VisEveryone,
      ConnectionRequestAllowance.sameCommunity =>
        AppStrings.akn08VisSameMargaOrComm,
      ConnectionRequestAllowance.noOne => AppStrings.akn08VisOnlyMe,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.akn08Title)),
      body: SafeArea(
        child: _isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.chipInactive,
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: Text(
                      AppStrings.akn08PublicInfoNote,
                      style: typo.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Text(
                    AppStrings.akn08AccountTypeLabel,
                    style: typo.bodyStrong,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: <Widget>[
                      AppChip(
                        label: AppStrings.akn08PublicAccount,
                        isSelected:
                            _settings.accountType ==
                            AccountVisibilityType.publicAccount,
                        onTap: () => _update(
                          _settings.copyWith(
                            accountType: AccountVisibilityType.publicAccount,
                          ),
                        ),
                      ),
                      AppChip(
                        label: AppStrings.akn08PrivateAccount,
                        isSelected:
                            _settings.accountType ==
                            AccountVisibilityType.privateAccount,
                        onTap: () => _update(
                          _settings.copyWith(
                            accountType: AccountVisibilityType.privateAccount,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _VisibilitySelector(
                    label: AppStrings.akn08FieldMotherMarga,
                    value: _settings.motherMarga,
                    labelOf: _visLabel,
                    onChanged: (v) =>
                        _update(_settings.copyWith(motherMarga: v)),
                  ),
                  _VisibilitySelector(
                    label: AppStrings.akn08FieldSubdistrict,
                    value: _settings.subdistrict,
                    labelOf: _visLabel,
                    onChanged: (v) =>
                        _update(_settings.copyWith(subdistrict: v)),
                  ),
                  _VisibilitySelector(
                    label: AppStrings.akn08FieldCommunities,
                    value: _settings.joinedCommunities,
                    labelOf: _visLabel,
                    onChanged: (v) =>
                        _update(_settings.copyWith(joinedCommunities: v)),
                  ),
                  _VisibilitySelector(
                    label: AppStrings.akn08FieldHomeChurch,
                    value: _settings.homeChurch,
                    labelOf: _visLabel,
                    onChanged: (v) =>
                        _update(_settings.copyWith(homeChurch: v)),
                  ),
                  _VisibilitySelector(
                    label: AppStrings.akn08FieldTarombo,
                    value: _settings.tarombo,
                    labelOf: _visLabel,
                    onChanged: (v) => _update(_settings.copyWith(tarombo: v)),
                  ),

                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.akn08WhoCanConnectLabel,
                    style: typo.bodyStrong,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: ConnectionRequestAllowance.values
                        .map(
                          (a) => AppChip(
                            label: _allowanceLabel(a),
                            isSelected:
                                _settings.whoCanSendConnectionRequest == a,
                            onTap: () => _update(
                              _settings.copyWith(
                                whoCanSendConnectionRequest: a,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(AppStrings.akn08FieldAgeGroup),
                    value: _settings.showAgeGroup,
                    onChanged: _isSaving
                        ? null
                        : (v) => _update(_settings.copyWith(showAgeGroup: v)),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(AppStrings.akn08DiscoverableLabel),
                    value: _settings.discoverableInNearbyAndSearch,
                    onChanged: _isSaving
                        ? null
                        : (v) => _update(
                            _settings.copyWith(
                              discoverableInNearbyAndSearch: v,
                            ),
                          ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(AppStrings.akn08SharedContextMsgLabel),
                    value: _settings.allowMessagesFromSharedContext,
                    onChanged: _isSaving
                        ? null
                        : (v) => _update(
                            _settings.copyWith(
                              allowMessagesFromSharedContext: v,
                            ),
                          ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(AppStrings.akn08ReadReceiptsLabel),
                    value: _settings.sendReadReceipts,
                    onChanged: _isSaving
                        ? null
                        : (v) =>
                              _update(_settings.copyWith(sendReadReceipts: v)),
                  ),
                ],
              ),
      ),
    );
  }
}

class _VisibilitySelector extends StatelessWidget {
  const _VisibilitySelector({
    required this.label,
    required this.value,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final FieldVisibility value;
  final String Function(FieldVisibility) labelOf;
  final ValueChanged<FieldVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: context.typo.bodyStrong),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: FieldVisibility.values
                .map(
                  (v) => AppChip(
                    label: labelOf(v),
                    isSelected: value == v,
                    onTap: () => onChanged(v),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
