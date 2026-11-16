import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:material_ui/material_ui.dart';

/// TAR-06 Cek Partuturan (`TAR-R9`): pilih dua orang ATAU input manual dua marga.
///
/// Seluruh hasil pada mode pengecekan ini berlabel [AppStrings.termPerkiraan].
class Tar06CheckPartuturanPage extends ConsumerStatefulWidget {
  const Tar06CheckPartuturanPage({super.key});

  @override
  ConsumerState<Tar06CheckPartuturanPage> createState() =>
      _Tar06CheckPartuturanPageState();
}

class _Tar06CheckPartuturanPageState
    extends ConsumerState<Tar06CheckPartuturanPage> {
  bool _loadingCandidates = true;
  bool _calculating = false;
  AppError? _error;

  List<PersonSummary> _people = const <PersonSummary>[];
  String? _personAId;
  String? _personBId;

  // Input Manual
  final TextEditingController _margaACtrl = TextEditingController(
    text: 'Simanjuntak',
  );
  final TextEditingController _motherMargaACtrl = TextEditingController(
    text: 'Sitorus',
  );
  final TextEditingController _margaBCtrl = TextEditingController(
    text: 'Sitorus',
  );
  SubEthnic _manualSubEthnic = SubEthnic.toba;
  UserGender _genderA = UserGender.male;
  UserGender _genderB = UserGender.male;
  int? _manualGenDelta = 1;

  PartuturanResult? _result;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadCandidates);
  }

  @override
  void dispose() {
    _margaACtrl.dispose();
    _motherMargaACtrl.dispose();
    _margaBCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    setState(() {
      _loadingCandidates = true;
      _error = null;
    });

    final meRes = await ref.read(profileRepositoryProvider).getMyProfile();
    final peopleRes = await ref
        .read(searchRepositoryProvider)
        .searchPeople(query: '');
    if (!mounted) return;

    if (peopleRes is Err<List<PersonSummary>>) {
      setState(() {
        _loadingCandidates = false;
        _error = peopleRes.failure;
      });
      return;
    }

    final list = (peopleRes as Ok<List<PersonSummary>>).value;
    final meId = meRes is Ok<Profil> ? meRes.value.id : null;
    setState(() {
      _loadingCandidates = false;
      _people = list;
      _personAId = meId ?? (list.isNotEmpty ? list.first.id : null);
      _personBId = list
          .where((p) => p.id != _personAId)
          .map((p) => p.id)
          .firstOrNull;
    });
  }

  Future<void> _evaluateTwoPeople() async {
    if (_personAId == null || _personBId == null) return;
    setState(() {
      _calculating = true;
      _error = null;
    });
    final res = await ref
        .read(partuturanRepositoryProvider)
        .evaluateBetweenUsers(userAId: _personAId!, userBId: _personBId!);
    if (!mounted) return;
    setState(() => _calculating = false);

    if (res is Err<PartuturanResult>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    setState(() => _result = (res as Ok<PartuturanResult>).value);
  }

  Future<void> _evaluateManual() async {
    if (_margaACtrl.text.trim().isEmpty || _margaBCtrl.text.trim().isEmpty) {
      AppToast.show(
        context,
        message: 'Isi kedua marga terlebih dahulu.',
        variant: AppToastVariant.warning,
      );
      return;
    }
    setState(() {
      _calculating = true;
      _error = null;
    });

    final genInfo = _manualGenDelta == null
        ? const GenerationInfo.unknown()
        : GenerationInfo(
            source: GenerationSource.tahunLahir,
            delta: _manualGenDelta,
          );

    final res = await ref
        .read(partuturanRepositoryProvider)
        .evaluateManual(
          viewerMarga: _margaACtrl.text.trim(),
          viewerGender: _genderA,
          viewerMotherMarga: _motherMargaACtrl.text.trim().isEmpty
              ? null
              : _motherMargaACtrl.text.trim(),
          subEthnic: _manualSubEthnic,
          targetMarga: _margaBCtrl.text.trim(),
          targetGender: _genderB,
          generationInfo: genInfo,
        );
    if (!mounted) return;
    setState(() => _calculating = false);

    if (res is Err<PartuturanResult>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    setState(() => _result = (res as Ok<PartuturanResult>).value);
  }

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    final colors = context.colors;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.tar06Title),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: AppStrings.tar06TabPickTwoPeople),
              Tab(text: AppStrings.tar06TabManualInput),
            ],
          ),
        ),
        body: _loadingCandidates
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : _error != null
            ? StateView.fromError(_error!, onRetry: _loadCandidates)
            : Column(
                children: <Widget>[
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        // Tab 1: Pilih Dua Orang
                        ListView(
                          padding: const EdgeInsets.all(
                            AppSpacing.screenMargin,
                          ),
                          children: <Widget>[
                            Text(
                              AppStrings.tar06PersonALabel,
                              style: typo.bodyStrong,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            DropdownButtonFormField<String>(
                              initialValue: _personAId,
                              decoration: const InputDecoration(),
                              items: <DropdownMenuItem<String>>[
                                for (final p in _people)
                                  DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(
                                      '${p.displayName} (${p.marga})',
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _personAId = v),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              AppStrings.tar06PersonBLabel,
                              style: typo.bodyStrong,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            DropdownButtonFormField<String>(
                              initialValue: _personBId,
                              decoration: const InputDecoration(),
                              items: <DropdownMenuItem<String>>[
                                for (final p in _people)
                                  DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(
                                      '${p.displayName} (${p.marga})',
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _personBId = v),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            AppButton(
                              label: AppStrings.tar06CalculateBtn,
                              isLoading: _calculating,
                              onPressed: _evaluateTwoPeople,
                            ),
                          ],
                        ),

                        // Tab 2: Input Manual
                        ListView(
                          padding: const EdgeInsets.all(
                            AppSpacing.screenMargin,
                          ),
                          children: <Widget>[
                            Text(
                              AppStrings.tar06ManualSubEthnicLabel,
                              style: typo.bodyStrong,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            DropdownButtonFormField<SubEthnic>(
                              initialValue: _manualSubEthnic,
                              decoration: const InputDecoration(),
                              items: <DropdownMenuItem<SubEthnic>>[
                                for (final s in SubEthnic.values)
                                  DropdownMenuItem<SubEthnic>(
                                    value: s,
                                    child: Text(s.displayName),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _manualSubEthnic = v);
                                }
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              controller: _margaACtrl,
                              label: AppStrings.tar06ManualMargaALabel,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              controller: _motherMargaACtrl,
                              label: AppStrings.tar06ManualMotherMargaALabel,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SegmentedButton<UserGender>(
                              segments: <ButtonSegment<UserGender>>[
                                for (final g in UserGender.values)
                                  ButtonSegment<UserGender>(
                                    value: g,
                                    label: Text('A: ${g.label}'),
                                  ),
                              ],
                              selected: <UserGender>{_genderA},
                              onSelectionChanged: (sel) {
                                if (sel.isNotEmpty) {
                                  setState(() => _genderA = sel.first);
                                }
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              controller: _margaBCtrl,
                              label: AppStrings.tar06ManualMargaBLabel,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SegmentedButton<UserGender>(
                              segments: <ButtonSegment<UserGender>>[
                                for (final g in UserGender.values)
                                  ButtonSegment<UserGender>(
                                    value: g,
                                    label: Text('B: ${g.label}'),
                                  ),
                              ],
                              selected: <UserGender>{_genderB},
                              onSelectionChanged: (sel) {
                                if (sel.isNotEmpty) {
                                  setState(() => _genderB = sel.first);
                                }
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              AppStrings.tar06ManualGenDiffLabel,
                              style: typo.bodyStrong,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            DropdownButtonFormField<int?>(
                              initialValue: _manualGenDelta,
                              decoration: const InputDecoration(),
                              items: const <DropdownMenuItem<int?>>[
                                DropdownMenuItem<int?>(
                                  value: 2,
                                  child: Text(AppStrings.tar06GenAbove2),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 1,
                                  child: Text(AppStrings.tar06GenAbove1),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 0,
                                  child: Text(AppStrings.tar06GenSame),
                                ),
                                DropdownMenuItem<int?>(
                                  value: -1,
                                  child: Text(AppStrings.tar06GenBelow1),
                                ),
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(AppStrings.tar06GenUnknown),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _manualGenDelta = v),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            AppButton(
                              label: AppStrings.tar06CalculateBtn,
                              isLoading: _calculating,
                              onPressed: _evaluateManual,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_result != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(top: BorderSide(color: colors.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                AppStrings.tar06ResultHeader,
                                style: typo.h3,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.confidenceAmberSurface,
                                  borderRadius: AppRadius.pillRadius,
                                  border: Border.all(
                                    color: colors.confidenceAmber,
                                  ),
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
                          const SizedBox(height: AppSpacing.sm),
                          if (_result!.modeNetral)
                            Text(
                              AppStrings.sek04NeutralModeHint,
                              style: typo.caption,
                            )
                          else ...<Widget>[
                            PartuturanBadge(result: _result!),
                            if (_result!
                                .penjelasanJalur
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _result!.penjelasanJalur,
                                style: typo.caption,
                              ),
                            ],
                          ],
                          if (_result!.isSemarga) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            const SemargaLabel(showExplanation: false),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
