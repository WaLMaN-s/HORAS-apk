import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// AKN-13 Data Saya: unduh arsip profil, postingan, tarombo (ZIP/JSON, `AKN-R7`).
class Akn13DataExportPage extends ConsumerStatefulWidget {
  const Akn13DataExportPage({super.key});

  @override
  ConsumerState<Akn13DataExportPage> createState() =>
      _Akn13DataExportPageState();
}

class _Akn13DataExportPageState extends ConsumerState<Akn13DataExportPage> {
  final _otpController = TextEditingController();
  DataExportJob? _latestJob;
  List<int>? _zipBytes;
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ref
        .read(accountLifecycleRepositoryProvider)
        .getLatestDataExportJob();
    if (!mounted) return;
    setState(() {
      if (res is Ok<DataExportJob?>) _latestJob = res.value;
      _isLoading = false;
    });
  }

  Future<void> _requestAndGenerateZip() async {
    FocusScope.of(context).unfocus();
    setState(() => _isGenerating = true);
    final repo = ref.read(accountLifecycleRepositoryProvider);
    final res = await repo.requestDataExport(
      otpCode: _otpController.text.trim(),
    );
    if (!mounted) return;
    if (res is Err<DataExportJob>) {
      setState(() => _isGenerating = false);
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }

    final zipRes = await repo.buildExportZipBytes();
    if (!mounted) return;
    setState(() {
      _latestJob = (res as Ok<DataExportJob>).value;
      _zipBytes = zipRes is Ok<List<int>> ? zipRes.value : null;
      _isGenerating = false;
    });
    AppToast.show(
      context,
      message: AppStrings.akn13JobReadyStatus,
      variant: AppToastVariant.success,
    );
  }

  Future<void> _shareZip() async {
    final bytes = _zipBytes;
    if (bytes == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final uid = ref.read(authRepositoryProvider).currentUserId ?? 'user';
      final file = File('${dir.path}/horas-data-$uid.zip');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/zip')],
          text: AppStrings.akn13JobReadyStatus,
        ),
      );
    } on Object {
      if (mounted) {
        AppToast.show(
          context,
          message: AppStrings.akn13JobReadyStatus,
          variant: AppToastVariant.info,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.akn13Title)),
      body: SafeArea(
        child: _isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  Text(AppStrings.akn13InfoText, style: typo.body),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _otpController,
                    label: AppStrings.akn13OtpLabel,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: AppStrings.akn13RequestBtn,
                    isExpanded: true,
                    isLoading: _isGenerating,
                    onPressed: _isGenerating ? null : _requestAndGenerateZip,
                  ),
                  if (_latestJob != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _latestJob!.status == DataExportStatus.ready
                                  ? AppStrings.akn13JobReadyStatus
                                  : AppStrings.akn13JobProcessingStatus,
                              style: typo.bodyStrong.copyWith(
                                color: colors.primary,
                              ),
                            ),
                            if (_zipBytes != null) ...<Widget>[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Ukuran arsip ZIP: ${_zipBytes!.length} byte',
                                style: typo.caption.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppButton(
                                label: AppStrings.akn13ShareZipBtn,
                                variant: AppButtonVariant.secondary,
                                isExpanded: true,
                                leadingIcon: Icons.share_outlined,
                                onPressed: _shareZip,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
