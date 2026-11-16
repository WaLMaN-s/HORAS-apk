import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' hide Block;
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// AKN-11 Daftar Pengguna Diblokir & Buka Blokir (`AKN-R6`, `AC-11`).
class Akn11BlockedUsersPage extends ConsumerStatefulWidget {
  const Akn11BlockedUsersPage({super.key});

  @override
  ConsumerState<Akn11BlockedUsersPage> createState() =>
      _Akn11BlockedUsersPageState();
}

class _Akn11BlockedUsersPageState extends ConsumerState<Akn11BlockedUsersPage> {
  List<Block> _blocks = const <Block>[];
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
    final res = await ref.read(blockRepositoryProvider).getBlockedUsers();
    if (!mounted) return;
    if (res is Err<List<Block>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }
    setState(() {
      _blocks = (res as Ok<List<Block>>).value;
      _isLoading = false;
    });
  }

  Future<void> _unblock(Block item) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: AppStrings.akn11UnblockConfirmTitle,
      message: AppStrings.akn11UnblockConfirmBody,
      confirmLabel: AppStrings.akn11UnblockBtn,
    );
    if (confirmed != true || !mounted) return;
    await ref.read(blockRepositoryProvider).unblockUser(item.blockedUser.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _load);
    } else if (_blocks.isEmpty) {
      body = StateView.empty(
        message: AppStrings.akn11EmptyBlocked,
        actionLabel: AppStrings.semanticsBack,
        onAction: () => context.pop(),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _blocks.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (ctx, index) {
          final b = _blocks[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: AppAvatar(
                name: b.blockedUser.displayName,
                seed: b.blockedUser.avatarSeed,
              ),
              title: Text(
                '${b.blockedUser.displayName} · ${b.blockedUser.marga}',
                style: context.typo.bodyStrong,
              ),
              subtitle: Text(
                b.blockedUser.city,
                style: context.typo.caption.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
              trailing: TextButton(
                onPressed: () => _unblock(b),
                child: const Text(AppStrings.akn11UnblockBtn),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.akn11Title)),
      body: SafeArea(child: body),
    );
  }
}
