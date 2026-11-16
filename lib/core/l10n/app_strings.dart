/// Seluruh teks antarmuka Bahasa Indonesia terpusat (PRD 1, 5.1, 5.2, 7.3).
///
/// Aturan wajib: tidak ada string UI tersebar di widget; seluruh istilah baku
/// PRD 7.3 diambil dari kelas ini.
abstract final class AppStrings {
  // ── Identitas aplikasi (PRD 1) ──────────────────────────────────────────────
  static const String appName = 'HORAS';
  static const String appWordmark = 'Horas';
  static const String appTagline = 'Satu Aplikasi, Satu Keluarga Orang Batak';

  // ── Istilah Antarmuka Baku (PRD 7.3) ────────────────────────────────────────
  static const String termIkuti = 'Ikuti';
  static const String termMengikuti = 'Mengikuti';
  static const String termPengikut = 'Pengikut';
  static const String termKenalan = 'Kenalan';
  static const String termTerhubung = 'Terhubung';
  static const String termPesan = 'Pesan';
  static const String termSemarga = 'Semarga';
  static const String termKemungkinan = 'Kemungkinan';
  static const String termBelumDiverifikasi = 'Belum diverifikasi';
  static const String termTerverifikasi = 'Terverifikasi';
  static const String termPerkiraan = 'Perkiraan';

  /// Format teks hasil partuturan sesuai tingkat keyakinan (TAR-R5).
  static String partuturanHighLabel(String callTerm) =>
      'Dia adalah ${callTerm}mu';
  static String partuturanMediumLabel(String callTerm) =>
      '$termKemungkinan: $callTerm';
  static const String partuturanLowLabel = 'Belum bisa dipastikan';
  static const String partuturanLowPrompt =
      'Lengkapi marga ibu dan tahun lahir untuk memperjelas jalur partuturan.';
  static const String semargaDescription =
      'Dongan tubu (satu marga / kelompok marga serumpun).';

  // ── Navigasi Utama: 5 Tab (PRD 4) ───────────────────────────────────────────
  static const String tabBeranda = 'Beranda';
  static const String tabBerandaSub = 'Sosial';
  static const String tabSekitar = 'Sekitar';
  static const String tabSekitarSub = 'Penemuan';
  static const String tabTarombo = 'Tarombo';
  static const String tabTaromboSub = 'Keluarga';
  static const String tabMain = 'Main';
  static const String tabMainSub = 'Aktivitas';
  static const String tabAkun = 'Akun';
  static const String tabAkunSub = 'Pengaturan';

  // ── Label Aksesibilitas / Semantics ─────────────────────────────────────────
  static const String semanticsLogo = 'Logo HORAS dan siluet Rumah Bolon';
  static const String semanticsGorga = 'Ornamen gorga Batak';
  static const String semanticsSearch = 'Buka pencarian';
  static const String semanticsNotifications = 'Buka notifikasi';
  static const String semanticsMessages = 'Buka pesan';
  static const String semanticsCreatePost = 'Buat postingan baru';
  static const String semanticsCreateSession = 'Buat sesi main baru';
  static const String semanticsSettings = 'Buka pengaturan';
  static const String semanticsBack = 'Kembali';
  static const String semanticsClose = 'Tutup';
  static const String semanticsClearInput = 'Bersihkan teks';
  static const String semanticsToggleTheme = 'Ganti mode tema tampilan';
  static const String semanticsVerified = 'Lencana Terverifikasi';
  static const String semanticsUnverified = 'Lencana Belum diverifikasi';
  static const String semanticsLoading = 'Sedang memuat konten';
  static String semanticsAvatarFor(String name) => 'Foto profil $name';
  static String semanticsAvatarOverflow(int count) =>
      '$count anggota lainnya';
  static String semanticsTab(String label, String sublabel) =>
      'Tab $label ($sublabel)';
  static String semanticsUnreadBadge(int count) => '$count belum dibaca';

  // ── Tombol dan Aksi Umum ────────────────────────────────────────────────────
  static const String actionRetry = 'Coba lagi';
  static const String actionCancel = 'Batal';
  static const String actionConfirm = 'Konfirmasi';
  static const String actionSave = 'Simpan';
  static const String actionDelete = 'Hapus';
  static const String actionClose = 'Tutup';
  static const String actionSeeAll = 'Lihat Semua';
  static const String actionOpenSettings = 'Buka Pengaturan';
  static const String actionContinueWithoutPermission =
      'Lanjutkan tanpa izin';
  static const String actionSubmitAppeal = 'Ajukan Banding';
  static const String actionBackToHome = 'Kembali ke Beranda';
  static const String actionExploreNearby = 'Jelajahi Sekitar';
  static const String actionNotThisRelation = 'Bukan';
  static const String actionReportWrongRule = 'Laporkan aturan salah';

