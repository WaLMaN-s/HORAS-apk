import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:horas/features/messages/presentation/psn01_conversations_page.dart';
import 'package:horas/features/messages/presentation/psn02_message_requests_page.dart';
import 'package:horas/features/messages/presentation/psn03_private_chat_page.dart';
import 'package:horas/features/messages/presentation/psn04_group_chat_page.dart';
import 'package:horas/features/messages/presentation/psn05_conversation_info_page.dart';
import 'package:horas/features/messages/presentation/psn06_media_viewer_page.dart';
import 'package:material_ui/material_ui.dart';

/// Controller fondasi modul Pesan (PSN-01 .. PSN-06).
final messagesModulePagesProvider = Provider<AppModule>(
  (ref) => AppModule.messages,
);

/// Router halaman nyata modul Pesan (`PSN-01` .. `PSN-06`, Prompt 8).
class MessagesModulePageRouter extends StatelessWidget {
  const MessagesModulePageRouter({
    required this.pageSpec,
    required this.routerState,
    super.key,
    this.tabIndex,
  });

  final PageSpec pageSpec;
  final GoRouterState routerState;
  final int? tabIndex;

  @override
  Widget build(BuildContext context) {
    final query = routerState.uri.queryParameters;
    final conversationId = query['conversationId'] ?? query['id'] ?? '';

    if (pageSpec.id == AppPages.psn01.id) {
      return Psn01ConversationsPage(tabIndex: tabIndex);
    }
    if (pageSpec.id == AppPages.psn02.id) {
      return const Psn02MessageRequestsPage();
    }
    if (pageSpec.id == AppPages.psn03.id) {
      return Psn03PrivateChatPage(
        conversationId: conversationId.isEmpty ? null : conversationId,
        targetUserId: query['userId'],
      );
    }
    if (pageSpec.id == AppPages.psn04.id) {
      return Psn04GroupChatPage(conversationId: conversationId);
    }
    if (pageSpec.id == AppPages.psn05.id) {
      return Psn05ConversationInfoPage(conversationId: conversationId);
    }
    if (pageSpec.id == AppPages.psn06.id) {
      return Psn06MediaViewerPage(photoSeed: query['seed'] ?? '');
    }

    return SegeraPage(pageSpec: pageSpec);
  }
}
