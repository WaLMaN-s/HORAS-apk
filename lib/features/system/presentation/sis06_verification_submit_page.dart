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

/// SIS-06 Ajukan Verifikasi Komunitas (`SIS-R6`).
///
/// Verifikasi gereja adalah Fase 2 (`FeatureFlags.church == false`) sehingga
/// MVP hanya melayani verifikasi komunitas / punguan.
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
  String? _selectedCommunityId;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadCommunities);
  }

  @override
  void dispose() {
    _evidenceController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunities() async {
    final res = await ref.read(communityRepositoryProvider).getCommunities();
    if (!mounted) return;
    final list = res is Ok<List<Community>> ? res.value : const <Community>[];
    setState(() {
      _communities = list;
      _selectedCommunityId = list.any((c) => c.id == widget.initialCommunityId)
          ? widget.initialCommunityId
          : (list.isNotEmpty ? list.first.id : null);
      _isLoading = false;
    });
  }

  Future<void> _submit() async {
    final communityId = _selectedCommunityId;
    if (communityId == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    final res = await ref
        .read(verificationRepositoryProvider)
        .submitCommunityVerification(
          communityId: communityId,
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
                  // Fase 2 guard: verifikasi gereja disembunyikan saat flag off.
                  if (flags.church) const SizedBox.shrink(),
                  const SizedBox(height: AppSpacing.md),
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
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: AppStrings.sis06SubmitBtn,
                    isExpanded: true,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: AppStrings.sis06StatusShortcutBtn,
                    variant: AppButtonVariant.text,
                    isExpanded: true,
                    onPressed: () =>
                        context.push(AppPages.sis07.routePath).ignore(),
                  ),
                ],
              ),
      ),
    );
  }
}
