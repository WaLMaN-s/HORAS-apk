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
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// MAN-08 Detail & Usulkan Lapangan (`MAN-R10`).
class Man08CourtDetailPage extends ConsumerStatefulWidget {
  const Man08CourtDetailPage({
    super.key,
    this.courtId,
    this.proposeMode = false,
  });

  final String? courtId;
  final bool proposeMode;

  @override
  ConsumerState<Man08CourtDetailPage> createState() =>
      _Man08CourtDetailPageState();
}

class _Man08CourtDetailPageState extends ConsumerState<Man08CourtDetailPage> {
  // Detail state
  Court? _court;
  bool _isLoading = true;
  AppError? _error;

  // Propose state
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  late final TextEditingController _cityController;
  final _priceController = TextEditingController();
  final _hoursController = TextEditingController();
  final Set<SportType> _selectedSports = <SportType>{SportType.badminton};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(
      text: ref.read(playControllerProvider).selectedCity,
    );
    if (widget.proposeMode || (widget.courtId?.isEmpty ?? true)) {
      _isLoading = false;
    } else {
      Future<void>.microtask(_loadCourt);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _priceController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _loadCourt() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final res = await ref
        .read(courtRepositoryProvider)
        .getCourtById(widget.courtId!);
    if (!mounted) return;
    if (res is Err<Court>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }
    setState(() {
      _court = (res as Ok<Court>).value;
      _isLoading = false;
    });
  }

  Future<void> _openExternalMap(Court court) async {
    final query = Uri.encodeComponent(
      '${court.name}, ${court.address}, ${court.city}',
    );
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      AppToast.show(
        context,
        message: AppStrings.man08MapLaunchError,
        variant: AppToastVariant.warning,
      );
    }
  }

  Future<void> _reportWrongInfo(Court court) async {
    final noteController = TextEditingController();
    final submit = await AppBottomSheet.show<bool>(
      context,
      title: AppStrings.man08ReportWrongInfoTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextField(
            controller: noteController,
            label: AppStrings.man08ReportWrongInfoTitle,
            hintText: AppStrings.man08ReportWrongInfoHint,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: AppStrings.actionConfirm,
            isExpanded: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (submit != true || !mounted) return;

    final res = await ref
        .read(reportRepositoryProvider)
        .submitReport(
          targetType: ReportTargetType.court,
          targetId: court.id,
          category: ReportCategory.other,
          note: note,
        );
    if (!mounted) return;
    if (res is Err<Report>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    AppToast.show(
      context,
      message: AppStrings.man08ReportWrongInfoSuccess,
      variant: AppToastVariant.success,
    );
    await _loadCourt();
  }

  Future<void> _submitProposal() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    final res = await ref
        .read(courtRepositoryProvider)
        .proposeCourt(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          supportedSports: _selectedSports.toList(growable: false),
          estimatedPriceText: _priceController.text.trim(),
          openingHours: _hoursController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (res is Err<Court>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    AppToast.show(
      context,
      message: AppStrings.man08ProposedToast,
      variant: AppToastVariant.success,
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    if (widget.proposeMode || (widget.courtId?.isEmpty ?? true)) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.man08ProposeTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              AppTextField(
                controller: _nameController,
                label: AppStrings.man08CourtNameLabel,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _addressController,
                label: AppStrings.man08CourtAddressLabel,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _cityController,
                label: AppStrings.man08CityLabel,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.man08SupportedSportsLabel,
                style: typo.bodyStrong,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: SportType.values
                    .map(
                      (sport) => AppChip(
                        label: sport.label,
                        isSelected: _selectedSports.contains(sport),
                        onTap: () => setState(() {
                          if (_selectedSports.contains(sport)) {
                            _selectedSports.remove(sport);
                          } else {
                            _selectedSports.add(sport);
                          }
                        }),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _priceController,
                label: AppStrings.man08CourtPriceLabel,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _hoursController,
                label: AppStrings.man08CourtHoursLabel,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: AppStrings.man08SubmitProposeBtn,
                isExpanded: true,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submitProposal,
              ),
            ],
          ),
        ),
      );
    }

    Widget body;
    if (_isLoading) {
      body = const StateView.loading(itemCount: 3);
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _loadCourt);
    } else if (_court == null) {
      body = StateView.empty(
        message: AppStrings.stateEmptyDefaultTitle,
        actionLabel: AppStrings.semanticsBack,
        onAction: () => context.pop(),
      );
    } else {
      final court = _court!;
      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          PlaceholderImage(
            seed: court.imageSeed,
            width: double.infinity,
            height: 180,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(court.name, style: typo.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${court.address}, ${court.city}',
            style: typo.body.copyWith(color: colors.textMuted),
          ),
          if (court.status == CourtModerationStatus.flaggedForReview ||
              court.wrongInfoReportCount > 3) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: AppChip(
                label: AppStrings.man08FlaggedForReviewBadge,
                customBackgroundColor: colors.confidenceAmberSurface,
                customForegroundColor: colors.confidenceAmber,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: court.supportedSports
                .map((s) => AppChip(label: s.label, isSelected: true))
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${AppStrings.man08EstimatedPricePrefix} (${AppStrings.termPerkiraan}): ${court.estimatedPriceText}',
                    style: typo.bodyStrong,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${AppStrings.man08OpeningHoursLabel}: ${court.openingHours}',
                    style: typo.body,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: AppStrings.man08OpenMapsBtn,
            isExpanded: true,
            leadingIcon: Icons.map_outlined,
            onPressed: () => _openExternalMap(court),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: AppStrings.man08ReportWrongInfoBtn,
            variant: AppButtonVariant.secondary,
            isDestructive: true,
            isExpanded: true,
            leadingIcon: Icons.flag_outlined,
            onPressed: () => _reportWrongInfo(court),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.man08Title)),
      body: SafeArea(child: body),
    );
  }
}
