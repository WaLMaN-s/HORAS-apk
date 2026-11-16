import 'package:flutter/services.dart' show rootBundle;
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// SIS-08 Pedoman Komunitas: dapat dibaca tanpa login (`SIS-R7`).
class Sis08GuidelinesPage extends StatefulWidget {
  const Sis08GuidelinesPage({super.key});

  @override
  State<Sis08GuidelinesPage> createState() => _Sis08GuidelinesPageState();
}

class _Sis08GuidelinesPageState extends State<Sis08GuidelinesPage> {
  String _content = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final text = await rootBundle.loadString(
        'assets/legal/pedoman_komunitas.md',
      );
      if (mounted) {
        setState(() {
          _content = text;
          _isLoading = false;
        });
      }
    } on Object {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sis08Title)),
      body: SafeArea(
        child: _isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.chipInactive,
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: Text(
                      AppStrings.sis08PublicReadNotice,
                      style: typo.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(_content, style: typo.body),
                ],
              ),
      ),
    );
  }
}
