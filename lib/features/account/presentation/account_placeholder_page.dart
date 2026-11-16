import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:material_ui/material_ui.dart';

/// Controller fondasi modul Akun (AKN-01 .. AKN-15).
final accountModulePagesProvider = Provider<AppModule>(
  (ref) => AppModule.account,
);

/// Entrypoint halaman modul Akun (tahap fondasi memakai [SegeraPage]).
class AccountModulePlaceholderPage extends StatelessWidget {
  const AccountModulePlaceholderPage({
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
