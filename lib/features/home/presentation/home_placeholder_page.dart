import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:material_ui/material_ui.dart';

/// Controller fondasi modul Beranda (BER-01 .. BER-10).
final homeModulePagesProvider = Provider<AppModule>((ref) => AppModule.home);

/// Entrypoint halaman modul Beranda (tahap fondasi memakai [SegeraPage]).
class HomeModulePlaceholderPage extends StatelessWidget {
  const HomeModulePlaceholderPage({
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
