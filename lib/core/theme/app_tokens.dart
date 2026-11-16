import 'package:material_ui/material_ui.dart';

/// Grid spasi berbasis 8 (Tahap 4).
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Margin tepi layar standar (16).
  static const double screenMargin = lg;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenMargin,
  );
}

/// Radius sudut komponen sesuai Tahap 4.
abstract final class AppRadius {
  /// Tombol radius 10.
  static const double button = 10;

  /// Foto radius 12.
  static const double photo = 12;

  /// Kartu radius 14.
  static const double card = 14;

  /// Bottom sheet radius 20.
  static const double sheet = 20;

  /// Chip pill (bulat penuh).
  static const double pill = 999;

  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius photoRadius = BorderRadius.all(
    Radius.circular(photo),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
  static const BorderRadius sheetTopRadius = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

/// Ukuran standar komponen dan target sentuh (PRD 5.2, 11, Tahap 4).
abstract final class AppSizes {
  /// Target sentuh interaktif minimal 44 px.
  static const double minTouchTarget = 44;

  static const double buttonHeight = 48;
  static const double chipMinHeight = 44;
  static const double bottomNavHeight = 68;

  static const double iconXs = 14;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 26;
  static const double iconXl = 36;

  static const double avatarXs = 28;
  static const double avatarSm = 36;
  static const double avatarMd = 44;
  static const double avatarLg = 64;
  static const double avatarXl = 88;

  static const double strokeThin = 1;
  static const double strokeMedium = 1.5;
  static const double strokeThick = 2;
}

/// Bayangan sangat lembut untuk kartu dan bilah (Tahap 4).
abstract final class AppShadows {
  static List<BoxShadow> softCard(Color shadowColor) => <BoxShadow>[
    BoxShadow(color: shadowColor, blurRadius: 14, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> subtleBar(Color shadowColor) => <BoxShadow>[
    BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, -2)),
  ];
}
