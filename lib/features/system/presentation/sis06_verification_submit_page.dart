import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// SIS-06 Ajukan Verifikasi Komunitas & Gereja (`SIS-R6`).
///
/// Verifikasi gereja aktif saat `FeatureFlags.church == true`.
class Sis06VerificationSubmitPage extends ConsumerStatefulWidget {
  const Sis06VerificationSubmitPage({this.initialCommunityId, super.key});

  final String? initialCommunityId;

  @override
  ConsumerState<Sis06VerificationSubmitPage> createState() =>
      _Sis06VerificationSubmitPageState();
}

class _Sis06VerificationSubmitPageState
    extends ConsumerState<Sis06VerificationSubmitPage> {
  final _evidenceController = TextEditingController();
  final _contactController = TextEditingController();
  List<Community> _communities = const <Community>[];
  List<Church> _churches = const <Church>[];
  String? _selectedCommunityId;
  String? _selectedChurchId;
  bool _isChurch = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadData);
  }

  @override
  void dispose() {
    _evidenceController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final commFuture = ref.read(communityRepositoryProvider).getCommunities();
    final churchFuture = ref.read(churchRepositoryProvider).getChurches();

    final commRes = await commFuture;
    final churchRes = await churchFuture;
    if (!mounted) return;

    final commList = commRes is Ok<List<Community>>
        ? commRes.value
        : const <Community>[];
    final churchList = churchRes is Ok<List<Church>>
        ? churchRes.value
        : const <Church>[];

    setState(() {
      _communities = commList;
      _churches = churchList;
      _selectedCommunityId =
          commList.any((c) => c.id == widget.initialCommunityId)
          ? widget.initialCommunityId
          : (commList.isNotEmpty ? commList.first.id : null);
      if (churchList.isNotEmpty) {
        _selectedChurchId = churchList.first.id;
      }
      _isLoading = false;
    });
  }

  Future<void> _submit() async {
    final entityId = _isChurch ? _selectedChurchId : _selectedCommunityId;
    if (entityId == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    final res = await ref
        .read(verificationRepositoryProvider)
        .submitCommunityVerification(
          communityId: entityId,
          evidenceDescription: _evidenceController.text.trim(),
          contactInfo: _contactController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (res is Err<VerificationRequest>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    AppToast.show(
      context,
      message: AppStrings.sis06SuccessToast,
      variant: AppToastVariant.success,
    );
    context.pushReplacement(AppPages.sis07.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sis06Title)),
      body: SafeArea(
        child: _isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  Text(
                    AppStrings.sis06TypeLabel,
                    style: context.typo.bodyStrong,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (flags.church) ...<Widget>[
                    SegmentedButton<bool>(
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Komunitas / Punguan'),
                          icon: Icon(Icons.groups_outlined),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Gereja'),
                          icon: Icon(Icons.church_outlined),
                        ),
                      ],
                      selected: <bool>{_isChurch},
                      onSelectionChanged: (set) {
                        setState(() => _isChurch = set.first);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_isChurch) ...<Widget>[
                    if (_churches.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedChurchId,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Gereja',
                          border: OutlineInputBorder(),
                        ),
                        items: _churches
                            .map(
                              (ch) => DropdownMenuItem<String>(
                                value: ch.id,
                                child: Text(
                                  '${ch.name} (${ch.city})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (v) => setState(() => _selectedChurchId = v),
                      ),
                  ] else ...<Widget>[
                    if (_communities.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCommunityId,
                        decoration: const InputDecoration(
                          labelText: AppStrings.sis06CommunityLabel,
                          border: OutlineInputBorder(),
                        ),
                        items: _communities
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (v) =>
                            setState(() => _selectedCommunityId = v),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _evidenceController,
                    label: AppStrings.sis06EvidenceLabel,
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _contactController,
                    label: AppStrings.sis06ContactLabel,
                    helperText: AppStrings.sis06ContactHelper,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: AppStrings.sis06SubmitBtn,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
      ),
    );
  }
}
