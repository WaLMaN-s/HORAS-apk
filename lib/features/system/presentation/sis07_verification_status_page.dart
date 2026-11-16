import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// SIS-07 Status Verifikasi Komunitas (`SIS-R6`).
class Sis07VerificationStatusPage extends ConsumerStatefulWidget {
  const Sis07VerificationStatusPage({super.key});

  @override
  ConsumerState<Sis07VerificationStatusPage> createState() =>
      _Sis07VerificationStatusPageState();
}

class _Sis07VerificationStatusPageState
    extends ConsumerState<Sis07VerificationStatusPage> {
  List<VerificationRequest> _requests = const <VerificationRequest>[];
  bool _isLoading = true;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final res = await ref
        .read(verificationRepositoryProvider)
        .getMyVerificationRequests();
    if (!mounted) return;
    if (res is Err<List<VerificationRequest>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }
    setState(() {
      _requests = (res as Ok<List<VerificationRequest>>).value;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    Widget body;
    if (_isLoading) {
      body = const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _load);
    } else if (_requests.isEmpty) {
      body = StateView.empty(
        message: AppStrings.sis07EmptyRequests,
        actionLabel: AppStrings.actionRetry,
        onAction: _load,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _requests.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final req = _requests[index];
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            req.communityName,
                            style: typo.bodyStrong,
                          ),
                        ),
                        AppChip(
                          label: req.status.label,
                          isSelected: req.status == VerificationStatus.approved,
                          customBackgroundColor:
                              req.status == VerificationStatus.rejected
                              ? colors.danger.withValues(alpha: 0.12)
                              : null,
                          customForegroundColor:
                              req.status == VerificationStatus.rejected
                              ? colors.danger
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(req.evidenceDescription, style: typo.body),
                    if (req.rejectionReason != null &&
                        req.rejectionReason!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        AppStrings.sis07RejectionReason(req.rejectionReason!),
                        style: typo.caption.copyWith(color: colors.danger),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sis07Title)),
      body: SafeArea(child: body),
    );
  }
}
