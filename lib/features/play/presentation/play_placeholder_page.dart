import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:material_ui/material_ui.dart';

/// Controller fondasi modul Main (MAN-01 .. MAN-09).
final playModulePagesProvider = Provider<AppModule>((ref) => AppModule.play);

/// Entrypoint halaman modul Main (tahap fondasi memakai [SegeraPage]).
class PlayModulePlaceholderPage extends StatelessWidget {
  const PlayModulePlaceholderPage({
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
