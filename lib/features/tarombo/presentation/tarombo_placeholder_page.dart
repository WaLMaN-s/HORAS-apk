import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:material_ui/material_ui.dart';

/// Controller fondasi modul Tarombo (TAR-01 .. TAR-08).
final taromboModulePagesProvider = Provider<AppModule>(
  (ref) => AppModule.tarombo,
);

/// Entrypoint halaman modul Tarombo (tahap fondasi memakai [SegeraPage]).
class TaromboModulePlaceholderPage extends StatelessWidget {
  const TaromboModulePlaceholderPage({
    required this.pageSpec,
    super.key,
    this.tabIndex,
  });

  final PageSpec pageSpec;
  final int? tabIndex;

  @override
  Widget build(BuildContext context) {
    return SegeraPage(pageSpec: pageSpec, tabIndex: tabIndex);
  }
}
