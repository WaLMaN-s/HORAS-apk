import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:material_ui/material_ui.dart';

/// Controller fondasi modul Autentikasi (AUT-01 .. AUT-07).
final authModulePagesProvider = Provider<AppModule>((ref) => AppModule.auth);

/// Entrypoint halaman modul Autentikasi (tahap fondasi memakai [SegeraPage]).
class AuthModulePlaceholderPage extends StatelessWidget {
  const AuthModulePlaceholderPage({required this.pageSpec, super.key});

  final PageSpec pageSpec;

  @override
  Widget build(BuildContext context) {
    return SegeraPage(pageSpec: pageSpec);
  }
}
