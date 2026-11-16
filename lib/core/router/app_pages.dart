import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/domain/models/page_spec.dart';

/// Registri lengkap 75 halaman dari inventaris PRD 5.1.
abstract final class AppPages {
  // ── 5 Tab Utama (PRD 4) ─────────────────────────────────────────────────────
  static const String berandaPath = '/beranda';
  static const String sekitarPath = '/sekitar';
  static const String taromboPath = '/tarombo';
  static const String mainPath = '/main';
  static const String akunPath = '/akun';

  // ── Autentikasi (7 halaman: AUT-01 .. AUT-07) ───────────────────────────────
  static const PageSpec aut01 = PageSpec(
    id: 'AUT-01',
    title: AppStrings.aut01Title,
    purpose: AppStrings.aut01Purpose,
    module: AppModule.auth,
    phase: 1,
    routePath: '/auth/splash',
  );
  static const PageSpec aut02 = PageSpec(
    id: 'AUT-02',
    title: AppStrings.aut02Title,
    purpose: AppStrings.aut02Purpose,
    module: AppModule.auth,
    phase: 1,
    routePath: '/auth/pengenalan',
  );
  static const PageSpec aut03 = PageSpec(
    id: 'AUT-03',
    title: AppStrings.aut03Title,
    purpose: AppStrings.aut03Purpose,
    module: AppModule.auth,
    phase: 1,
    routePath: '/auth/masuk',
  );
  static const PageSpec aut04 = PageSpec(
    id: 'AUT-04',
    title: AppStrings.aut04Title,
    purpose: AppStrings.aut04Purpose,
    module: AppModule.auth,
    phase: 1,
    routePath: '/auth/daftar',
  );
  static const PageSpec aut05 = PageSpec(
    id: 'AUT-05',
    title: AppStrings.aut05Title,
    purpose: AppStrings.aut05Purpose,
    module: AppModule.auth,
    phase: 1,
    routePath: '/auth/otp',
  );
  static const PageSpec aut06 = PageSpec(
    id: 'AUT-06',
    title: AppStrings.aut06Title,
    purpose: AppStrings.aut06Purpose,
    module: AppModule.auth,
    phase: 1,
    routePath: '/auth/onboarding',
  );
  static const PageSpec aut07 = PageSpec(
    id: 'AUT-07',
    title: AppStrings.aut07Title,
    purpose: AppStrings.aut07Purpose,
    module: AppModule.auth,
    phase: 1,
    routePath: '/auth/pemulihan',
  );

  // ── Beranda (10 halaman: BER-01 .. BER-10) ──────────────────────────────────
  static const PageSpec ber01 = PageSpec(
    id: 'BER-01',
    title: AppStrings.ber01Title,
    purpose: AppStrings.ber01Purpose,
    module: AppModule.home,
    phase: 1,
    routePath: berandaPath,
  );
  static final PageSpec ber02 = PageSpec(
    id: 'BER-02',
    title: AppStrings.ber02Title,
    purpose: AppStrings.ber02Purpose,
    module: AppModule.home,
    phase: 2,
    routePath: '/beranda/story-lihat',
    isEnabledByFlags: (flags) => flags.stories,
  );
  static final PageSpec ber03 = PageSpec(
    id: 'BER-03',
    title: AppStrings.ber03Title,
    purpose: AppStrings.ber03Purpose,
    module: AppModule.home,
    phase: 2,
    routePath: '/beranda/story-buat',
    isEnabledByFlags: (flags) => flags.stories,
  );
  static const PageSpec ber04 = PageSpec(
    id: 'BER-04',
    title: AppStrings.ber04Title,
    purpose: AppStrings.ber04Purpose,
    module: AppModule.home,
    phase: 1,
    routePath: '/beranda/postingan-buat',
  );
  static const PageSpec ber05 = PageSpec(
    id: 'BER-05',
    title: AppStrings.ber05Title,
    purpose: AppStrings.ber05Purpose,
    module: AppModule.home,
    phase: 1,
    routePath: '/beranda/media-edit',
  );
  static const PageSpec ber06 = PageSpec(
    id: 'BER-06',
    title: AppStrings.ber06Title,
    purpose: AppStrings.ber06Purpose,
    module: AppModule.home,
    phase: 1,
    routePath: '/beranda/postingan-detail',
  );
  static const PageSpec ber07 = PageSpec(
    id: 'BER-07',
    title: AppStrings.ber07Title,
    purpose: AppStrings.ber07Purpose,
    module: AppModule.home,
    phase: 1,
    routePath: '/beranda/komentar',
  );
  static const PageSpec ber08 = PageSpec(
    id: 'BER-08',
    title: AppStrings.ber08Title,
    purpose: AppStrings.ber08Purpose,
    module: AppModule.home,
    phase: 1,
    routePath: '/beranda/suka',
  );
  static const PageSpec ber09 = PageSpec(
    id: 'BER-09',
    title: AppStrings.ber09Title,
    purpose: AppStrings.ber09Purpose,
    module: AppModule.home,
    phase: 1,
    routePath: '/beranda/cari',
  );
  static const PageSpec ber10 = PageSpec(
    id: 'BER-10',
    title: AppStrings.ber10Title,
    purpose: AppStrings.ber10Purpose,
    module: AppModule.home,
    phase: 1,
    routePath: '/beranda/cari-hasil',
  );

