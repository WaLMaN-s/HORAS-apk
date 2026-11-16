import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

/// AKN-12 Kenalan Saya: tab Terhubung, Permintaan Masuk, Terkirim (`AKN-R9`, `SEK-R5`).
class Akn12ConnectionsPage extends ConsumerStatefulWidget {
  const Akn12ConnectionsPage({super.key});

  @override
  ConsumerState<Akn12ConnectionsPage> createState() =>
      _Akn12ConnectionsPageState();
}

class _Akn12ConnectionsPageState extends ConsumerState<Akn12ConnectionsPage> {
  List<Connection> _connected = const <Connection>[];
  List<ConnectionRequest> _incoming = const <ConnectionRequest>[];
  List<ConnectionRequest> _outgoing = const <ConnectionRequest>[];
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
    final repo = ref.read(connectionRepositoryProvider);
    final connRes = await repo.getConnections();
    if (!mounted) return;
    if (connRes is Err<List<Connection>>) {
      setState(() {
        _isLoading = false;
        _error = connRes.failure;
      });
      return;
    }
    final inRes = await repo.getIncomingRequests();
    final outRes = await repo.getOutgoingRequests();
    if (!mounted) return;

    setState(() {
      _connected = (connRes as Ok<List<Connection>>).value;
      _incoming = inRes is Ok<List<ConnectionRequest>>
          ? inRes.value
          : const <ConnectionRequest>[];
      _outgoing = outRes is Ok<List<ConnectionRequest>>
          ? outRes.value
          : const <ConnectionRequest>[];
      _isLoading = false;
    });
  }

  Future<void> _respond(String requestId, bool accept) async {
    await ref
        .read(connectionRepositoryProvider)
        .respondToConnectionRequest(requestId: requestId, accept: accept);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.akn12Title),
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(text: AppStrings.akn12TabConnected),
              Tab(text: AppStrings.akn12TabIncoming),
              Tab(text: AppStrings.akn12TabOutgoing),
            ],
          ),
        ),
        body: _isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : _error != null
            ? StateView.fromError(_error!, onRetry: _load)
            : TabBarView(
                children: <Widget>[
                  _ConnectedTab(items: _connected, onRefresh: _load),
                  _IncomingTab(
                    items: _incoming,
                    onRespond: _respond,
                    onRefresh: _load,
                  ),
                  _OutgoingTab(items: _outgoing, onRefresh: _load),
                ],
              ),
      ),
    );
  }
}

class _ConnectedTab extends StatelessWidget {
  const _ConnectedTab({required this.items, required this.onRefresh});

  final List<Connection> items;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return StateView.empty(
        message: AppStrings.akn12EmptyConnected,
        actionLabel: AppStrings.actionExploreNearby,
        onAction: () => context.go(AppPages.sek01.routePath),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (ctx, index) {
          final friend = items[index].friend;
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () => context
                  .push('${AppPages.sek04.routePath}?userId=${friend.id}')
                  .ignore(),
              leading: AppAvatar(
                name: friend.displayName,
                seed: friend.avatarSeed,
              ),
              title: Text(
                '${friend.displayName} · ${friend.marga}',
                style: context.typo.bodyStrong,
              ),
              subtitle: Text(
                friend.city,
                style: context.typo.caption.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          );
        },
      ),
    );
  }
}

class _IncomingTab extends StatelessWidget {
  const _IncomingTab({
    required this.items,
    required this.onRespond,
    required this.onRefresh,
  });

  final List<ConnectionRequest> items;
  final Future<void> Function(String requestId, bool accept) onRespond;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return StateView.empty(
        message: AppStrings.akn12EmptyIncoming,
        actionLabel: AppStrings.actionRetry,
        onAction: onRefresh,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (ctx, index) {
          final req = items[index];
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${req.sender.displayName} · ${req.sender.marga}',
                    style: context.typo.bodyStrong,
                  ),
                  if (req.introMessage.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(req.introMessage, style: context.typo.body),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AppButton(
                          label: AppStrings.man05ApproveBtn,
                          onPressed: () => onRespond(req.id, true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          label: AppStrings.man05RejectBtn,
                          variant: AppButtonVariant.secondary,
                          isDestructive: true,
                          onPressed: () => onRespond(req.id, false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OutgoingTab extends StatelessWidget {
  const _OutgoingTab({required this.items, required this.onRefresh});

  final List<ConnectionRequest> items;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return StateView.empty(
        message: AppStrings.akn12EmptyOutgoing,
        actionLabel: AppStrings.actionExploreNearby,
        onAction: () => context.go(AppPages.sek01.routePath),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (ctx, index) {
          final req = items[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: AppAvatar(
                name: req.receiver.displayName,
                seed: req.receiver.avatarSeed,
              ),
              title: Text(
                '${req.receiver.displayName} · ${req.receiver.marga}',
                style: context.typo.bodyStrong,
              ),
              subtitle: Text(
                req.introMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typo.caption,
              ),
            ),
          );
        },
      ),
    );
  }
}
