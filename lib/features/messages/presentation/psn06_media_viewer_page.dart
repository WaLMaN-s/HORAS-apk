import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

/// PSN-06 Penampil Media dalam Chat (rasio asli tanpa terpotong 1:1, zoom & bagikan).
class Psn06MediaViewerPage extends StatelessWidget {
  const Psn06MediaViewerPage({required this.photoSeed, super.key});

  final String photoSeed;

  Future<void> _sharePhoto(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: '${AppStrings.psn06ShareTextTemplate} ($photoSeed)'),
      );
    } on Object {
      if (context.mounted) {
        AppToast.show(
          context,
          message: AppStrings.psn06ShareUnavailableToast,
          variant: AppToastVariant.info,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSeed = photoSeed.isEmpty ? 'horas-chat-media' : photoSeed;
    final isReal = PlaceholderImage.isRealImageSeed(effectiveSeed);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(AppStrings.psn06Title),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.psn06SharePhotoBtn,
            onPressed: () => _sharePhoto(context),
            icon: Semantics(
              label: AppStrings.psn06SharePhotoBtn,
              child: const Icon(Icons.share_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.5,
          child: isReal
              ? SizedBox.expand(
                  child: PlaceholderImage(
                    seed: effectiveSeed,
                    fit: BoxFit.contain,
                    borderRadius: BorderRadius.zero,
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: PlaceholderImage(
                      seed: effectiveSeed,
                      width: 340,
                      height: 340,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
