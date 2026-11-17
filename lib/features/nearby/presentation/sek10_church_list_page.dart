import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-10 Daftar Gereja (SEK-R13).
///
/// - Filter denominasi (HKBP, GKPI, HKI, GKPS, GBKP, lainnya).
/// - Jadwal ibadah, kontak, kegiatan.
/// - Jumlah jemaat di HORAS hanya tampil bila minimal 5 orang (SEK-R13).
/// - Lencana Terverifikasi vs Belum diverifikasi.
/// - Formulir usulkan gereja.
/// - Memiliki status memuat, kosong, offline, error.
class Sek10ChurchListPage extends ConsumerStatefulWidget {
  const Sek10ChurchListPage({super.key});

  @override
  ConsumerState<Sek10ChurchListPage> createState() =>
      _Sek10ChurchListPageState();
}

class _Sek10ChurchListPageState extends ConsumerState<Sek10ChurchListPage> {
  final _searchController = TextEditingController();
  ChurchDenomination? _selectedDenomination;
  bool _isLoading = true;
  AppError? _error;
  List<Church> _churches = const <Church>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final churchRepo = ref.read(churchRepositoryProvider);
    final res = await churchRepo.getChurches(
      denomination: _selectedDenomination,
      query: _searchController.text.trim(),
    );

    if (!mounted) return;
    if (res is Err<List<Church>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }

    setState(() {
      _churches = (res as Ok<List<Church>>).value;
      _isLoading = false;
    });
  }

  void _showProposeChurchSheet() {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Medan');
    final phoneCtrl = TextEditingController();
    ChurchDenomination denom = ChurchDenomination.hkbp;
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  bottom:
                      MediaQuery.of(sheetContext).viewInsets.bottom +
                      AppSpacing.lg,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppStrings.sek10ProposeChurchTitle,
                        style: sheetContext.typo.h3,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: nameCtrl,
                        label: 'Nama Gereja Lengkap',
                        hintText: 'Misal: HKBP Sudirman Medan',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<ChurchDenomination>(
                        initialValue: denom,
                        decoration: const InputDecoration(
                          labelText: 'Denominasi Gereja',
                          border: OutlineInputBorder(),
                        ),
                        items: ChurchDenomination.values.map((d) {
                          return DropdownMenuItem<ChurchDenomination>(
                            value: d,
                            child: Text(d.label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => denom = val);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: addrCtrl,
                        label: 'Alamat Lengkap',
                        hintText: 'Jalan, nomor, kelurahan',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: cityCtrl,
                        label: 'Kota / Kabupaten',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: phoneCtrl,
                        label: 'Kontak Gereja / Sekretariat (Opsional)',
                        hintText: '+62...',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Kirim Usulan Gereja',
                        variant: AppButtonVariant.primary,
                        isExpanded: true,
                        isLoading: isSubmitting,
                        onPressed: () async {
                          final cleanName = nameCtrl.text.trim();
                          final cleanAddr = addrCtrl.text.trim();
                          final cleanCity = cityCtrl.text.trim();
                          if (cleanName.isEmpty ||
                              cleanAddr.isEmpty ||
                              cleanCity.isEmpty) {
                            AppToast.show(
                              sheetContext,
                              message:
                                  'Nama, alamat, dan kota gereja wajib diisi.',
                              variant: AppToastVariant.error,
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          final res = await ref
                              .read(churchRepositoryProvider)
                              .proposeChurch(
                                name: cleanName,
                                denomination: denom,
                                address: cleanAddr,
                                city: cleanCity,
                                contactPhone: phoneCtrl.text.trim(),
                                serviceSchedules: const <ChurchServiceSchedule>[
                                  ChurchServiceSchedule(
                                    dayOfWeek: 'Minggu',
                                    time: '09.00 WIB',
                                    language: 'Bahasa Indonesia',
                                  ),
                                ],
                              );

                          if (!sheetContext.mounted) return;
                          setModalState(() => isSubmitting = false);

                          if (res is Ok<Church>) {
                            sheetContext.pop();
                            if (mounted) {
                              AppToast.show(
                                context,
                                message: 'Usulan gereja berhasil dikirim dan masuk antrean moderasi.',
                                variant: AppToastVariant.success,
                              );
                              await _load();
                            }
                          } else if (res is Err<Church>) {
                            AppToast.show(
                              sheetContext,
                              message: res.failure.message,
                              variant: AppToastVariant.error,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;

    if (!flags.church) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sek10Title)),
        body: StateView.contentUnavailable(
          onBack: () => context.go(AppPages.sekitarPath),
        ),
      );
    }

    Widget content;
    if (_isLoading) {
      content = const SingleChildScrollView(
        child: StateView.loading(itemCount: 4),
      );
    } else if (_error != null) {
      content = StateView.fromError(_error!, onRetry: _load);
    } else if (_churches.isEmpty) {
      content = StateView.empty(
        message: AppStrings.sek10EmptyChurches,
        actionLabel: AppStrings.sek10ProposeChurchBtn,
        onAction: _showProposeChurchSheet,
      );
    } else {
      content = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _churches.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, idx) {
            final church = _churches[idx];
            return InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () =>
                  context.push('${AppPages.sek11.routePath}?id=${church.id}'),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.6),
                  ),
                  boxShadow: AppShadows.softCard(colors.shadow),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.chipInactive,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.church_outlined,
                        color: colors.primary,
                        size: AppSizes.iconMd,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  church.name,
                                  style: typo.bodyStrong,
                                ),
                              ),
                              if (church.isVerified)
                                const Icon(
                                  Icons.verified,
                                  color: Colors.blue,
                                  size: AppSizes.iconSm,
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${church.denomination.label} · ${church.city}',
                            style: typo.caption.copyWith(color: colors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            church.address,
                            style: typo.micro.copyWith(color: colors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // SEK-R13: Jumlah jemaat hanya tampil bila minimal 5 orang
                          if (church.canDisplayMemberCount)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.chipInactive,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                AppStrings.sek10MemberCountFormat(
                                  church.memberCount,
                                ),
                                style: typo.micro.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.sek10Title),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.sek10ProposeChurchBtn,
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: _showProposeChurchSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Bilah Pencarian
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: AppTextField(
                controller: _searchController,
                hintText: AppStrings.sek10SearchHint,
                leadingIcon: Icons.search,
                onSubmitted: (_) => _load(),
              ),
            ),
            // Chip Filter Denominasi
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  FilterChip(
                    label: const Text(AppStrings.sek10DenominationAll),
                    selected: _selectedDenomination == null,
                    onSelected: (selected) {
                      setState(() => _selectedDenomination = null);
                      _load();
                    },
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ...ChurchDenomination.values.map((d) {
                    final isSel = _selectedDenomination == d;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: FilterChip(
                        label: Text(d.label),
                        selected: isSel,
                        onSelected: (selected) {
                          setState(() {
                            _selectedDenomination = selected ? d : null;
                          });
                          _load();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