  // ── Ketentuan Status Standar (PRD 5.2) ──────────────────────────────────────
  static const String stateEmptyDefaultTitle = 'Belum ada data di sini';
  static const String stateEmptyDefaultAction = 'Muat ulang';

  static const String stateOfflineTitle = 'Tidak ada koneksi internet';
  static const String stateOfflineMessage =
      'Periksa jaringanmu lalu coba lagi.';
  static const String stateOfflineCachedBanner =
      'Menampilkan data tersimpan karena perangkat sedang luring.';

  static const String stateServerErrorTitle = 'Terjadi kendala pada layanan';
  static const String stateServerErrorMessage =
      'Kami belum berhasil memuat halaman ini. Silakan coba beberapa saat lagi.';
  static String stateServerErrorReference(String code) =>
      'Kode referensi dukungan: $code';

  static const String statePermissionDeniedTitle = 'Izin akses diperlukan';
  static const String statePermissionDeniedDefaultBenefit =
      'Izin ini membantu HORAS memberikan pengalaman yang relevan di kotamu. Kamu tetap dapat memakai aplikasi tanpa memberikan izin ini.';

  static const String stateContentUnavailableTitle = 'Konten tidak tersedia';
  static const String stateContentUnavailableMessage =
      'Halaman atau konten yang kamu cari saat ini tidak dapat ditampilkan.';

  static const String stateAccountRestrictedTitle =
      'Akun dibatasi atau ditangguhkan';
  static const String stateAccountRestrictedDefaultReason =
      'Akunmu sedang dibatasi karena terdeteksi aktivitas yang tidak sesuai dengan Pedoman Komunitas HORAS.';
  static const String stateAccountRestrictedAppealInfo =
      'Jika menurutmu ini keliru, kamu dapat mengajukan banding ke tim dukungan dalam 14 hari.';

  // ── Mode Tema (Tahap 4) ─────────────────────────────────────────────────────
  static const String themeModeSystem = 'Ikuti sistem';
  static const String themeModeLight = 'Mode terang';
  static const String themeModeDark = 'Mode gelap';

  // ── Halaman Segera / Placeholder Fondasi (Tahap 6) ──────────────────────────
  static const String segeraBadge = 'Kerangka Halaman';
  static const String segeraPhase1Badge = 'Fase 1 · MVP';
  static const String segeraPhase2Badge = 'Fase 2 · Rilis Berikutnya';
  static const String segeraPhase3Badge = 'Fase 3 · Rilis Lanjutan';
  static const String segeraSectionSubpages = 'Halaman Terkait di Modul Ini';
  static const String segeraInfoDescription =
      'Halaman ini terdaftar dalam arsitektur navigasi HORAS dan siap diisi pada tahap modul berikutnya.';
  static const String segeraPhase2HiddenNotice =
      'Fitur Fase 2 saat ini dinonaktifkan sesuai konfigurasi FeatureFlags MVP.';

  // ── Rentang Lokasi Aman Privasi (SEK-R2, AC-07) ─────────────────────────────
  static const String areaSameCity = 'Di kotamu';
  static const String areaSameSubdistrict = 'Di kecamatanmu';

  // ── Daftar 75 Halaman PRD 5.1 (ID, Judul, Tujuan) ───────────────────────────
  // Autentikasi (AUT-01 .. AUT-07)
  static const String aut01Title = 'Splash';
  static const String aut01Purpose = 'Memuat aplikasi, memeriksa sesi login';
  static const String aut02Title = 'Pengenalan';
  static const String aut02Purpose =
      'Tiga layar nilai produk (kenal, tarombo, main)';
  static const String aut03Title = 'Masuk';
  static const String aut03Purpose = 'Input nomor HP';
  static const String aut04Title = 'Daftar';
  static const String aut04Purpose =
      'Persetujuan kebijakan, pedoman, konfirmasi usia 17+';
  static const String aut05Title = 'Verifikasi OTP';
  static const String aut05Purpose = 'Input kode 6 digit';
  static const String aut06Title = 'Onboarding Profil';
  static const String aut06Purpose =
      'Empat langkah: nama dan foto, jenis kelamin dan tahun lahir, marga dan sub-suku, domisili dan minat';
  static const String aut07Title = 'Pemulihan Akun';
  static const String aut07Purpose = 'Mengganti nomor atau memulihkan akses';