  // ── Sekitar (12 halaman: SEK-01 .. SEK-12) ──────────────────────────────────
  static const PageSpec sek01 = PageSpec(
    id: 'SEK-01',
    title: AppStrings.sek01Title,
    purpose: AppStrings.sek01Purpose,
    module: AppModule.nearby,
    phase: 1,
    routePath: sekitarPath,
  );
  static const PageSpec sek02 = PageSpec(
    id: 'SEK-02',
    title: AppStrings.sek02Title,
    purpose: AppStrings.sek02Purpose,
    module: AppModule.nearby,
    phase: 1,
    routePath: '/sekitar/orang',
  );
  static const PageSpec sek03 = PageSpec(
    id: 'SEK-03',
    title: AppStrings.sek03Title,
    purpose: AppStrings.sek03Purpose,
    module: AppModule.nearby,
    phase: 1,
    routePath: '/sekitar/orang-filter',
  );
  static const PageSpec sek04 = PageSpec(
    id: 'SEK-04',
    title: AppStrings.sek04Title,
    purpose: AppStrings.sek04Purpose,
    module: AppModule.nearby,
    phase: 1,
    routePath: '/sekitar/profil',
  );
  static const PageSpec sek05 = PageSpec(
    id: 'SEK-05',
    title: AppStrings.sek05Title,
    purpose: AppStrings.sek05Purpose,
    module: AppModule.nearby,
    phase: 1,
    routePath: '/sekitar/komunitas',
  );
  static const PageSpec sek06 = PageSpec(
    id: 'SEK-06',
    title: AppStrings.sek06Title,
    purpose: AppStrings.sek06Purpose,
    module: AppModule.nearby,
    phase: 1,
    routePath: '/sekitar/komunitas-detail',
  );
  static const PageSpec sek07 = PageSpec(
    id: 'SEK-07',
    title: AppStrings.sek07Title,
    purpose: AppStrings.sek07Purpose,
    module: AppModule.nearby,
    phase: 1,
    routePath: '/sekitar/komunitas-buat',
  );
  static const PageSpec sek08 = PageSpec(
    id: 'SEK-08',
    title: AppStrings.sek08Title,
    purpose: AppStrings.sek08Purpose,
    module: AppModule.nearby,
    phase: 1,
    routePath: '/sekitar/komunitas-kelola',
  );
  static final PageSpec sek09 = PageSpec(
    id: 'SEK-09',
    title: AppStrings.sek09Title,
    purpose: AppStrings.sek09Purpose,
    module: AppModule.nearby,
    phase: 2,
    routePath: '/sekitar/kegiatan-detail',
    isEnabledByFlags: (flags) => flags.events,
  );
  static final PageSpec sek10 = PageSpec(
    id: 'SEK-10',
    title: AppStrings.sek10Title,
    purpose: AppStrings.sek10Purpose,
    module: AppModule.nearby,
    phase: 2,
    routePath: '/sekitar/gereja',
    isEnabledByFlags: (flags) => flags.church,
  );
  static final PageSpec sek11 = PageSpec(
    id: 'SEK-11',
    title: AppStrings.sek11Title,
    purpose: AppStrings.sek11Purpose,
    module: AppModule.nearby,
    phase: 2,
    routePath: '/sekitar/gereja-detail',
    isEnabledByFlags: (flags) => flags.church,
  );
  static const PageSpec sek12 = PageSpec(
    id: 'SEK-12',
    title: AppStrings.sek12Title,
    purpose: AppStrings.sek12Purpose,
    module: AppModule.nearby,
    phase: 1,
    routePath: '/sekitar/cari',
  );

