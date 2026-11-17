import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/play/presentation/play_controller.dart';
import 'package:horas/features/play/presentation/play_models.dart';
import 'package:material_ui/material_ui.dart';

/// MAN-03 Buat Sesi Main (`MAN-R1`, `MAN-R2`, `MAN-R7`, `MAN-R8`, `MAN-R11`).
///
/// Sesi berulang adalah Fase 2 (`FeatureFlags.recurringSessions == false`) dan
/// sengaja tidak ditampilkan pada MVP.
class Man03CreateSessionPage extends ConsumerStatefulWidget {
  const Man03CreateSessionPage({super.key});

  @override
  ConsumerState<Man03CreateSessionPage> createState() =>
      _Man03CreateSessionPageState();
}

enum _VenueMode { court, manual }

class _Man03CreateSessionPageState
    extends ConsumerState<Man03CreateSessionPage> {
  final _titleController = TextEditingController();
  final _manualSummaryController = TextEditingController();
  final _manualDetailController = TextEditingController();
  final _slotsController = TextEditingController(text: '8');
  final _feeController = TextEditingController(text: '25000');
  final _notesController = TextEditingController();

  SportType _sportType = SportType.badminton;
  SkillLevel _skillLevel = SkillLevel.all;
  SessionVisibility _visibility = SessionVisibility.publicInArea;
  SessionJoinMode _joinMode = SessionJoinMode.instant;
  _VenueMode _venueMode = _VenueMode.court;
  bool _isRecurring = false;
  String _recurringInterval = AppStrings.man03RecurringIntervalWeekly;

  late String _selectedCity;
  late DateTime _selectedStart;
  int _durationHours = 2;

  List<WilayahCity> _cities = const <WilayahCity>[];
  List<Court> _courts = const <Court>[];
  String? _selectedCourtId;
  List<Community> _communities = const <Community>[];
  String? _selectedCommunityId;

  bool _isLoadingOptions = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    final now = ref.read(authRepositoryProvider).currentTime;
    _selectedCity = nearbyRepo.currentSelectedCity;
    _selectedStart = now.add(const Duration(hours: 2));
    Future<void>.microtask(_loadOptions);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _manualSummaryController.dispose();
    _manualDetailController.dispose();
    _slotsController.dispose();
    _feeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() => _isLoadingOptions = true);
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    final courtRepo = ref.read(courtRepositoryProvider);
    final communityRepo = ref.read(communityRepositoryProvider);

    final citiesRes = await nearbyRepo.getAvailableCities();
    final courtsRes = await courtRepo.getCourts(
      city: _selectedCity,
      sportType: _sportType,
    );
    final communitiesRes = await communityRepo.getCommunities();

    if (!mounted) return;
    final courts = courtsRes is Ok<List<Court>>
        ? courtsRes.value
              .where((c) => c.status != CourtModerationStatus.pendingModeration)
              .toList(growable: false)
        : const <Court>[];
    final communities = communitiesRes is Ok<List<Community>>
        ? communitiesRes.value
        : const <Community>[];

    setState(() {
      _cities = citiesRes is Ok<List<WilayahCity>>
          ? citiesRes.value
          : const <WilayahCity>[];
      _courts = courts;
      _selectedCourtId = courts.any((c) => c.id == _selectedCourtId)
          ? _selectedCourtId
          : (courts.isNotEmpty ? courts.first.id : null);
      if (courts.isEmpty && _venueMode == _VenueMode.court) {
        _venueMode = _VenueMode.manual;
      }
      _communities = communities;
      _selectedCommunityId =
          communities.any((c) => c.id == _selectedCommunityId)
          ? _selectedCommunityId
          : (communities.isNotEmpty ? communities.first.id : null);
      _isLoadingOptions = false;
    });
  }

  Future<void> _reloadCourtsForCityOrSport() async {
    final res = await ref
        .read(courtRepositoryProvider)
        .getCourts(city: _selectedCity, sportType: _sportType);
    if (!mounted) return;
    final courts = res is Ok<List<Court>>
        ? res.value
              .where((c) => c.status != CourtModerationStatus.pendingModeration)
              .toList(growable: false)
        : const <Court>[];
    setState(() {
      _courts = courts;
      _selectedCourtId = courts.any((c) => c.id == _selectedCourtId)
          ? _selectedCourtId
          : (courts.isNotEmpty ? courts.first.id : null);
    });
  }

  Future<void> _pickCustomDateTime() async {
    final now = ref.read(authRepositoryProvider).currentTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedStart,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedStart),
    );
    if (pickedTime == null || !mounted) return;
    setState(() {
      _selectedStart = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final slots = int.tryParse(_slotsController.text.trim()) ?? -1;
    final fee =
        int.tryParse(
          _feeController.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        -1;
    final endTime = _selectedStart.add(Duration(hours: _durationHours));

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final res = await ref
        .read(sessionRepositoryProvider)
        .createSession(
          sportType: _sportType,
          title: _titleController.text.trim(),
          city: _selectedCity,
          startTime: _selectedStart,
          endTime: endTime,
          maxSlots: slots,
          skillLevel: _skillLevel,
          feePerPersonRupiah: fee,
          visibility: _visibility,
          joinMode: _joinMode,
          courtId: _venueMode == _VenueMode.court ? _selectedCourtId : null,
          manualLocationSummary: _venueMode == _VenueMode.manual
              ? _manualSummaryController.text.trim()
              : null,
          manualLocationFullDetail: _venueMode == _VenueMode.manual
              ? _manualDetailController.text.trim()
              : null,
          notes: _notesController.text.trim(),
          communityId: _visibility == SessionVisibility.communityOnly
              ? _selectedCommunityId
              : null,
        );

    if (!mounted) return;

    if (res is Err<PlaySession>) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = res.failure.message;
      });
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }

    final created = (res as Ok<PlaySession>).value;
    final now = ref.read(authRepositoryProvider).currentTime;
    await ref
        .read(sessionReminderServiceProvider)
        .scheduleForSession(session: created, now: now);
    await ref.read(playControllerProvider.notifier).loadInitial();

    if (!mounted) return;
    AppToast.show(
      context,
      message: AppStrings.man03CreatedToast,
      variant: AppToastVariant.success,
    );
    context.pop(created.id);
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;
    final now = ref.read(authRepositoryProvider).currentTime;

    final start2h = now.add(const Duration(hours: 2));
    final tomorrow8 = DateTime(now.year, now.month, now.day + 1, 8, 0);
    final tomorrow19 = DateTime(now.year, now.month, now.day + 1, 19, 0);
    final next3Days = DateTime(now.year, now.month, now.day + 3, 17, 0);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.man03Title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            // MAN-R7: Larangan taruhan / judi + tempat umum / fasilitas olahraga (MAN-R8)
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
                    Icons.gpp_maybe_outlined,
                    color: colors.confidenceAmber,
                    size: AppSizes.iconMd,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      AppStrings.man03NoGamblingBanner,
                      style: typo.caption.copyWith(color: colors.text),
                    ),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.12),
                  borderRadius: AppRadius.cardRadius,
                ),
                child: Text(
                  _errorMessage!,
                  style: typo.caption.copyWith(color: colors.danger),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            Text(AppStrings.man02SportLabel, style: typo.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: SportType.values
                  .map(
                    (sport) => AppChip(
                      label: sport.label,
                      isSelected: _sportType == sport,
                      onTap: () {
                        setState(() => _sportType = sport);
                        _reloadCourtsForCityOrSport();
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _titleController,
              label: AppStrings.man03TitleLabel,
              hintText: AppStrings.man03TitleHint,
              maxLength: 80,
            ),
            const SizedBox(height: AppSpacing.md),

            Text(AppStrings.man03CityLabel, style: typo.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            if (_cities.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _cities.any((c) => c.name == _selectedCity)
                    ? _selectedCity
                    : _cities.first.name,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _cities
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c.name,
                        child: Text(c.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedCity = value);
                  _reloadCourtsForCityOrSport();
                },
              ),
            const SizedBox(height: AppSpacing.lg),

            Text(AppStrings.man03VenueModeLabel, style: typo.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                AppChip(
                  label: AppStrings.man03VenueModeCourt,
                  isSelected: _venueMode == _VenueMode.court,
                  onTap: () => setState(() => _venueMode = _VenueMode.court),
                ),
                AppChip(
                  label: AppStrings.man03VenueModeManual,
                  isSelected: _venueMode == _VenueMode.manual,
                  onTap: () => setState(() => _venueMode = _VenueMode.manual),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (_venueMode == _VenueMode.court) ...<Widget>[
              if (_isLoadingOptions)
                const SkeletonBox(height: 52, width: double.infinity)
              else if (_courts.isEmpty)
                Text(
                  AppStrings.man03NoCourtsInCityHint,
                  style: typo.caption.copyWith(color: colors.textMuted),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedCourtId,
                  decoration: const InputDecoration(
                    labelText: AppStrings.man03CourtSelectLabel,
                    border: OutlineInputBorder(),
                  ),
                  items: _courts
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _selectedCourtId = value),
                ),
            ] else ...<Widget>[
              AppTextField(
                controller: _manualSummaryController,
                label: AppStrings.man03ManualSummaryLabel,
                hintText: AppStrings.man03ManualSummaryHint,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _manualDetailController,
                label: AppStrings.man03ManualFullDetailLabel,
                maxLines: 2,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            Text(AppStrings.man03StartOffsetLabel, style: typo.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                AppChip(
                  label: AppStrings.man03StartTime2h,
                  isSelected:
                      _selectedStart.difference(start2h).inMinutes.abs() < 30,
                  onTap: () => setState(() => _selectedStart = start2h),
                ),
                AppChip(
                  label: AppStrings.man03StartTimeTomorrowMorning,
                  isSelected: _selectedStart == tomorrow8,
                  onTap: () => setState(() => _selectedStart = tomorrow8),
                ),
                AppChip(
                  label: AppStrings.man03StartTimeTomorrowNight,
                  isSelected: _selectedStart == tomorrow19,
                  onTap: () => setState(() => _selectedStart = tomorrow19),
                ),
                AppChip(
                  label: AppStrings.man03StartTimeNextWeek,
                  isSelected: _selectedStart == next3Days,
                  onTap: () => setState(() => _selectedStart = next3Days),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    PlayFormatters.formatTimeWindow(
                      _selectedStart,
                      _selectedStart.add(Duration(hours: _durationHours)),
                    ),
                    style: typo.caption.copyWith(color: colors.primary),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickCustomDateTime,
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: const Text(AppStrings.man03CustomTimeBtn),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            Text(AppStrings.man03DurationHoursLabel, style: typo.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: <int>[1, 2, 3, 4]
                  .map(
                    (hours) => AppChip(
                      label: '$hours jam',
                      isSelected: _durationHours == hours,
                      onTap: () => setState(() => _durationHours = hours),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    controller: _slotsController,
                    label: AppStrings.man03SlotsLabel,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: _feeController,
                    label: AppStrings.man03FeeLabel,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(AppStrings.man02LevelLabel, style: typo.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: SkillLevel.values
                  .map(
                    (level) => AppChip(
                      label: level.label,
                      isSelected: _skillLevel == level,
                      onTap: () => setState(() => _skillLevel = level),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(AppStrings.man03VisibilityLabel, style: typo.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                AppChip(
                  label: AppStrings.man03VisibilityPublic,
                  isSelected: _visibility == SessionVisibility.publicInArea,
                  onTap: () => setState(
                    () => _visibility = SessionVisibility.publicInArea,
                  ),
                ),
                AppChip(
                  label: AppStrings.man03VisibilityCommunity,
                  isSelected: _visibility == SessionVisibility.communityOnly,
                  onTap: () => setState(
                    () => _visibility = SessionVisibility.communityOnly,
                  ),
                ),
                AppChip(
                  label: AppStrings.man03VisibilityInviteOnly,
                  isSelected: _visibility == SessionVisibility.inviteOnly,
                  onTap: () => setState(
                    () => _visibility = SessionVisibility.inviteOnly,
                  ),
                ),
              ],
            ),
            if (_visibility == SessionVisibility.communityOnly) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              if (_communities.isEmpty)
                Text(
                  AppStrings.man03NoCommunitiesHint,
                  style: typo.caption.copyWith(color: colors.textMuted),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedCommunityId,
                  decoration: const InputDecoration(
                    labelText: AppStrings.man03CommunitySelectLabel,
                    border: OutlineInputBorder(),
                  ),
                  items: _communities
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _selectedCommunityId = value),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),

            Text(AppStrings.man03JoinModeLabel, style: typo.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                AppChip(
                  label: AppStrings.man03JoinModeInstant,
                  isSelected: _joinMode == SessionJoinMode.instant,
                  onTap: () =>
                      setState(() => _joinMode = SessionJoinMode.instant),
                ),
                AppChip(
                  label: AppStrings.man03JoinModeHostApproval,
                  isSelected: _joinMode == SessionJoinMode.hostApproval,
                  onTap: () =>
                      setState(() => _joinMode = SessionJoinMode.hostApproval),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            if (flags.recurringSessions) ...<Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  AppStrings.man03RecurringSwitch,
                  style: typo.bodyStrong,
                ),
                value: _isRecurring,
                onChanged: (val) => setState(() => _isRecurring = val),
              ),
              if (_isRecurring) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children:
                      <String>[
                            AppStrings.man03RecurringIntervalWeekly,
                            AppStrings.man03RecurringIntervalBiweekly,
                            AppStrings.man03RecurringIntervalMonthly,
                          ]
                          .map((interval) {
                            return ChoiceChip(
                              label: Text(interval),
                              selected: _recurringInterval == interval,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _recurringInterval = interval);
                                }
                              },
                            );
                          })
                          .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],

            AppTextField(
              controller: _notesController,
              label: AppStrings.man03NotesLabel,
              maxLines: 3,
              maxLength: 300,
            ),
            const SizedBox(height: AppSpacing.xl),

            AppButton(
              label: AppStrings.man03SubmitBtn,
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