  // Beranda (BER-01 .. BER-10)
  static const String ber01Title = 'Beranda';
  static const String ber01Purpose = 'Daftar postingan dari lingkaranmu';
  static const String ber02Title = 'Penampil Story';
  static const String ber02Purpose = 'Menonton story';
  static const String ber03Title = 'Buat Story';
  static const String ber03Purpose = 'Membuat story foto/video';
  static const String ber04Title = 'Buat Postingan';
  static const String ber04Purpose = 'Teks, foto, visibilitas';
  static const String ber05Title = 'Pilih dan Edit Media';
  static const String ber05Purpose = 'Pangkas dan urutkan foto';
  static const String ber06Title = 'Detail Postingan';
  static const String ber06Purpose = 'Satu postingan lengkap';
  static const String ber07Title = 'Komentar';
  static const String ber07Purpose = 'Daftar dan tulis komentar';
  static const String ber08Title = 'Daftar Suka';
  static const String ber08Purpose = 'Siapa yang menyukai';
  static const String ber09Title = 'Pencarian';
  static const String ber09Purpose = 'Kolom cari, riwayat, saran';
  static const String ber10Title = 'Hasil Pencarian';
  static const String ber10Purpose = 'Tab Orang, Komunitas, Gereja, Postingan';

  // Sekitar (SEK-01 .. SEK-12)
  static const String sek01Title = 'Sekitar';
  static const String sek01Purpose = 'Temukan kerabat, dongan sahuta, dan komunitas di kotamu';
  static const String sek02Title = 'Daftar Orang Sekitar';
  static const String sek02Purpose = 'Kartu orang dengan badge partuturan';
  static const String sek03Title = 'Filter Orang';
  static const String sek03Purpose = 'Marga, kota, kampus/kantor, hobi';
  static const String sek04Title = 'Profil Orang Lain';
  static const String sek04Purpose = 'Profil, badge, aksi Ikuti/Kenalan/Pesan';
  static const String sek05Title = 'Daftar Komunitas';
  static const String sek05Purpose = 'Jelajah dan cari komunitas';
  static const String sek06Title = 'Detail Komunitas';
  static const String sek06Purpose = 'Info, anggota, pengumuman, kegiatan';
  static const String sek07Title = 'Buat Komunitas';
  static const String sek07Purpose = 'Formulir pembuatan komunitas';
  static const String sek08Title = 'Kelola Komunitas';
  static const String sek08Purpose =
      'Anggota, permintaan gabung, peran, pengumuman';
  static const String sek09Title = 'Detail Kegiatan';
  static const String sek09Purpose = 'Info kegiatan dan RSVP';
  static const String sek10Title = 'Daftar Gereja';
  static const String sek10Purpose = 'Direktori dan filter gereja';
  static const String sek11Title = 'Detail Gereja';
  static const String sek11Purpose =
      'Jadwal, kontak, kegiatan, jemaat di HORAS';
  static const String sek12Title = 'Pencarian Sekitar';
  static const String sek12Purpose = 'Cari orang dan komunitas di area terpilih';

  // Tarombo (TAR-01 .. TAR-08)
  static const String tar01Title = 'Tarombo';
  static const String tar01Purpose =
      'Ringkasan identitas, kelengkapan silsilah, saran kerabat, dan konfirmasi hubungan';
  static const String tar02Title = 'Pohon Silsilah';
  static const String tar02Purpose = 'Tampilan pohon ringkas 3 generasi';
  static const String tar03Title = 'Tambah/Ubah Anggota Keluarga';
  static const String tar03Purpose = 'Ayah, ibu, kakek dari ayah';
  static const String tar04Title = 'Detail Anggota';
  static const String tar04Purpose = 'Data satu anggota tarombo';
  static const String tar05Title = 'Detail Hubungan';
  static const String tar05Purpose =
      'Panggilan, penjelasan jalur, tingkat keyakinan';
  static const String tar06Title = 'Cek Partuturan';
  static const String tar06Purpose = 'Pilih dua orang, lihat hubungannya';
  static const String tar07Title = 'Konfirmasi Hubungan';
  static const String tar07Purpose = 'Kirim/terima/tolak pengakuan kerabat';
  static const String tar08Title = 'Kamus Partuturan';
  static const String tar08Purpose = 'Cari istilah dan maknanya';

