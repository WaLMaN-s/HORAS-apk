import 'package:go_router/go_router.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// AUT-02 Pengenalan: Tiga layar nilai produk (kenal, tarombo, main), indikator,
/// tombol Lanjut/Lewati, serta pintu Masuk (`AUT-03`) atau Daftar (`AUT-04`).
class Aut02IntroPage extends StatefulWidget {
  const Aut02IntroPage({super.key});

  @override
  State<Aut02IntroPage> createState() => _Aut02IntroPageState();
}

class _Aut02IntroPageState extends State<Aut02IntroPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const List<({String seed, String title, String desc})> _slides =
      <({String seed, String title, String desc})>[
        (
          seed: 'intro-kenal-sekitar',
          title: AppStrings.aut02Slide1Title,
          desc: AppStrings.aut02Slide1Desc,
        ),
        (
          seed: 'intro-tarombo-partuturan',
          title: AppStrings.aut02Slide2Title,
          desc: AppStrings.aut02Slide2Desc,
        ),
        (
          seed: 'intro-main-bareng',
          title: AppStrings.aut02Slide3Title,
          desc: AppStrings.aut02Slide3Desc,
        ),
      ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPressed() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      context.push(AppPages.aut04.routePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const HorasLogo(showRoof: false, wordmarkFontSize: 24),
                  AppButton(
                    label: AppStrings.aut02BtnSkip,
                    variant: AppButtonVariant.text,
                    onPressed: () => context.push(AppPages.aut03.routePath),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const GorgaOrnament(width: double.infinity, height: 18),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (idx) => setState(() => _currentIndex = idx),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          PlaceholderImage(
                            seed: slide.seed,
                            height: 190,
                            width: double.infinity,
                            borderRadius: AppRadius.cardRadius,
                            caption: AppStrings.appTagline,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const HorasLogo(showRoof: true, wordmarkFontSize: 28),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: typo.h1,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            slide.desc,
                            textAlign: TextAlign.center,
                            style: typo.body.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Indikator tiga layar
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(_slides.length, (i) {
                  final active = i == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    width: active ? AppSpacing.xl : AppSpacing.sm,
                    height: AppSpacing.sm,
                    decoration: BoxDecoration(
                      color: active ? colors.buttonPrimary : colors.border,
                      borderRadius: AppRadius.pillRadius,
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: _currentIndex < _slides.length - 1
                    ? AppStrings.aut02BtnNext
                    : AppStrings.aut02BtnRegister,
                isExpanded: true,
                onPressed: _onNextPressed,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: AppStrings.aut02BtnLogin,
                variant: AppButtonVariant.secondary,
                isExpanded: true,
                onPressed: () => context.push(AppPages.aut03.routePath),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
