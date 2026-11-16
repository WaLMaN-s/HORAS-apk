import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:material_ui/material_ui.dart';

/// Controller fondasi modul Pesan (PSN-01 .. PSN-06).
final messagesModulePagesProvider = Provider<AppModule>(
  (ref) => AppModule.messages,
);

/// Entrypoint halaman modul Pesan (tahap fondasi memakai [SegeraPage]).
class MessagesModulePlaceholderPage extends StatelessWidget {
  const MessagesModulePlaceholderPage({required this.pageSpec, super.key});

  final PageSpec pageSpec;

  @override
  Widget build(BuildContext context) {
    return SegeraPage(pageSpec: pageSpec);
  }
}