  // Main (MAN-01 .. MAN-09)
  static const String man01Title = 'Main Bareng';
  static const String man01Purpose = 'Daftar sesi olahraga dan aktivitas bersama di sekitar';
  static const String man02Title = 'Filter Sesi';
  static const String man02Purpose = 'Olahraga, hari, level, area, biaya';
  static const String man03Title = 'Buat Sesi';
  static const String man03Purpose = 'Formulir pembuatan sesi main';
  static const String man04Title = 'Detail Sesi';
  static const String man04Purpose = 'Info sesi, gabung/keluar';
  static const String man05Title = 'Peserta dan Daftar Tunggu';
  static const String man05Purpose = 'Daftar peserta dengan badge partuturan';
  static const String man06Title = 'Patungan';
  static const String man06Purpose = 'Biaya per orang dan status bayar';
  static const String man07Title = 'Daftar Lapangan';
  static const String man07Purpose = 'Lapangan olahraga yang sering dipakai';
  static const String man08Title = 'Detail/Usul Lapangan';
  static const String man08Purpose = 'Info lapangan, usulkan lapangan baru';
  static const String man09Title = 'Riwayat Sesi Saya';
  static const String man09Purpose = 'Sesi yang dibuat dan diikuti';

  // Pesan (PSN-01 .. PSN-06)
  static const String psn01Title = 'Daftar Pesan';
  static const String psn01Purpose = 'Semua percakapan pribadi dan grup';
  static const String psn02Title = 'Permintaan Pesan';
  static const String psn02Purpose = 'Pesan dari orang yang belum terhubung';
  static const String psn03Title = 'Chat Pribadi';
  static const String psn03Purpose = 'Percakapan satu lawan satu';
  static const String psn04Title = 'Chat Grup';
  static const String psn04Purpose = 'Grup komunitas dan sesi';
  static const String psn05Title = 'Info Percakapan';
  static const String psn05Purpose = 'Anggota, bisukan, keluar, lapor';
  static const String psn06Title = 'Penampil Media';
  static const String psn06Purpose = 'Foto dalam chat';

  // Akun (AKN-01 .. AKN-15)
  static const String akn01Title = 'Profil Saya';
  static const String akn01Purpose = 'Tampilan profil sendiri, kenalan, dan pengaturan akun';
  static const String akn02Title = 'Edit Profil';
  static const String akn02Purpose = 'Ubah bio, foto, domisili, hobi';
  static const String akn03Title = 'Postingan Saya';
  static const String akn03Purpose = 'Daftar postingan sendiri';
  static const String akn04Title = 'Tersimpan';
  static const String akn04Purpose = 'Postingan yang disimpan';
  static const String akn05Title = 'Pengikut';
  static const String akn05Purpose = 'Daftar pengikut';
  static const String akn06Title = 'Mengikuti';
  static const String akn06Purpose = 'Daftar yang diikuti';
  static const String akn07Title = 'Pengaturan';
  static const String akn07Purpose = 'Menu pengaturan utama, mode gelap';
  static const String akn08Title = 'Privasi Akun';
  static const String akn08Purpose = 'Visibilitas per bidang';
  static const String akn09Title = 'Keamanan Akun';
  static const String akn09Purpose = 'Perangkat aktif, ganti nomor';
  static const String akn10Title = 'Pengaturan Notifikasi';
  static const String akn10Purpose = 'Preferensi per jenis, jam tenang';
  static const String akn11Title = 'Pengguna Diblokir';
  static const String akn11Purpose = 'Daftar dan buka blokir';
  static const String akn12Title = 'Kenalan Saya';
  static const String akn12Purpose = 'Daftar terhubung dan permintaan';
  static const String akn13Title = 'Data Saya';
  static const String akn13Purpose = 'Unduh arsip data pribadi';
  static const String akn14Title = 'Hapus Akun';
  static const String akn14Purpose = 'Alur penghapusan akun dengan masa tunggu 30 hari';
  static const String akn15Title = 'Tentang HORAS';
  static const String akn15Purpose = 'Versi, lisensi, kebijakan';

  // Sistem (SIS-01 .. SIS-08)
  static const String sis01Title = 'Notifikasi';
  static const String sis01Purpose = 'Daftar notifikasi dalam aplikasi';
  static const String sis02Title = 'Laporkan';
  static const String sis02Purpose =
      'Formulir laporan untuk pengguna, konten, komunitas, sesi';
  static const String sis03Title = 'Status Laporan Saya';
  static const String sis03Purpose = 'Riwayat dan hasil laporan';
  static const String sis04Title = 'Pusat Bantuan';
  static const String sis04Purpose = 'Artikel dan pertanyaan umum';
  static const String sis05Title = 'Hubungi Dukungan';
  static const String sis05Purpose = 'Kirim keluhan atau permohonan bantuan';
  static const String sis06Title = 'Ajukan Verifikasi';
  static const String sis06Purpose = 'Verifikasi komunitas punguan';
  static const String sis07Title = 'Status Verifikasi';
  static const String sis07Purpose = 'Status pengajuan verifikasi';
  static const String sis08Title = 'Pedoman Komunitas';
  static const String sis08Purpose = 'Aturan perilaku keluarga besar HORAS';
}
