import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// AKN-15 Tentang HORAS: versi (`package_info_plus`), lisensi (`showLicensePage`),
/// kebijakan, serta pintu masuk Panel Debug non-prod.
class Akn15AboutPage extends ConsumerStatefulWidget {
  const Akn15AboutPage({super.key});

  @override
  ConsumerState<Akn15AboutPage> createState() => _Akn15AboutPageState();
}

class _Akn15AboutPageState extends ConsumerState<Akn15AboutPage> {
  String _version = '0.1.0';
  String _buildNumber = '1';

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadVersion);
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } on Object {
      // Abaikan pada environment tanpa platform channel.
    }
  }

  Future<void> _openPrivacyPolicy() async {
    var content = '';
    try {
      content = await rootBundle.loadString(
        'assets/legal/kebijakan_privasi_dan_syarat.md',
      );
    } on Object {
      content = AppStrings.appTagline;
    }
    if (!mounted) return;
    await AppBottomSheet.show<void>(
      context,
      title: AppStrings.akn15PrivacyPolicyBtn,
      child: SingleChildScrollView(
        child: Text(content, style: context.typo.body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProd = ref.watch(appConfigProvider).isProd;
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.akn15Title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Center(
              child: GestureDetector(
                onLongPress: isProd
                    ? null
                    : () => DebugPanelSheet.showIfNonProd(context, ref),
                child: Column(
                  children: <Widget>[
                    const HorasLogo(showRoof: true, showTagline: true),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppStrings.akn15VersionText(_version, _buildNumber),
                      style: typo.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: const Text(AppStrings.akn15PrivacyPolicyBtn),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _openPrivacyPolicy,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.gavel_outlined),
              title: const Text(AppStrings.akn15GuidelinesBtn),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppPages.sis08.routePath).ignore(),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.article_outlined),
              title: const Text(AppStrings.akn15LicenseBtn),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppStrings.appName,
                applicationVersion: '$_version+$_buildNumber',
              ),
            ),
            if (!isProd) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.debugTapHintOnAbout,
                style: typo.caption.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: AppStrings.debugPanelTitle,
                variant: AppButtonVariant.secondary,
                isExpanded: true,
                onPressed: () => DebugPanelSheet.showIfNonProd(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
