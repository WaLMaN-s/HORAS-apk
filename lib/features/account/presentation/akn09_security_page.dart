import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/play/presentation/play_models.dart';
import 'package:material_ui/material_ui.dart';

/// AKN-09 Keamanan: perangkat aktif (maks 3), ganti nomor (dual OTP), riwayat masuk 30 hari (`AKN-R4`).
class Akn09SecurityPage extends ConsumerStatefulWidget {
  const Akn09SecurityPage({super.key});

  @override
  ConsumerState<Akn09SecurityPage> createState() => _Akn09SecurityPageState();
}

class _Akn09SecurityPageState extends ConsumerState<Akn09SecurityPage> {
  final _oldPhoneCtrl = TextEditingController();
  final _oldOtpCtrl = TextEditingController();
  final _newPhoneCtrl = TextEditingController();
  final _newOtpCtrl = TextEditingController();

  List<Device> _devices = const <Device>[];
  List<LoginHistoryEntry> _history = const <LoginHistoryEntry>[];
  bool _isLoading = true;
  bool _isChangingPhone = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _oldPhoneCtrl.dispose();
    _oldOtpCtrl.dispose();
    _newPhoneCtrl.dispose();
    _newOtpCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final authRepo = ref.read(authRepositoryProvider);
    final devRes = await authRepo.getActiveDevices();
    final histRes = await authRepo.getLoginHistory30Days();
    if (!mounted) return;
    _oldPhoneCtrl.text = authRepo.currentSessionProfile?.phoneE164 ?? '';
    setState(() {
      _devices = devRes is Ok<List<Device>> ? devRes.value : const <Device>[];
      _history = histRes is Ok<List<LoginHistoryEntry>>
          ? histRes.value
          : const <LoginHistoryEntry>[];
      _isLoading = false;
    });
  }

  Future<void> _revokeDevice(String id) async {
    await ref.read(authRepositoryProvider).revokeDevice(id);
    await _load();
  }

  Future<void> _changePhone() async {
    FocusScope.of(context).unfocus();
    setState(() => _isChangingPhone = true);
    final res = await ref
        .read(authRepositoryProvider)
        .changePhoneWithDualOtp(
          oldPhoneE164: _oldPhoneCtrl.text.trim(),
          oldOtpCode: _oldOtpCtrl.text.trim(),
          newPhoneE164: _newPhoneCtrl.text.trim(),
          newOtpCode: _newOtpCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _isChangingPhone = false);
    if (res is Err<void>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    _oldOtpCtrl.clear();
    _newOtpCtrl.clear();
    AppToast.show(
      context,
      message: AppStrings.akn09ChangePhoneSuccessToast,
      variant: AppToastVariant.success,
    );
    await _load();
  }

  Future<void> _logout() async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.akn09LogoutBtn,
      message: AppStrings.akn09LogoutBtn,
      confirmLabel: AppStrings.akn09LogoutBtn,
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    await ref.read(authRepositoryProvider).logout();
    if (!mounted) return;
    context.go(AppPages.aut02.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.akn09Title)),
      body: SafeArea(
        child: _isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  const SectionHeader(
                    title: AppStrings.akn09ActiveDevicesSection,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ..._devices.map(
                    (dev) => Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: const Icon(Icons.devices_rounded),
                        title: Text(dev.deviceName, style: typo.bodyStrong),
                        subtitle: Text(
                          '${dev.platform} · ${PlayFormatters.formatClockTime(dev.lastActiveAt)}',
                          style: typo.caption.copyWith(color: colors.textMuted),
                        ),
                        trailing: dev.isCurrent
                            ? const AppChip(
                                label: AppStrings.akn09CurrentDeviceBadge,
                                isSelected: true,
                              )
                            : TextButton(
                                onPressed: () => _revokeDevice(dev.id),
                                child: const Text(
                                  AppStrings.akn09RevokeDeviceBtn,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  const SectionHeader(
                    title: AppStrings.akn09ChangePhoneSection,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _oldPhoneCtrl,
                    label: AppStrings.akn09OldPhoneLabel,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _oldOtpCtrl,
                    label: AppStrings.akn09OldOtpLabel,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _newPhoneCtrl,
                    label: AppStrings.akn09NewPhoneLabel,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _newOtpCtrl,
                    label: AppStrings.akn09NewOtpLabel,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: AppStrings.akn09ChangePhoneBtn,
                    isExpanded: true,
                    isLoading: _isChangingPhone,
                    onPressed: _isChangingPhone ? null : _changePhone,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  const SectionHeader(
                    title: AppStrings.akn09LoginHistorySection,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ..._history.map(
                    (entry) => Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: const Icon(Icons.history_rounded),
                        title: Text(
                          '${entry.deviceName} (${entry.platform})',
                          style: typo.bodyStrong,
                        ),
                        subtitle: Text(
                          '${entry.city} · ${PlayFormatters.formatClockTime(entry.loggedInAt)}',
                          style: typo.caption.copyWith(color: colors.textMuted),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppButton(
                    label: AppStrings.akn09LogoutBtn,
                    variant: AppButtonVariant.secondary,
                    isDestructive: true,
                    isExpanded: true,
                    onPressed: _logout,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: AppStrings.akn14Title,
                    variant: AppButtonVariant.text,
                    isDestructive: true,
                    isExpanded: true,
                    onPressed: () =>
                        context.push(AppPages.akn14.routePath).ignore(),
                  ),
                ],
              ),
      ),
    );
  }
}