  // ── Tarombo (8 halaman: TAR-01 .. TAR-08) ───────────────────────────────────
  static const PageSpec tar01 = PageSpec(
    id: 'TAR-01',
    title: AppStrings.tar01Title,
    purpose: AppStrings.tar01Purpose,
    module: AppModule.tarombo,
    phase: 1,
    routePath: taromboPath,
  );
  static const PageSpec tar02 = PageSpec(
    id: 'TAR-02',
    title: AppStrings.tar02Title,
    purpose: AppStrings.tar02Purpose,
    module: AppModule.tarombo,
    phase: 1,
    routePath: '/tarombo/pohon',
  );
  static const PageSpec tar03 = PageSpec(
    id: 'TAR-03',
    title: AppStrings.tar03Title,
    purpose: AppStrings.tar03Purpose,
    module: AppModule.tarombo,
    phase: 1,
    routePath: '/tarombo/anggota-form',
  );
  static const PageSpec tar04 = PageSpec(
    id: 'TAR-04',
    title: AppStrings.tar04Title,
    purpose: AppStrings.tar04Purpose,
    module: AppModule.tarombo,
    phase: 1,
    routePath: '/tarombo/anggota-detail',
  );
  static const PageSpec tar05 = PageSpec(
    id: 'TAR-05',
    title: AppStrings.tar05Title,
    purpose: AppStrings.tar05Purpose,
    module: AppModule.tarombo,
    phase: 1,
    routePath: '/tarombo/hubungan-detail',
  );
  static const PageSpec tar06 = PageSpec(
    id: 'TAR-06',
    title: AppStrings.tar06Title,
    purpose: AppStrings.tar06Purpose,
    module: AppModule.tarombo,
    phase: 1,
    routePath: '/tarombo/cek-partuturan',
  );
  static const PageSpec tar07 = PageSpec(
    id: 'TAR-07',
    title: AppStrings.tar07Title,
    purpose: AppStrings.tar07Purpose,
    module: AppModule.tarombo,
    phase: 1,
    routePath: '/tarombo/konfirmasi',
  );
  static final PageSpec tar08 = PageSpec(
    id: 'TAR-08',
    title: AppStrings.tar08Title,
    purpose: AppStrings.tar08Purpose,
    module: AppModule.tarombo,
    phase: 2,
    routePath: '/tarombo/kamus',
    isEnabledByFlags: (flags) => flags.partuturanDictionary,
  );

  // ── Main (9 halaman: MAN-01 .. MAN-09) ──────────────────────────────────────
  static const PageSpec man01 = PageSpec(
    id: 'MAN-01',
    title: AppStrings.man01Title,
    purpose: AppStrings.man01Purpose,
    module: AppModule.play,
    phase: 1,
    routePath: mainPath,
  );
  static const PageSpec man02 = PageSpec(
    id: 'MAN-02',
    title: AppStrings.man02Title,
    purpose: AppStrings.man02Purpose,
    module: AppModule.play,
    phase: 1,
    routePath: '/main/filter',
  );
  static const PageSpec man03 = PageSpec(
    id: 'MAN-03',
    title: AppStrings.man03Title,
    purpose: AppStrings.man03Purpose,
    module: AppModule.play,
    phase: 1,
    routePath: '/main/sesi-buat',
  );
  static const PageSpec man04 = PageSpec(
    id: 'MAN-04',
    title: AppStrings.man04Title,
    purpose: AppStrings.man04Purpose,
    module: AppModule.play,
    phase: 1,
    routePath: '/main/sesi-detail',
  );
  static const PageSpec man05 = PageSpec(
    id: 'MAN-05',
    title: AppStrings.man05Title,
    purpose: AppStrings.man05Purpose,
    module: AppModule.play,
    phase: 1,
    routePath: '/main/peserta',
  );
  static const PageSpec man06 = PageSpec(
    id: 'MAN-06',
    title: AppStrings.man06Title,
    purpose: AppStrings.man06Purpose,
    module: AppModule.play,
    phase: 1,
    routePath: '/main/patungan',
  );
  static const PageSpec man07 = PageSpec(
    id: 'MAN-07',
    title: AppStrings.man07Title,
    purpose: AppStrings.man07Purpose,
    module: AppModule.play,
    phase: 1,
    routePath: '/main/lapangan',
  );
  static const PageSpec man08 = PageSpec(
    id: 'MAN-08',
    title: AppStrings.man08Title,
    purpose: AppStrings.man08Purpose,
    module: AppModule.play,
    phase: 1,
    routePath: '/main/lapangan-detail',
  );
  static const PageSpec man09 = PageSpec(
    id: 'MAN-09',
    title: AppStrings.man09Title,
    purpose: AppStrings.man09Purpose,
    module: AppModule.play,
    phase: 1,
    routePath: '/main/riwayat',
  );

