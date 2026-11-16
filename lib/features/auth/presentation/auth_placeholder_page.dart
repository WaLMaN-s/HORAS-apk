import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/segera_page.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:horas/features/auth/presentation/aut01_splash_page.dart';
import 'package:horas/features/auth/presentation/aut02_intro_page.dart';
import 'package:horas/features/auth/presentation/aut03_login_page.dart';
import 'package:horas/features/auth/presentation/aut04_register_page.dart';
import 'package:horas/features/auth/presentation/aut05_otp_page.dart';
import 'package:horas/features/auth/presentation/aut06_onboarding_page.dart';
import 'package:horas/features/auth/presentation/aut07_recovery_page.dart';
import 'package:material_ui/material_ui.dart';

export 'aut01_splash_page.dart';
export 'aut02_intro_page.dart';
export 'aut03_login_page.dart';
export 'aut04_register_page.dart';
export 'aut05_otp_page.dart';
export 'aut06_onboarding_page.dart';
export 'aut07_recovery_page.dart';
export 'auth_flow_controller.dart';

/// Builder halaman modul Autentikasi (`AUT-01` .. `AUT-07` — Prompt 3).
class AuthModulePageRouter extends StatelessWidget {
  const AuthModulePageRouter({required this.pageSpec, super.key});

  final PageSpec pageSpec;

  @override
  Widget build(BuildContext context) {
    if (pageSpec.id == AppPages.aut01.id) return const Aut01SplashPage();
    if (pageSpec.id == AppPages.aut02.id) return const Aut02IntroPage();
    if (pageSpec.id == AppPages.aut03.id) return const Aut03LoginPage();
    if (pageSpec.id == AppPages.aut04.id) return const Aut04RegisterPage();
    if (pageSpec.id == AppPages.aut05.id) return const Aut05OtpPage();
    if (pageSpec.id == AppPages.aut06.id) return const Aut06OnboardingPage();
    if (pageSpec.id == AppPages.aut07.id) return const Aut07RecoveryPage();
    return SegeraPage(pageSpec: pageSpec);
  }
}
