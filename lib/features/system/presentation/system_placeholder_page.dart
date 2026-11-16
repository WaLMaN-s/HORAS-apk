import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:material_ui/material_ui.dart';

/// Controller fondasi modul Sistem (SIS-01 .. SIS-08).
final systemModulePagesProvider = Provider<AppModule>(
  (ref) => AppModule.system,
);

/// Entrypoint halaman modul Sistem (tahap fondasi memakai [SegeraPage]).
class SystemModulePlaceholderPage extends StatelessWidget {
  const SystemModulePlaceholderPage({required this.pageSpec, super.key});

  final PageSpec pageSpec;

  @override
  Widget build(BuildContext context) {
    return SegeraPage(pageSpec: pageSpec);
  }
}
