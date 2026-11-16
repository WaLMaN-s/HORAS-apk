import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:material_ui/material_ui.dart';

/// Controller fondasi modul Sekitar (SEK-01 .. SEK-12).
final nearbyModulePagesProvider = Provider<AppModule>(
  (ref) => AppModule.nearby,
);

/// Entrypoint halaman modul Sekitar (tahap fondasi memakai [SegeraPage]).
class NearbyModulePlaceholderPage extends StatelessWidget {
  const NearbyModulePlaceholderPage({
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
