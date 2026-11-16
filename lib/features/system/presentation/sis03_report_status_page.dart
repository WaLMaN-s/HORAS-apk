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

/// SIS-03 Status Laporan Saya (`SIS-R3`, `AC-14`).
class Sis03ReportStatusPage extends ConsumerStatefulWidget {
  const Sis03ReportStatusPage({super.key});

  @override
  ConsumerState<Sis03ReportStatusPage> createState() =>
      _Sis03ReportStatusPageState();
}

class _Sis03ReportStatusPageState extends ConsumerState<Sis03ReportStatusPage> {
  List<Report> _reports = const <Report>[];
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
    final res = await ref.read(reportRepositoryProvider).getMyReports();
    if (!mounted) return;
    if (res is Err<List<Report>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }
    setState(() {
      _reports = (res as Ok<List<Report>>).value;
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
    } else if (_reports.isEmpty) {
      body = StateView.empty(
        message: AppStrings.sis03EmptyReports,
        actionLabel: AppStrings.actionRetry,
        onAction: _load,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _reports.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final rep = _reports[index];
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
                            '${rep.category.label} · ${rep.targetType.name}',
                            style: typo.bodyStrong,
                          ),
                        ),
                        AppChip(
                          label: rep.status.label,
                          isSelected: rep.status == ReportStatus.completed,
                          customBackgroundColor:
                              rep.status == ReportStatus.inReview
                              ? colors.confidenceAmberSurface
                              : null,
                          customForegroundColor:
                              rep.status == ReportStatus.inReview
                              ? colors.confidenceAmber
                              : null,
                        ),
                      ],
                    ),
                    if (rep.note.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(rep.note, style: typo.body),
                    ],
                    if (rep.outcome != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        rep.outcome!.label,
                        style: typo.captionStrong.copyWith(
                          color: colors.primary,
                        ),
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
      appBar: AppBar(title: const Text(AppStrings.sis03Title)),
      body: SafeArea(child: body),
    );
  }
}
