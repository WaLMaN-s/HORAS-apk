import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/play/presentation/play_controller.dart';
import 'package:horas/features/play/presentation/play_models.dart';
import 'package:material_ui/material_ui.dart';

/// MAN-06 Patungan Biaya (`MAN-R7`).
///
/// Pembayaran terjadi di luar aplikasi; tidak ada nomor rekening maupun
/// integrasi pembayaran di layar ini.
class Man06PatunganPage extends ConsumerStatefulWidget {
  const Man06PatunganPage({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<Man06PatunganPage> createState() => _Man06PatunganPageState();
}

class _Man06PatunganPageState extends ConsumerState<Man06PatunganPage> {
  final _amountController = TextEditingController();
  bool _isTotalAmount = true;
  PlaySession? _session;
  List<PaymentShare> _shares = const <PaymentShare>[];
  bool _isLoading = true;
  bool _isSaving = false;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.sessionId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final sessionRepo = ref.read(sessionRepositoryProvider);
    final sessionRes = await sessionRepo.getSessionById(widget.sessionId);
    if (!mounted) return;
    if (sessionRes is Err<PlaySession>) {
      setState(() {
        _isLoading = false;
        _error = sessionRes.failure;
      });
      return;
    }

    final sharesRes = await sessionRepo.getPaymentShares(widget.sessionId);
    if (!mounted) return;

    final session = (sessionRes as Ok<PlaySession>).value;
    if (_amountController.text.isEmpty && session.feePerPersonRupiah > 0) {
      _amountController.text =
          (_isTotalAmount
                  ? session.feePerPersonRupiah * session.participantCount
                  : session.feePerPersonRupiah)
              .toString();
    }

    setState(() {
      _session = session;
      _shares = sharesRes is Ok<List<PaymentShare>>
          ? sharesRes.value
          : const <PaymentShare>[];
      _isLoading = false;
    });
  }

  Future<void> _recalculate() async {
    FocusScope.of(context).unfocus();
    final parsed =
        int.tryParse(
          _amountController.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        -1;
    setState(() => _isSaving = true);
    final res = await ref
        .read(sessionRepositoryProvider)
        .updatePatungan(
          sessionId: widget.sessionId,
          amountRupiah: parsed,
          isTotalAmount: _isTotalAmount,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res is Err<List<PaymentShare>>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }

    await ref.read(playControllerProvider.notifier).loadInitial();
    await _load();
  }

  Future<void> _markPaid(String paymentShareId) async {
    final res = await ref
        .read(sessionRepositoryProvider)
        .markPaymentPaid(paymentShareId);
    if (!mounted) return;
    if (res is Err<PaymentShare>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await _load();
  }

  Future<void> _confirmReceived(String paymentShareId) async {
    final res = await ref
        .read(sessionRepositoryProvider)
        .confirmPaymentReceived(paymentShareId);
    if (!mounted) return;
    if (res is Err<PaymentShare>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.read(authRepositoryProvider).currentUserId;
    final colors = context.colors;
    final typo = context.typo;

    Widget body;
    if (_isLoading) {
      body = const StateView.loading(itemCount: 3);
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _load);
    } else if (_session == null) {
      body = StateView.empty(
        message: AppStrings.stateEmptyDefaultTitle,
        actionLabel: AppStrings.semanticsBack,
        onAction: () => context.pop(),
      );
    } else {
      final session = _session!;
      final isHost = currentUserId == session.host.id;

      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          // MAN-R7: Disclaimer pembayaran di luar aplikasi (tanpa input rekening).
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.confidenceAmberSurface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: colors.confidenceAmber),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  color: colors.confidenceAmber,
                  size: AppSizes.iconMd,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    AppStrings.man06DisclaimerBanner,
                    style: typo.caption,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(session.title, style: typo.h3),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.man06PerPersonResult(session.feePerPersonRupiah),
                    style: typo.h2.copyWith(color: colors.primary),
                  ),
                ],
              ),
            ),
          ),

          if (isHost) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                AppChip(
                  label: AppStrings.man06ModeTotal,
                  isSelected: _isTotalAmount,
                  onTap: () => setState(() => _isTotalAmount = true),
                ),
                AppChip(
                  label: AppStrings.man06ModePerPerson,
                  isSelected: !_isTotalAmount,
                  onTap: () => setState(() => _isTotalAmount = false),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _amountController,
              label: AppStrings.man06AmountLabel,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: AppStrings.man06RecalculateBtn,
              isExpanded: true,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _recalculate,
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          ..._shares.map((share) {
            final isMine = share.participant.id == currentUserId;
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        AppAvatar(
                          name: share.participant.displayName,
                          seed: share.participant.avatarSeed,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                share.participant.displayName,
                                style: typo.bodyStrong,
                              ),
                              Text(
                                PlayFormatters.formatRupiah(
                                  share.amountRupiah,
                                  freeLabel: AppStrings.man01FreeFeeLabel,
                                ),
                                style: typo.caption.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (share.hostConfirmedPaid)
                          AppChip(
                            label: AppStrings.man06PaidConfirmedBadge,
                            customBackgroundColor: colors.primary.withValues(
                              alpha: 0.12,
                            ),
                            customForegroundColor: colors.primary,
                          )
                        else if (share.participantMarkedPaid)
                          AppChip(
                            label: AppStrings.man06WaitingConfirmBadge,
                            customBackgroundColor:
                                colors.confidenceAmberSurface,
                            customForegroundColor: colors.confidenceAmber,
                          )
                        else
                          const AppChip(label: AppStrings.man06UnpaidBadge),
                      ],
                    ),
                    if (isMine &&
                        !isHost &&
                        !share.participantMarkedPaid &&
                        !share.hostConfirmedPaid) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: AppStrings.man06MarkPaidBtn,
                        variant: AppButtonVariant.secondary,
                        isExpanded: true,
                        onPressed: () => _markPaid(share.id),
                      ),
                    ],
                    if (isHost &&
                        share.participant.id != session.host.id &&
                        !share.hostConfirmedPaid) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: AppStrings.man06ConfirmPaidBtn,
                        isExpanded: true,
                        onPressed: () => _confirmReceived(share.id),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.man06Title)),
      body: SafeArea(child: body),
    );
  }
}
