import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_router.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// SIS-01 Notifikasi Dalam Aplikasi (`SIS-R1`, PRD bagian 9).
class Sis01NotificationsPage extends ConsumerStatefulWidget {
  const Sis01NotificationsPage({super.key});

  @override
  ConsumerState<Sis01NotificationsPage> createState() =>
      _Sis01NotificationsPageState();
}

class _Sis01NotificationsPageState
    extends ConsumerState<Sis01NotificationsPage> {
  StreamSubscription<List<AppNotification>>? _sub;
  List<AppNotification> _items = const <AppNotification>[];
  bool _isLoading = true;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_init);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final repo = ref.read(notificationRepositoryProvider);
    final res = await repo.getNotifications();
    if (!mounted) return;
    if (res is Err<List<AppNotification>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }

    await _sub?.cancel();
    if (!mounted) return;
    _sub = repo.watchNotifications().listen((updated) {
      if (!mounted) return;
      setState(() => _items = updated);
    });

    setState(() {
      _items = (res as Ok<List<AppNotification>>).value;
      _isLoading = false;
    });
  }

  Future<void> _markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllAsRead();
    await _init();
  }

  Future<void> _openNotification(AppNotification item) async {
    await ref.read(notificationRepositoryProvider).markAsRead(item.id);
    if (!mounted) return;
    final route = normalizeHorasDeepLink(Uri.parse(item.deepLink));
    context.push(route).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(authRepositoryProvider).currentTime;
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 7));

    final today = _items
        .where((n) => !n.createdAt.isBefore(todayStart))
        .toList(growable: false);
    final thisWeek = _items
        .where(
          (n) =>
              n.createdAt.isBefore(todayStart) &&
              !n.createdAt.isBefore(weekStart),
        )
        .toList(growable: false);
    final earlier = _items
        .where((n) => n.createdAt.isBefore(weekStart))
        .toList(growable: false);

    Widget body;
    if (_isLoading) {
      body = const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _init);
    } else if (_items.isEmpty) {
      body = StateView.empty(
        message: AppStrings.sis01EmptyMessage,
        actionLabel: AppStrings.actionRetry,
        onAction: _init,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _init,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            if (today.isNotEmpty) ...<Widget>[
              const SectionHeader(title: AppStrings.sis01GroupToday),
              const SizedBox(height: AppSpacing.sm),
              ...today.map(
                (n) => _NotifCard(item: n, onTap: () => _openNotification(n)),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (thisWeek.isNotEmpty) ...<Widget>[
              const SectionHeader(title: AppStrings.sis01GroupThisWeek),
              const SizedBox(height: AppSpacing.sm),
              ...thisWeek.map(
                (n) => _NotifCard(item: n, onTap: () => _openNotification(n)),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (earlier.isNotEmpty) ...<Widget>[
              const SectionHeader(title: AppStrings.sis01GroupEarlier),
              const SizedBox(height: AppSpacing.sm),
              ...earlier.map(
                (n) => _NotifCard(item: n, onTap: () => _openNotification(n)),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.sis01Title),
        actions: <Widget>[
          if (_items.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllRead,
              child: const Text(AppStrings.sis01MarkAllReadBtn),
            ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: item.isRead
          ? colors.surface
          : colors.primary.withValues(alpha: 0.06),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          item.isRead
              ? Icons.notifications_none_rounded
              : Icons.notifications_active_rounded,
          color: item.isRead ? colors.textMuted : colors.primary,
        ),
        title: Text(item.title, style: typo.bodyStrong),
        subtitle: Text(
          item.body,
          style: typo.caption.copyWith(color: colors.textMuted),
        ),
        trailing: item.isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}
