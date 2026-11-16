/// Sub-suku Batak (PRD 1.2, TAR-R6).
///
/// Pada Fase 1 hanya Toba yang memiliki aturan partuturan aktif penuh;
/// sub-suku tanpa aturan tervalidasi berjalan di mode netral (tanpa badge partuturan).
enum SubEthnic {
  toba('Toba', isPhase1RuleValidated: true),
  karo('Karo', isPhase1RuleValidated: false),
  simalungun('Simalungun', isPhase1RuleValidated: false),
  pakpak('Pakpak', isPhase1RuleValidated: false),
  angkola('Angkola', isPhase1RuleValidated: false),
  mandailing('Mandailing', isPhase1RuleValidated: false);

  const SubEthnic(this.displayName, {required this.isPhase1RuleValidated});

  final String displayName;
  final bool isPhase1RuleValidated;
}
