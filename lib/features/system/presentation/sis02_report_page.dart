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
import 'package:horas/domain/policies/app_limits.dart';
import 'package:material_ui/material_ui.dart';

/// SIS-02 Laporkan (`SIS-R2`, `AC-14`, Alur A7).
///
/// Satu halaman terpadu untuk semua target: pengguna, postingan, komentar, pesan,
/// komunitas, sesi, lapangan, dan gereja (bila flag aktif).
class Sis02ReportPage extends ConsumerStatefulWidget {
  const Sis02ReportPage({
    required this.targetType,
    required this.targetId,
    this.targetUserId,
    super.key,
  });

  final ReportTargetType targetType;
  final String targetId;
  final String? targetUserId;

  @override
  ConsumerState<Sis02ReportPage> createState() => _Sis02ReportPageState();
}

class _Sis02ReportPageState extends ConsumerState<Sis02ReportPage> {
  final _noteController = TextEditingController();
  late ReportTargetType _selectedType;
  ReportCategory _category = ReportCategory.spamScam;
  bool _alsoBlock = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.targetType;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final reportRepo = ref.read(reportRepositoryProvider);
    final res = await reportRepo.submitReport(
      targetType: _selectedType,
      targetId: widget.targetId.isEmpty ? 'general-target' : widget.targetId,
      category: _category,
      note: _noteController.text.trim(),
    );
    if (!mounted) return;

    if (res is Err<Report>) {
      setState(() => _isSubmitting = false);
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }

    final blockUserId =
        widget.targetUserId ??
        (_selectedType == ReportTargetType.user ? widget.targetId : null);
    if (_alsoBlock &&
        blockUserId != null &&
        blockUserId.isNotEmpty &&
        blockUserId != ref.read(authRepositoryProvider).currentUserId) {
      await ref.read(blockRepositoryProvider).blockUser(blockUserId);
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    AppToast.show(
      context,
      message: AppStrings.sis02SuccessToast,
      variant: AppToastVariant.success,
    );
    context.pushReplacement(AppPages.sis03.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;
    final allowedTargets = ReportTargetType.values
        .where((t) => t != ReportTargetType.church || flags.church)
        .toList(growable: false);
    final blockUserId =
        widget.targetUserId ??
        (_selectedType == ReportTargetType.user ? widget.targetId : null);
    final canAlsoBlock =
        blockUserId != null &&
        blockUserId.isNotEmpty &&
        blockUserId != ref.read(authRepositoryProvider).currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sis02Title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.chipInactive,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Text(
                AppStrings.sis02ReporterPrivacyNote,
                style: typo.caption.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (widget.targetId.isEmpty) ...<Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: allowedTargets
                    .map(
                      (t) => AppChip(
                        label: t.name,
                        isSelected: _selectedType == t,
                        onTap: () => setState(() => _selectedType = t),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            Text(AppStrings.sis02CategoryLabel, style: typo.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: ReportCategory.values
                  .map(
                    (c) => AppChip(
                      label: c.label,
                      isSelected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _noteController,
              label: AppStrings.sis02NoteLabel,
              maxLines: 4,
              maxLength: AppLimits.reportNoteMaxChars,
            ),
            if (canAlsoBlock) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              SwitchListTile.adaptive(
                value: _alsoBlock,
                onChanged: (v) => setState(() => _alsoBlock = v),
                title: const Text(AppStrings.sis02AlsoBlockLabel),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: AppStrings.sis02SubmitBtn,
              isExpanded: true,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