  // ── Pesan (6 halaman: PSN-01 .. PSN-06) ─────────────────────────────────────
  static const PageSpec psn01 = PageSpec(
    id: 'PSN-01',
    title: AppStrings.psn01Title,
    purpose: AppStrings.psn01Purpose,
    module: AppModule.messages,
    phase: 1,
    routePath: '/pesan',
  );
  static const PageSpec psn02 = PageSpec(
    id: 'PSN-02',
    title: AppStrings.psn02Title,
    purpose: AppStrings.psn02Purpose,
    module: AppModule.messages,
    phase: 1,
    routePath: '/pesan/permintaan',
  );
  static const PageSpec psn03 = PageSpec(
    id: 'PSN-03',
    title: AppStrings.psn03Title,
    purpose: AppStrings.psn03Purpose,
    module: AppModule.messages,
    phase: 1,
    routePath: '/pesan/pribadi',
  );
  static const PageSpec psn04 = PageSpec(
    id: 'PSN-04',
    title: AppStrings.psn04Title,
    purpose: AppStrings.psn04Purpose,
    module: AppModule.messages,
    phase: 1,
    routePath: '/pesan/grup',
  );
  static const PageSpec psn05 = PageSpec(
    id: 'PSN-05',
    title: AppStrings.psn05Title,
    purpose: AppStrings.psn05Purpose,
    module: AppModule.messages,
    phase: 1,
    routePath: '/pesan/info',
  );
  static const PageSpec psn06 = PageSpec(
    id: 'PSN-06',
    title: AppStrings.psn06Title,
    purpose: AppStrings.psn06Purpose,
    module: AppModule.messages,
    phase: 1,
    routePath: '/pesan/media',
  );

  // ── Akun (15 halaman: AKN-01 .. AKN-15) ─────────────────────────────────────
  static const PageSpec akn01 = PageSpec(
    id: 'AKN-01',
    title: AppStrings.akn01Title,
    purpose: AppStrings.akn01Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: akunPath,
  );
  static const PageSpec akn02 = PageSpec(
    id: 'AKN-02',
    title: AppStrings.akn02Title,
    purpose: AppStrings.akn02Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/edit',
  );
  static const PageSpec akn03 = PageSpec(
    id: 'AKN-03',
    title: AppStrings.akn03Title,
    purpose: AppStrings.akn03Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/postingan-saya',
  );
  static const PageSpec akn04 = PageSpec(
    id: 'AKN-04',
    title: AppStrings.akn04Title,
    purpose: AppStrings.akn04Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/tersimpan',
  );
  static const PageSpec akn05 = PageSpec(
    id: 'AKN-05',
    title: AppStrings.akn05Title,
    purpose: AppStrings.akn05Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/pengikut',
  );
  static const PageSpec akn06 = PageSpec(
    id: 'AKN-06',
    title: AppStrings.akn06Title,
    purpose: AppStrings.akn06Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/mengikuti',
  );
  static const PageSpec akn07 = PageSpec(
    id: 'AKN-07',
    title: AppStrings.akn07Title,
    purpose: AppStrings.akn07Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/pengaturan',
  );
  static const PageSpec akn08 = PageSpec(
    id: 'AKN-08',
    title: AppStrings.akn08Title,
    purpose: AppStrings.akn08Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/privasi',
  );
  static const PageSpec akn09 = PageSpec(
    id: 'AKN-09',
    title: AppStrings.akn09Title,
    purpose: AppStrings.akn09Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/keamanan',
  );
  static const PageSpec akn10 = PageSpec(
    id: 'AKN-10',
    title: AppStrings.akn10Title,
    purpose: AppStrings.akn10Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/notifikasi-preferensi',
  );
  static const PageSpec akn11 = PageSpec(
    id: 'AKN-11',
    title: AppStrings.akn11Title,
    purpose: AppStrings.akn11Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/diblokir',
  );
  static const PageSpec akn12 = PageSpec(
    id: 'AKN-12',
    title: AppStrings.akn12Title,
    purpose: AppStrings.akn12Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/kenalan',
  );
  static const PageSpec akn13 = PageSpec(
    id: 'AKN-13',
    title: AppStrings.akn13Title,
    purpose: AppStrings.akn13Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/data-saya',
  );
  static const PageSpec akn14 = PageSpec(
    id: 'AKN-14',
    title: AppStrings.akn14Title,
    purpose: AppStrings.akn14Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/hapus-akun',
  );
  static const PageSpec akn15 = PageSpec(
    id: 'AKN-15',
    title: AppStrings.akn15Title,
    purpose: AppStrings.akn15Purpose,
    module: AppModule.account,
    phase: 1,
    routePath: '/akun/tentang',
  );

