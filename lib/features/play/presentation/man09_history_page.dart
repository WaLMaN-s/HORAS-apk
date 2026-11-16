import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/play/presentation/man01_play_page.dart';
import 'package:material_ui/material_ui.dart';

/// MAN-09 Riwayat Sesi (`Dibuat` dan `Diikuti`).
class Man09HistoryPage extends ConsumerStatefulWidget {
  const Man09HistoryPage({super.key});

  @override
  ConsumerState<Man09HistoryPage> createState() => _Man09HistoryPageState();
}

class _Man09HistoryPageState extends ConsumerState<Man09HistoryPage> {
  List<PlaySession> _sessions = const <PlaySession>[];
  bool _isLoading = true;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final res = await ref.read(sessionRepositoryProvider).getMySessionHistory();
    if (!mounted) return;
    if (res is Err<List<PlaySession>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }
    setState(() {
      _sessions = (res as Ok<List<PlaySession>>).value;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.read(authRepositoryProvider).currentUserId ?? '';
    final created = _sessions
        .where((s) => s.host.id == currentUserId)
        .toList(growable: false);
    final joined = _sessions
        .where((s) => s.host.id != currentUserId)
        .toList(growable: false);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.man09Title),
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(text: AppStrings.man09TabCreated),
              Tab(text: AppStrings.man09TabJoined),
            ],
          ),
        ),
        body: _isLoading
            ? const StateView.loading(itemCount: 3)
            : _error != null
            ? StateView.fromError(_error!, onRetry: _load)
            : TabBarView(
                children: <Widget>[
                  _HistoryTabList(
                    sessions: created,
                    emptyMessage: AppStrings.man09EmptyCreated,
                    onRefresh: _load,
                  ),
                  _HistoryTabList(
                    sessions: joined,
                    emptyMessage: AppStrings.man09EmptyJoined,
                    onRefresh: _load,
                  ),
                ],
              ),
      ),
    );
  }
}

class _HistoryTabList extends StatelessWidget {
  const _HistoryTabList({
    required this.sessions,
    required this.emptyMessage,
    required this.onRefresh,
  });

  final List<PlaySession> sessions;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return StateView.empty(
        message: emptyMessage,
        actionLabel: AppStrings.actionRetry,
        onAction: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: sessions.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final session = sessions[index];
          return SessionSummaryCard(
            session: session,
            onTap: () => context
                .push('${AppPages.man04.routePath}?sessionId=${session.id}')
                .ignore(),
          );
        },
      ),
    );
  }
}
