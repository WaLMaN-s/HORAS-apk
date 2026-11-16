import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/app_config.dart';
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
import 'package:horas/features/tarombo/presentation/tarombo_controller.dart';
import 'package:material_ui/material_ui.dart';

/// TAR-05 Detail Hubungan (`TAR-R5`, `TAR-R6`, `TAR-R8`, `AC-03`, `AC-04`).
///
/// Menampilkan 3 varian sesuai tingkat keyakinan (`Tinggi`, `Sedang`, `Rendah`)
/// dan mode netral untuk sub-suku tanpa aturan tervalidasi.
class Tar05RelationshipDetailPage extends ConsumerStatefulWidget {
  const Tar05RelationshipDetailPage({required this.targetUserId, super.key});

  final String targetUserId;

  @override
  ConsumerState<Tar05RelationshipDetailPage> createState() =>
      _Tar05RelationshipDetailPageState();
}

class _Tar05RelationshipDetailPageState
    extends ConsumerState<Tar05RelationshipDetailPage> {
  bool _isLoading = true;
  bool _isBusy = false;
  AppError? _error;
  PersonSummary? _target;
  PartuturanResult? _result;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (widget.targetUserId.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _error = const UnavailableError(
          message: AppStrings.stateContentUnavailableMessage,
        );
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final profileRepo = ref.read(profileRepositoryProvider);
    final partuturanRepo = ref.read(partuturanRepositoryProvider);

    final personFuture = profileRepo.getPersonSummary(widget.targetUserId);
    final evalFuture = partuturanRepo.evaluateWithUser(widget.targetUserId);

    final personRes = await personFuture;
    final evalRes = await evalFuture;
    if (!mounted) return;

    if (personRes is Err<PersonSummary>) {
      setState(() {
        _isLoading = false;
        _error = personRes.failure;
      });
      return;
    }
    if (evalRes is Err<PartuturanResult>) {
      setState(() {
        _isLoading = false;
        _error = evalRes.failure;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _target = (personRes as Ok<PersonSummary>).value;
      _result = (evalRes as Ok<PartuturanResult>).value;
    });
  }

  Future<void> _confirmRelationship() async {
    final target = _target;
    final resObj = _result;
    if (target == null || resObj == null || _isBusy) return;
    setState(() => _isBusy = true);
    final claimRes = await ref
        .read(taromboControllerProvider.notifier)
        .sendClaim(
          targetUserId: target.id,
          claimedTerm: resObj.istilah ?? AppStrings.termKenalan,
          note: resObj.penjelasanJalur,
        );
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (claimRes is Err<PartuturanClaim>) {
      AppToast.show(
        context,
        message: claimRes.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    AppToast.show(
      context,
      message: AppStrings.tar07ClaimSentToast,
      variant: AppToastVariant.success,
    );
  }

  Future<void> _submitNotThis() async {
    final target = _target;
    final resObj = _result;
    if (target == null || resObj == null || _isBusy) return;
    setState(() => _isBusy = true);
    final fbRes = await ref
        .read(partuturanRepositoryProvider)
        .submitNotThisFeedback(
          targetMarga: target.marga,
          shownTerm: resObj.istilah,
        );
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (fbRes is Err<PartuturanFeedback>) {
      AppToast.show(
        context,
        message: fbRes.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    AppToast.show(
      context,
      message: AppStrings.sek04KinshipFeedbackToast,
      variant: AppToastVariant.info,
    );
  }

  Future<void> _reportWrongRule() async {
    final target = _target;
    final resObj = _result;
    if (target == null || resObj == null) return;
    final noteCtrl = TextEditingController();
    final submittedNote = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.tar05ReportWrongRuleTitle),
        content: AppTextField(
          controller: noteCtrl,
          hintText: AppStrings.tar05ReportWrongRuleHint,
          maxLines: 3,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(noteCtrl.text.trim()),
            child: const Text(AppStrings.actionConfirm),
          ),
        ],
      ),
    );
    noteCtrl.dispose();
    if (submittedNote == null || !mounted) return;

    final repRes = await ref
        .read(partuturanRepositoryProvider)
        .reportWrongRule(
          ruleOrTargetId: '${target.marga}:${resObj.versiAturan}',
          note: submittedNote.isEmpty
              ? AppStrings.tar05ReportWrongRuleTitle
              : submittedNote,
        );
    if (!mounted) return;
    if (repRes is Err<Report>) {
      AppToast.show(
        context,
        message: repRes.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    AppToast.show(
      context,
      message: AppStrings.tar05ReportSubmittedToast,
      variant: AppToastVariant.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.tar05Title)),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    }

    if (_error != null || _target == null || _result == null) {
      return StateView.fromError(
        _error ??
            const UnavailableError(
              message: AppStrings.stateContentUnavailableMessage,
            ),
        onRetry: _load,
        onBack: () => context.pop(),
      );
    }

    final target = _target!;
    final res = _result!;
    final appConfig = ref.watch(appConfigProvider);
    final colors = context.colors;
    final typo = context.typo;

    final mainStatement = res.modeNetral
        ? AppStrings.sek04NeutralModeHint
        : switch (res.confidence) {
            PartuturanConfidence.tinggi => AppStrings.partuturanHighLabel(
              res.istilah ?? '',
            ),
            PartuturanConfidence.sedang => AppStrings.partuturanMediumLabel(
              res.istilah ?? '',
            ),
            PartuturanConfidence.rendah => AppStrings.partuturanLowLabel,
          };

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: <Widget>[
          // Identitas Target
          Row(
            children: <Widget>[
              AppAvatar(
                name: target.displayName,
                seed: target.avatarSeed,
                size: AppSizes.avatarLg,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(target.displayName, style: typo.h2),
                    Text(
                      '${target.marga} · ${target.subEthnic.displayName}',
                      style: typo.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Kartu Hasil Partuturan (3 Varian: Tinggi, Sedang, Rendah + Netral)
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
                Text(
                  AppStrings.tar05SectionCallTerm,
                  style: typo.captionStrong,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!res.modeNetral) ...<Widget>[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      PartuturanBadge(
                        result: res,
                        showDraftIndicator: appConfig.allowDraftRules,
                      ),
                      if (res.isEstimate)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: colors.confidenceAmberSurface,
                            borderRadius: AppRadius.pillRadius,
                            border: Border.all(color: colors.confidenceAmber),
                          ),
                          child: Text(
                            AppStrings.termPerkiraan,
                            style: typo.micro.copyWith(
                              color: colors.confidenceAmber,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(mainStatement, style: typo.h2),
                const SizedBox(height: AppSpacing.xs),
                if (!res.modeNetral)
                  Text(
                    res.confidence == PartuturanConfidence.tinggi
                        ? AppStrings.tar05ConfirmedBadgeDesc
                        : AppStrings.tar05EstimateBadgeDesc,
                    style: typo.caption,
                  ),
                if (res.penjelasanJalur.isNotEmpty) ...<Widget>[
                  const Divider(height: AppSpacing.xl),
                  Text(AppStrings.tar05SectionPath, style: typo.captionStrong),
                  const SizedBox(height: AppSpacing.xs),
                  Text(res.penjelasanJalur, style: typo.body),
                ],
                if (res.confidence == PartuturanConfidence.rendah &&
                    (res.pertanyaanPelengkap ?? '').isNotEmpty &&
                    !res.modeNetral) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.chipInactive,
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: Text(res.pertanyaanPelengkap!, style: typo.caption),
                  ),
                ],
              ],
            ),
          ),

          if (target.isSameMarga) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const SemargaLabel(),
          ],

          // Aksi untuk hasil Sedang / Rendah (TAR-R5, TAR-R7, TAR-R8)
          if (!res.modeNetral &&
              res.confidence != PartuturanConfidence.tinggi) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: AppStrings.sek04KinshipAcceptQuestion,
                    isLoading: _isBusy,
                    onPressed: _confirmRelationship,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: AppStrings.sek04KinshipRejectQuestion,
                    variant: AppButtonVariant.secondary,
                    onPressed: _isBusy ? null : _submitNotThis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: AppStrings.tar05SendWeAreKinBtn,
              variant: AppButtonVariant.secondary,
              leadingIcon: Icons.handshake_outlined,
              onPressed: () => context.push(
                '${AppPages.tar07.routePath}?targetId=${target.id}&term=${Uri.encodeComponent(res.istilah ?? '')}',
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: AppStrings.tar05ReportWrongRuleBtn,
            variant: AppButtonVariant.text,
            isDestructive: true,
            leadingIcon: Icons.flag_outlined,
            onPressed: _reportWrongRule,
          ),
        ],
      ),
    );
  }
}