  // ── Sistem (8 halaman: SIS-01 .. SIS-08) ────────────────────────────────────
  static const PageSpec sis01 = PageSpec(
    id: 'SIS-01',
    title: AppStrings.sis01Title,
    purpose: AppStrings.sis01Purpose,
    module: AppModule.system,
    phase: 1,
    routePath: '/sistem/notifikasi',
  );
  static const PageSpec sis02 = PageSpec(
    id: 'SIS-02',
    title: AppStrings.sis02Title,
    purpose: AppStrings.sis02Purpose,
    module: AppModule.system,
    phase: 1,
    routePath: '/sistem/laporkan',
  );
  static const PageSpec sis03 = PageSpec(
    id: 'SIS-03',
    title: AppStrings.sis03Title,
    purpose: AppStrings.sis03Purpose,
    module: AppModule.system,
    phase: 1,
    routePath: '/sistem/laporan-status',
  );
  static const PageSpec sis04 = PageSpec(
    id: 'SIS-04',
    title: AppStrings.sis04Title,
    purpose: AppStrings.sis04Purpose,
    module: AppModule.system,
    phase: 1,
    routePath: '/sistem/bantuan',
  );
  static const PageSpec sis05 = PageSpec(
    id: 'SIS-05',
    title: AppStrings.sis05Title,
    purpose: AppStrings.sis05Purpose,
    module: AppModule.system,
    phase: 1,
    routePath: '/sistem/dukungan',
  );
  static const PageSpec sis06 = PageSpec(
    id: 'SIS-06',
    title: AppStrings.sis06Title,
    purpose: AppStrings.sis06Purpose,
    module: AppModule.system,
    phase: 1,
    routePath: '/sistem/verifikasi-ajukan',
  );
  static const PageSpec sis07 = PageSpec(
    id: 'SIS-07',
    title: AppStrings.sis07Title,
    purpose: AppStrings.sis07Purpose,
    module: AppModule.system,
    phase: 1,
    routePath: '/sistem/verifikasi-status',
  );
  static const PageSpec sis08 = PageSpec(
    id: 'SIS-08',
    title: AppStrings.sis08Title,
    purpose: AppStrings.sis08Purpose,
    module: AppModule.system,
    phase: 1,
    routePath: '/sistem/pedoman',
  );

  static final List<PageSpec> authPages = <PageSpec>[
    aut01,
    aut02,
    aut03,
    aut04,
    aut05,
    aut06,
    aut07,
  ];

  static final List<PageSpec> homePages = <PageSpec>[
    ber01,
    ber02,
    ber03,
    ber04,
    ber05,
    ber06,
    ber07,
    ber08,
    ber09,
    ber10,
  ];

  static final List<PageSpec> nearbyPages = <PageSpec>[
    sek01,
    sek02,
    sek03,
    sek04,
    sek05,
    sek06,
    sek07,
    sek08,
    sek09,
    sek10,
    sek11,
    sek12,
  ];

  static final List<PageSpec> taromboPages = <PageSpec>[
    tar01,
    tar02,
    tar03,
    tar04,
    tar05,
    tar06,
    tar07,
    tar08,
  ];

  static final List<PageSpec> playPages = <PageSpec>[
    man01,
    man02,
    man03,
    man04,
    man05,
    man06,
    man07,
    man08,
    man09,
  ];

  static final List<PageSpec> messagePages = <PageSpec>[
    psn01,
    psn02,
    psn03,
    psn04,
    psn05,
    psn06,
  ];

  static final List<PageSpec> accountPages = <PageSpec>[
    akn01,
    akn02,
    akn03,
    akn04,
    akn05,
    akn06,
    akn07,
    akn08,
    akn09,
    akn10,
    akn11,
    akn12,
    akn13,
    akn14,
    akn15,
  ];

  static final List<PageSpec> systemPages = <PageSpec>[
    sis01,
    sis02,
    sis03,
    sis04,
    sis05,
    sis06,
    sis07,
    sis08,
  ];

  /// Seluruh 75 halaman PRD 5.1.
  static final List<PageSpec> all = <PageSpec>[
    ...authPages,
    ...homePages,
    ...nearbyPages,
    ...taromboPages,
    ...playPages,
    ...messagePages,
    ...accountPages,
    ...systemPages,
  ];

  static List<PageSpec> pagesForModule(AppModule module) {
    return switch (module) {
      AppModule.auth => authPages,
      AppModule.home => homePages,
      AppModule.nearby => nearbyPages,
      AppModule.tarombo => taromboPages,
      AppModule.play => playPages,
      AppModule.messages => messagePages,
      AppModule.account => accountPages,
      AppModule.system => systemPages,
    };
  }
}
