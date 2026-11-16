import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/domain/models/models.dart';

/// State untuk daftar percakapan (`PSN-01`) dan jumlah permintaan (`PSN-02`).
final class ConversationsListState {
  const ConversationsListState({
    this.conversations = const <Conversation>[],
    this.requests = const <MessageRequest>[],
    this.isLoading = true,
    this.error,
  });

  final List<Conversation> conversations;
  final List<MessageRequest> requests;
  final bool isLoading;
  final AppError? error;

  int get pendingRequestsCount => requests.length;

  ConversationsListState copyWith({
    List<Conversation>? conversations,
    List<MessageRequest>? requests,
    bool? isLoading,
    AppError? error,
    bool clearError = false,
  }) {
    return ConversationsListState(
      conversations: conversations ?? this.conversations,
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller live berbasis Stream untuk `PSN-01` dan `PSN-02`.
class ConversationsListController extends Notifier<ConversationsListState> {
  StreamSubscription<List<Conversation>>? _convSub;

  @override
  ConversationsListState build() {
    final chatRepo = ref.watch(chatRepositoryProvider);
    _convSub?.cancel();
    _convSub = chatRepo.watchConversations().listen((updated) {
      state = state.copyWith(conversations: updated);
      refreshRequestsOnly();
    });
    ref.onDispose(() {
      _convSub?.cancel();
      _convSub = null;
    });

    Future<void>.microtask(loadInitial);
    return const ConversationsListState(isLoading: true);
  }

  Future<void> loadInitial() async {
    final chatRepo = ref.read(chatRepositoryProvider);
    state = state.copyWith(isLoading: true, clearError: true);

    final convRes = await chatRepo.getConversations();
    final reqRes = await chatRepo.getMessageRequests();

    if (convRes is Err<List<Conversation>>) {
      state = state.copyWith(isLoading: false, error: convRes.failure);
      return;
    }

    state = state.copyWith(
      isLoading: false,
      conversations: (convRes as Ok<List<Conversation>>).value,
      requests: reqRes is Ok<List<MessageRequest>>
          ? reqRes.value
          : const <MessageRequest>[],
      clearError: true,
    );
  }

  Future<void> refreshRequestsOnly() async {
    final reqRes = await ref.read(chatRepositoryProvider).getMessageRequests();
    if (reqRes is Ok<List<MessageRequest>>) {
      state = state.copyWith(requests: reqRes.value);
    }
  }
}

final conversationsListProvider =
    NotifierProvider<ConversationsListController, ConversationsListState>(
      ConversationsListController.new,
    );

/// Helper pemformat waktu ringkas modul Pesan.
abstract final class ChatFormatters {
  static String formatShortTime(DateTime dt, DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) {
      return '${two(dt.hour)}:${two(dt.minute)}';
    }
    return '${two(dt.day)}/${two(dt.month)}';
  }
}
