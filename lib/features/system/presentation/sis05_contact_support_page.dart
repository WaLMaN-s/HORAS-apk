import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/messages/presentation/chat_thread_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// SIS-05 Hubungi Dukungan & Banding Sanksi 14 Hari (`SIS-R4`, `SIS-R5`).
class Sis05ContactSupportPage extends ConsumerStatefulWidget {
  const Sis05ContactSupportPage({this.initialCategory, super.key});

  final String? initialCategory;

  @override
  ConsumerState<Sis05ContactSupportPage> createState() =>
      _Sis05ContactSupportPageState();
}

class _Sis05ContactSupportPageState
    extends ConsumerState<Sis05ContactSupportPage> {
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  late String _category;
  String? _attachmentSeed;
  bool _isSubmitting = false;

  static const List<String> _categories = <String>[
    AppStrings.sis05CategoryGeneral,
    AppStrings.sis05CategoryIdentity,
    AppStrings.sis05CategoryAppeal,
  ];

  @override
  void initState() {
    super.initState();
    _category =
        (widget.initialCategory != null &&
            _categories.contains(widget.initialCategory))
        ? widget.initialCategory!
        : _categories.first;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final seed = await pickAndCompressChatPhoto(context);
    if (seed == null || !mounted) return;
    setState(() => _attachmentSeed = seed);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final authRepo = ref.read(authRepositoryProvider);
    final supportRepo = ref.read(supportRepositoryProvider);
    final reportRepo = ref.read(reportRepositoryProvider);
    final msg = _messageController.text.trim();

    if (_category == AppStrings.sis05CategoryAppeal) {
      final strikesRes = await reportRepo.getMyStrikes();
      final latestStrikeAt =
          (strikesRes is Ok<List<Strike>> && strikesRes.value.isNotEmpty)
          ? strikesRes.value.last.createdAt
          : authRepo.currentTime;
      final appealRes = await reportRepo.submitAppeal(
        sanctionCreatedAt: latestStrikeAt,
        reasonText: msg,
      );
      if (!mounted) return;
      if (appealRes is Err<Appeal>) {
        setState(() => _isSubmitting = false);
        AppToast.show(
          context,
          message: appealRes.failure.message,
          variant: AppToastVariant.error,
        );
        return;
      }
    }

    final res = await supportRepo.submitSupportTicket(
      category: _category,
      message: msg,
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      attachmentSeed: _attachmentSeed,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res is Err<void>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    AppToast.show(
      context,
      message: AppStrings.sis05SuccessToast,
      variant: AppToastVariant.success,
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sis05Title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Text(AppStrings.sis05CategoryLabel, style: context.typo.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _categories
                  .map(
                    (c) => AppChip(
                      label: c,
                      isSelected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _messageController,
              label: AppStrings.sis05MessageLabel,
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _emailController,
              label: AppStrings.sis05EmailLabel,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_attachmentSeed != null) ...<Widget>[
              PlaceholderImage(seed: _attachmentSeed!, width: 120, height: 90),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppButton(
              label: AppStrings.sis05AttachPhotoBtn,
              variant: AppButtonVariant.secondary,
              leadingIcon: Icons.attach_file_rounded,
              onPressed: _pickAttachment,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: AppStrings.sis05SubmitBtn,
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
