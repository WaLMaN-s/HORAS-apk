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
      'Dongan tubu (satu marga / kelompok marga serumpun). Ini informasi kekerabatan, bukan pembatasan interaksi.';
  static const String semargaFullLabel = 'Semarga (dongan tubu)';
  static const String partuturanDraftRuleBadge = 'Aturan draf';

  // ── Panel Debug Non-Prod (Prompt 2 - Bagian D) ──────────────────────────────
  static const String debugPanelTitle = 'Panel Debug HORAS (Non-Prod)';
  static const String debugSectionScenarios = 'Skenario Jaringan & Status';
  static const String debugToggleOffline = 'Simulasi Tanpa Koneksi (Offline)';
  static const String debugToggleServerError = 'Simulasi Error Server';
  static const String debugToggleEmpty = 'Simulasi Status Kosong';
  static const String debugToggleSlow = 'Simulasi Jaringan Lambat (+1.2 dtk)';
  static const String debugToggleChatAutoReply =
      'Balasan Otomatis Kontak Tiruan (Chat)';
  static const String debugSectionClock = 'Simulasi Waktu (Clock)';
  static const String debugClockAdvance1Hour = '+1 Jam';
  static const String debugClockAdvance1Day = '+1 Hari';
  static const String debugClockAdvance14Days = '+14 Hari';
  static const String debugClockAdvance30Days = '+30 Hari';
  static const String debugClockReset = 'Reset Waktu';
  static const String debugSectionUser = 'Ganti Pengguna Tiruan Aktif';
  static const String debugSectionModeration = 'Simulasi Moderasi & Data';
  static const String debugAddStrike = 'Tambah 1 Strike ke Akun Aktif';
  static const String debugSuspendAccount = 'Tangguhkan Akun Aktif (Suspend)';
  static const String debugClearSanctions = 'Bersihkan Sanksi Akun';
  static const String debugAdvanceLatestReportReview = 'Tinjau Laporan Terbaru';
  static const String debugCompleteReportActionTaken =
      'Selesaikan Laporan (Tindakan Diambil)';
  static const String debugCompleteReportNoViolation =
      'Selesaikan Laporan (Tidak Melanggar)';
  static const String debugApproveLatestVerification =
      'Setujui Verifikasi Terbaru';
  static const String debugResetAllData = 'Reset Seluruh Data Tiruan';
  static const String debugTapHintOnAbout =
      'Tekan lama logo HORAS di bawah untuk membuka Panel Debug (khusus build dev/beta).';

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
  static String semanticsAvatarOverflow(int count) => '$count anggota lainnya';
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
  static const String actionContinueWithoutPermission = 'Lanjutkan tanpa izin';
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

  // ── Autentikasi (AUT-01 .. AUT-07, AUT-R1 .. AUT-R10) ──────────────────────
  static const String aut01Title = 'Splash';
  static const String aut01Purpose = 'Memuat aplikasi, memeriksa sesi login';
  static const String aut01CheckingSession = 'Memeriksa sesi keluarga HORAS...';

  static const String aut02Title = 'Pengenalan';
  static const String aut02Purpose =
      'Tiga layar nilai produk (kenal, tarombo, main)';
  static const String aut02Slide1Title = 'Temukan Dongan Sahuta di Perantauan';
  static const String aut02Slide1Desc =
      'Kenali sesama orang Batak, punguan marga, dan komunitas di kotamu dengan privasi yang terjaga.';
  static const String aut02Slide2Title = 'Pahami Tarombo & Partuturan';
  static const String aut02Slide2Desc =
      'Ketahui cara memanggil kerabat sesuai sistem kekerabatan Dalihan Na Tolu dengan aturan tervalidasi.';
  static const String aut02Slide3Title = 'Main Bareng & Kumpul Sehat';
  static const String aut02Slide3Desc =
      'Ikuti atau buat sesi badminton, futsal, voli, dan aktivitas bersama di sekitarmu.';
  static const String aut02BtnNext = 'Lanjut';
  static const String aut02BtnSkip = 'Lewati';
  static const String aut02BtnLogin = 'Masuk dengan Nomor HP';
  static const String aut02BtnRegister = 'Daftar Anggota Baru';

  static const String aut03Title = 'Masuk';
  static const String aut03Purpose = 'Input nomor HP';
  static const String aut03Subheading =
      'Masukkan nomor HP aktifmu. Kami akan mengirimkan kode OTP 6 digit tanpa kata sandi.';
  static const String aut03CountryLabel = 'Kode Negara';
  static const String aut03PhoneLabel = 'Nomor HP';
  static const String aut03PhoneHint = '812 3456 7890';
  static const String aut03SendOtpBtn = 'Kirim Kode OTP';
  static const String aut03LostNumberLink = 'Nomor tidak bisa diakses?';
  static const String aut03ToRegisterPrefix = 'Belum pernah mendaftar? ';
  static const String aut03ToRegisterAction = 'Daftar di sini';

  static const String aut04Title = 'Daftar';
  static const String aut04Purpose =
      'Persetujuan kebijakan, pedoman, konfirmasi usia 17+';
  static const String aut04Subheading =
      'Bergabung dengan keluarga besar HORAS. Setujui ketentuan dan konfirmasi usia sebelum verifikasi OTP.';
  static const String aut04ConsentPrivacyLabel =
      'Saya menyetujui Kebijakan Privasi dan Syarat Layanan HORAS.';
  static const String aut04ReadPrivacyBtn =
      'Baca Kebijakan Privasi & Syarat Layanan';
  static const String aut04ConsentGuidelinesLabel =
      'Saya berjanji mematuhi Pedoman Komunitas HORAS.';
  static const String aut04ReadGuidelinesBtn = 'Baca Pedoman Komunitas';
  static const String aut04ConsentAge17Label =
      'Saya menyatakan bahwa saat ini saya berusia 17 tahun atau lebih.';
  static const String aut04LegalDraftBadge = 'Draf, perlu tinjauan hukum';
  static const String aut04ContinueToOtpBtn = 'Setuju & Kirim Kode OTP';
  static const String aut04ToLoginPrefix = 'Sudah punya akun? ';
  static const String aut04ToLoginAction = 'Masuk';
  static const String aut04ErrorMustAcceptAll =
      'Harap centang seluruh persetujuan dan pernyataan usia 17+ untuk melanjutkan.';

  static const String aut05Title = 'Verifikasi OTP';
  static const String aut05Purpose = 'Input kode 6 digit';
  static String aut05SubtitleForPhone(String phone) =>
      'Masukkan 6 digit kode OTP yang dikirimkan ke nomor $phone';
  static const String aut05DevHint =
      'Mode Non-Prod: Gunakan kode OTP tiruan 123456';
  static String aut05ValidityNotice(int minutesLeft, int secondsLeft) =>
      'Kode berlaku ${minutesLeft.toString().padLeft(2, '0')}:${secondsLeft.toString().padLeft(2, '0')}';
  static const String aut05ExpiredNotice =
      'Kode OTP telah kedaluwarsa (lewat 5 menit). Silakan kirim ulang kode baru.';
  static String aut05ResendCountdown(int seconds) =>
      'Kirim ulang kode dalam $seconds detik';
  static const String aut05ResendBtn = 'Kirim Ulang Kode OTP';
  static String aut05RemainingAttempts(int remaining, int max) =>
      'Sisa kesempatan mencoba: $remaining dari $max';
  static String aut05LockedMessage(String retryTimeFormatted) =>
      'Nomor ini dikunci selama 1 jam karena batas percobaan OTP terlampaui. Kamu dapat mencoba lagi pada pukul $retryTimeFormatted.';
  static const String aut05VerifyBtn = 'Verifikasi & Lanjutkan';

  static const String aut06Title = 'Onboarding Profil';
  static const String aut06Purpose =
      'Empat langkah: nama dan foto, jenis kelamin dan tahun lahir, marga dan sub-suku, domisili dan minat';
  static String aut06StepIndicator(int step) => 'Langkah $step dari 4';
  static const String aut06DraftSavedNotice =
      'Draf otomatis tersimpan dan dapat dilanjutkan kapan saja.';
  static const String aut06Step1Title = 'Nama Tampil & Foto Profil';
  static const String aut06Step1Desc =
      'Gunakan nama yang dikenal di keluarga atau komunitasmu (2–40 karakter).';
  static const String aut06DisplayNameLabel = 'Nama Lengkap / Nama Tampil';
  static const String aut06DisplayNameHint = 'Contoh: Rudi Simanjuntak';
  static const String aut06PickPhotoGallery = 'Pilih dari Galeri';
  static const String aut06PickPhotoCamera = 'Ambil Foto Kamera';
  static const String aut06PhotoCompressedBadge =
      'Foto terkompresi & bebas EXIF';

  static const String aut06Step2Title = 'Jenis Kelamin & Tahun Lahir';
  static const String aut06Step2Desc =
      'Digunakan untuk perhitungan panggilan partuturan. Tahun lahir tidak pernah ditampilkan ke orang lain.';
  static const String aut06GenderLabel = 'Jenis Kelamin';
  static const String aut06BirthYearLabel = 'Tahun Lahir (Hanya Tahun)';
  static const String aut06Under17PoliteRejection =
      'Horas! Terima kasih atas minatmu bergabung di HORAS. Saat ini layanan HORAS hanya diperuntukkan bagi pengguna berusia 17 tahun ke atas. Data yang kamu isi tidak kami simpan.';

  static const String aut06Step3Title = 'Marga & Sub-Suku';
  static const String aut06Step3Desc =
      'Identitas marga menjadi dasar hubungan kekerabatan di HORAS.';
  static const String aut06LockWarningBanner =
      'Penting (AUT-R7): Marga, sub-suku, dan jenis kelamin akan dikunci setelah onboarding selesai. Perubahan di kemudian hari hanya dapat diajukan melalui Hubungi Dukungan.';
  static const String aut06SubEthnicLabel = 'Sub-Suku';
  static const String aut06MargaSearchLabel = 'Cari & Pilih Marga';
  static const String aut06MargaSearchHint =
      'Ketik nama marga (mis. Simanjuntak)...';
  static const String aut06MargaNotListedToggle =
      'Marga belum ada di daftar baku';
  static const String aut06CustomMargaInputLabel = 'Tulis Nama Margamu';
  static const String aut06CustomMargaNotice =
      'Marga baru akan masuk ke antrean verifikasi admin dan sementara tampil tanpa badge partuturan (AUT-R6).';
  static const String aut06MotherMargaLabel = 'Marga Ibu (Opsional)';
  static const String aut06MotherMargaHint =
      'Sangat disarankan agar jalur Tulang/Hula-hula dapat dihitung';

  static const String aut06Step4Title = 'Domisili & Minat';
  static const String aut06Step4Desc =
      'Pilih kota dan kecamatan tempat tinggalmu saat ini untuk menemukan komunitas sekitar.';
  static const String aut06CityLabel = 'Kota / Kabupaten Domisili';
  static const String aut06SubdistrictLabel = 'Kecamatan';
  static const String aut06HobbiesLabel = 'Minat & Olahraga (Opsional)';
  static const String aut06CampusOfficeLabel = 'Kampus atau Kantor (Opsional)';
  static const String aut06CampusOfficeHint = 'Contoh: USU Medan / ITB Bandung';
  static const String aut06BtnBackStep = 'Kembali';
  static const String aut06BtnNextStep = 'Langkah Berikutnya';
  static const String aut06BtnFinishSteps = 'Simpan & Lanjutkan';

  // Layar penjelas manfaat izin setelah onboarding (AUT-R10)
  static const String autPermissionTitle = 'Aktifkan Notifikasi & Area Sekitar';
  static const String autPermissionSubtitle =
      'Kami meminta izin hanya setelah kamu memahami manfaatnya. HORAS tetap berfungsi penuh meskipun kamu memilih melewati izin ini.';
  static const String autPermissionNotifTitle =
      'Notifikasi Kerabat & Aktivitas';
  static const String autPermissionNotifDesc =
      'Agar kamu tahu saat ada ajakan Kenalan, konfirmasi Tarombo, pesan baru, atau pengingat sesi olahraga.';
  static const String autPermissionNotifAllowBtn = 'Izinkan Notifikasi';
  static const String autPermissionNotifGranted = 'Notifikasi Diaktifkan';
  static const String autPermissionLocTitle =
      'Lokasi Perkiraan Kota (Tanpa GPS Presisi)';
  static const String autPermissionLocDesc =
      'Hanya memakai lokasi kasar (ACCESS_COARSE_LOCATION) untuk mencocokkan kota terdekat di perangkatmu, lalu koordinatnya langsung dibuang.';
  static const String autPermissionLocAllowBtn = 'Cocokkan Kota Otomatis';
  static String autPermissionLocMatched(String city) =>
      'Kota terdeteksi di perangkat: $city (koordinat telah dibuang)';
  static const String autPermissionDeniedNotice =
      'Izin ditolak. Tidak masalah! Kamu tetap menggunakan domisili manual dan dapat mengubah izin kapan saja di Pengaturan.';
  static const String autPermissionContinueToNearbyBtn =
      'Masuk ke Sekitar Sekarang';

  static const String aut07Title = 'Pemulihan Akun';
  static const String aut07Purpose = 'Mengganti nomor atau memulihkan akses';
  static const String aut07ModeAccessibleTab = 'Nomor Lama Masih Aktif';
  static const String aut07ModeLostTab = 'Nomor Lama Hilang';
  static const String aut07AccessibleDesc =
      'Ganti nomor HP dengan memverifikasi kode OTP ke nomor lama lalu ke nomor baru (AUT-R8a).';
  static const String aut07OldPhoneLabel = 'Nomor HP Lama';
  static const String aut07NewPhoneLabel = 'Nomor HP Baru';
  static const String aut07OldOtpLabel = 'Kode OTP Nomor Lama (6 digit)';
  static const String aut07NewOtpLabel = 'Kode OTP Nomor Baru (6 digit)';
  static const String aut07SendBothOtpBtn = 'Kirim OTP ke Nomor Lama & Baru';
  static const String aut07ConfirmChangePhoneBtn =
      'Verifikasi & Ganti Nomor HP';
  static const String aut07PhoneChangedSuccess =
      'Nomor HP berhasil diperbarui. Silakan masuk dengan nomor barumu.';
  static const String aut07LostDesc =
      'Jika nomor lama sudah tidak aktif, isi bukti kepemilikan akun untuk ditinjau tim dukungan (AUT-R8b).';
  static const String aut07RegDateLabel = 'Perkiraan Bulan & Tahun Mendaftar';
  static const String aut07RegDateHint = 'Contoh: Oktober 2026';
  static const String aut07KnownMargaLabel = 'Marga pada Akun';
  static const String aut07KnownFriendsLabel =
      'Sebutkan Beberapa Nama Kenalan di HORAS';
  static const String aut07KnownFriendsHint =
      'Contoh: Dewi Simanjuntak, Bona Sitorus';
  static const String aut07SubmitRecoveryBtn = 'Kirim Pengajuan Pemulihan';
  static const String aut07RecoveryStatusBadge =
      'Ditinjau, target 3 hari kerja';
  static const String aut07RecoverySubmittedDesc =
      'Pengajuan pemulihan akunmu telah diterima dan sedang ditinjau oleh tim dukungan HORAS dengan target penyelesaian 3 hari kerja.';

  // Beranda (BER-01 .. BER-10)
  static const String ber01Title = 'Beranda';
  static const String ber01Purpose = 'Daftar postingan dari lingkaranmu';
  static const String ber01ComposerPrompt = 'Ada cerita apa hari ini?';
  static const String ber01ComposerSemantics = 'Tulis postingan baru';
  static const String ber01ComposerPhotoTooltip = 'Tambah foto';
  static String ber01AuthorProfileSemantics(String name) => 'Buka profil $name';
  static const String ber01EmptyMessage =
      'Belum ada postingan di berandamu. Ikuti orang dan gabung komunitas untuk melihat kabar terbaru.';
  static const String ber01EmptyAction = 'Jelajahi Sekitar';
  static const String ber01LoadMoreBtn = 'Muat lebih banyak';
  static const String ber01UnderReviewBadge = 'Sedang ditinjau';
  static const String ber01EditedBadge = 'Diedit';
  static const String ber01LikeAction = 'Suka';
  static const String ber01CommentAction = 'Komentar';
  static const String ber01SaveAction = 'Simpan';
  static const String ber01SavedAction = 'Tersimpan';
  static const String ber01ShareAction = 'Bagikan';
  static const String ber01ShareCopiedToast =
      'Tautan postingan disalin ke papan klip.';
  static const String ber01MenuTooltip = 'Menu opsi postingan';
  static const String ber01MenuReport = 'Laporkan';
  static const String ber01MenuMute = 'Bisukan akun';
  static const String ber01MenuBlock = 'Blokir akun';
  static const String ber01MenuEdit = 'Edit teks postingan';
  static const String ber01MenuDelete = 'Hapus postingan';
  static const String ber01MuteConfirmTitle = 'Bisukan Akun Ini?';
  static const String ber01MuteConfirmMessage =
      'Postingan dari akun ini tidak akan tampil lagi di berandamu.';
  static const String ber01BlockConfirmTitle = 'Blokir Pengguna Ini?';
  static const String ber01BlockConfirmMessage =
      'Kalian tidak akan saling melihat profil, postingan, maupun pesan. Koneksi dan ikuti akan dihapus.';
  static const String ber01DeleteConfirmTitle = 'Hapus Postingan Ini?';
  static const String ber01DeleteConfirmMessage =
      'Postingan beserta seluruh komentarnya akan dihapus secara langsung.';
  static const String ber01AccountMutedToast = 'Akun berhasil dibisukan.';
  static const String ber01AccountBlockedToast = 'Pengguna berhasil diblokir.';
  static const String ber01PostDeletedToast = 'Postingan telah dihapus.';

  static const String ber02Title = 'Penampil Story';
  static const String ber02Purpose = 'Menonton story';
  static const String ber03Title = 'Buat Story';
  static const String ber03Purpose = 'Membuat story foto/video';

  static const String ber04Title = 'Buat Postingan';
  static const String ber04Purpose = 'Teks, foto, visibilitas';
  static const String ber04TextHint =
      'Bagikan kabar, cerita komunitas, atau informasi kegiatan di kotamu...';
  static const String ber04AddMediaBtn = 'Pilih / Edit Foto';
  static const String ber04VisibilityLabel = 'Siapa yang dapat melihat';
  static const String ber04VisibilityPublic = 'Publik';
  static const String ber04VisibilityFollowers = 'Pengikut saja';
  static const String ber04VisibilityCommunities = 'Komunitas tertentu';
  static const String ber04SelectCommunitiesLabel = 'Pilih Komunitas';
  static const String ber04CityTagLabel =
      'Tag Lokasi (Hanya Level Kota · Opsional)';
  static const String ber04NoCityTag = 'Tanpa tag lokasi';
  static const String ber04SubmitBtn = 'Posting';
  static const String ber04DraftRestoredNotice =
      'Draf postingan sebelumnya dipulihkan.';
  static const String ber04DraftSavedOnFailToast =
      'Gagal mengunggah. Draf postingan disimpan agar bisa dicoba lagi.';
  static const String ber04UnderReviewToast =
      'Postingan tersimpan dengan status "Sedang ditinjau" dan sementara hanya terlihat olehmu.';
  static const String ber04PublishedToast = 'Postingan berhasil diterbitkan!';

  static const String ber05Title = 'Pilih dan Edit Media';
  static const String ber05Purpose = 'Pangkas dan urutkan foto';
  static const String ber05PickFromGalleryBtn = 'Pilih dari Galeri';
  static const String ber05AddSamplePhotoBtn = 'Tambah Foto Contoh';
  static const String ber05PermissionBenefit =
      'Izinkan akses galeri untuk memilih foto hingga 10 gambar. HORAS otomatis menghapus metadata lokasi (EXIF) sebelum foto dikirim.';
  static const String ber05CropLabel = 'Rasio Pangkas';
  static const String ber05CropSquare = '1:1';
  static const String ber05Crop4x3 = '4:3';
  static const String ber05Crop16x9 = '16:9';
  static const String ber05ReorderHint =
      'Seret gagang di kanan untuk mengurutkan foto. Semua foto dikompres dan dibersihkan EXIF.';
  static const String ber05ApplyBtn = 'Gunakan Foto';
  static const String ber05RemovePhotoTooltip = 'Hapus foto';
  static String ber05PhotoCounter(int count, int max) => '$count/$max foto';

  static const String ber06Title = 'Detail Postingan';
  static const String ber06Purpose = 'Satu postingan lengkap';
  static const String ber06EditTextTitle = 'Edit Teks Postingan';
  static const String ber06ViewLikesAction = 'Lihat daftar suka';

  static const String ber07Title = 'Komentar';
  static const String ber07Purpose = 'Daftar dan tulis komentar';
  static const String ber07InputHint =
      'Tulis komentar sopan (maks. 1.000 karakter)...';
  static const String ber07SendTooltip = 'Kirim komentar';
  static const String ber07ReplyAction = 'Balas';
  static String ber07ReplyingTo(String name) => 'Membalas $name';
  static const String ber07CommentsDisabledBanner =
      'Pembuat postingan menonaktifkan komentar pada postingan ini.';
  static const String ber07DisableComments = 'Matikan komentar';
  static const String ber07EnableComments = 'Aktifkan komentar';
  static const String ber07DeleteCommentTitle = 'Hapus Komentar?';
  static const String ber07DeleteCommentMessage =
      'Komentar ini akan dihapus dari postingan.';
  static const String ber07EmptyMessage =
      'Belum ada komentar. Jadilah yang pertama menyapa!';

  static const String ber08Title = 'Daftar Suka';
  static const String ber08Purpose = 'Siapa yang menyukai';
  static const String ber08EmptyMessage =
      'Belum ada yang menyukai postingan ini.';

  static const String ber09Title = 'Pencarian';
  static const String ber09Purpose = 'Kolom cari, riwayat, saran';
  static const String ber09SearchHint = 'Cari nama, marga, atau komunitas...';
  static const String ber09HistoryHeader = 'Riwayat Pencarian';
  static const String ber09ClearAllHistory = 'Hapus semua';
  static const String ber09SuggestionsHeader = 'Saran Pencarian';
  static const String ber09DeleteHistoryItemTooltip = 'Hapus dari riwayat';

  static const String ber10Title = 'Hasil Pencarian';
  static const String ber10Purpose = 'Tab Orang dan Komunitas';
  static const String ber10TabPeople = 'Orang';
  static const String ber10TabCommunities = 'Komunitas';
  static const String ber10EmptyPeople =
      'Tidak ditemukan pengguna yang cocok dengan kata kunci tersebut.';
  static const String ber10EmptyCommunities =
      'Tidak ditemukan komunitas yang cocok dengan kata kunci tersebut.';

  // Sekitar (SEK-01 .. SEK-12)
  static const String sek01Title = 'Sekitar';
  static const String sek01Purpose =
      'Temukan kerabat, dongan sahuta, dan komunitas di kotamu';
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
  static const String sek12Purpose =
      'Cari orang dan komunitas di area terpilih';

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
  static const String man01Purpose =
      'Daftar sesi olahraga dan aktivitas bersama di sekitar';
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
  static const String akn01Purpose =
      'Tampilan profil sendiri, kenalan, dan pengaturan akun';
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
  static const String akn14Purpose =
      'Alur penghapusan akun dengan masa tunggu 30 hari';
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

  // ── Sekitar Detail & Fitur (Prompt 5: SEK-01 .. SEK-08, SEK-12) ────────────
  static const String sek01SegmentOrang = 'Orang';
  static const String sek01SegmentKomunitas = 'Komunitas';
  static const String sek01AreaLabel = 'Area tampilan';
  static const String sek01AreaPickerTitle = 'Pilih Kota / Area';
  static const String sek01AreaPickerSubtitle =
      'Menampilkan dongan sahuta di area profil atau kota tujuan pilihanmu tanpa GPS.';
  static const String sek01EmptyPeopleMessage =
      'Belum ada pengguna lain yang tampil di area dan filter ini.';
  static const String sek01EmptyCommunitiesMessage =
      'Belum ada komunitas yang tersedia di area ini.';
  static const String sek01LocationPermissionBenefit =
      'Izin lokasi perkiraan membantu mencocokkan kotamu secara otomatis. Kamu tetap dapat mengisi dan mengganti area secara manual.';
  static const String sek01ManualAreaAction = 'Isi Area Manual';
  static const String sek01OpenFilterTooltip = 'Filter Orang';
  static const String sek01OpenSearchTooltip = 'Cari di Sekitar';
  static const String sek01CreateCommunityBtn = 'Buat Komunitas';
  static const String sek01ViewAllPeople = 'Lihat Semua Orang';
  static const String sek01ViewAllCommunities = 'Jelajah Komunitas';
  static const String sek01FilterActivePrefix = 'Filter aktif';

  static const String sek02LoadMoreBtn = 'Muat lebih banyak';
  static const String sek02ChangeAreaBtn = 'Ganti Area';
  static String sek02SharedCommunitiesCount(int count) =>
      '$count komunitas sama';

  static const String sek03MargaLabel = 'Marga';
  static const String sek03MargaHint = 'Semua marga (atau pilih marga)';
  static const String sek03AllMargas = 'Semua Marga';
  static const String sek03CityLabel = 'Kota / Area';
  static const String sek03AllCities = 'Semua Kota';
  static const String sek03CampusOrOfficeLabel = 'Kampus / Kantor';
  static const String sek03CampusOrOfficeHint = 'Contoh: USU, ITB, SCBD';
  static const String sek03HobbyLabel = 'Hobi';
  static const String sek03HobbyHint = 'Contoh: Badminton, Kopi, Futsal';
  static const String sek03ApplyBtn = 'Terapkan Filter';
  static const String sek03ResetBtn = 'Atur Ulang';

  static const String sek04FollowPending = 'Menunggu persetujuan';
  static const String sek04UnfollowAction = 'Berhenti ikuti';
  static const String sek04ConnectionSent = 'Terkirim';
  static const String sek04AcceptBtn = 'Terima';
  static const String sek04RejectBtn = 'Tolak';
  static const String sek04IgnoreBtn = 'Abaikan';
  static const String sek04RemoveConnectionAction = 'Hapus koneksi';
  static const String sek04RemoveConnectionConfirmTitle = 'Hapus Koneksi?';
  static const String sek04RemoveConnectionConfirmBody =
      'Status Terhubung akan diakhiri tanpa pemberitahuan ke pengguna lain.';
  static const String sek04MessageRequestBadge = 'Permintaan pesan';
  static const String sek04MessageSheetTitle = 'Kirim Pesan';
  static const String sek04MessageRequestNotice =
      'Kalian belum Terhubung, tetapi berbagi komunitas/sesi. Pesan pertamamu akan masuk sebagai Permintaan pesan (maksimal 1 pesan teks sampai diterima).';
  static const String sek04OpenChatPlaceholderBtn = 'Buka Chat';
  static const String sek04SendFirstMessageBtn = 'Kirim Permintaan Pesan';
  static const String sek04MessageSentNotice =
      'Permintaan pesan berhasil dikirim.';
  static const String sek04PrivateAccountTitle = 'Akun ini privat';
  static const String sek04PrivateAccountSubtitle =
      'Nama, foto, marga, dan kota tetap terlihat. Bio, hobi, dan rincian lain disembunyikan sesuai pengaturan privasi pemilik.';
  static const String sek04BioSectionTitle = 'Tentang';
  static const String sek04InfoSectionTitle = 'Informasi Terlihat';
  static const String sek04MotherMargaLabel = 'Marga Ibu';
  static const String sek04SubdistrictLabel = 'Kecamatan';
  static const String sek04AgeGroupLabel = 'Rentang Usia';
  static const String sek04CampusOfficeLabel = 'Kampus / Kantor';
  static const String sek04HobbiesLabel = 'Hobi';
  static const String sek04NeutralModeHint =
      'Mode netral aktif: sub-suku belum memiliki aturan partuturan tervalidasi atau marga belum diverifikasi.';
  static const String sek04KinshipAcceptQuestion = 'Konfirmasi';
  static const String sek04KinshipRejectQuestion = 'Bukan';
  static const String sek04KinshipConfirmToast =
      'Terima kasih! Hubungan partuturan ditandai sesuai.';
  static const String sek04KinshipFeedbackToast =
      'Masukan dicatat untuk peninjauan aturan adat.';
  static const String sek04MenuReport = 'Laporkan';
  static const String sek04MenuMute = 'Bisukan akun';
  static const String sek04MenuBlock = 'Blokir akun';
  static const String sek04BlockConfirmTitle = 'Blokir Akun Ini?';
  static const String sek04BlockConfirmBody =
      'Kalian tidak akan saling terlihat di profil, postingan, pencarian, dan Sekitar. Koneksi serta ikuti akan dihapus.';
  static const String sek04MuteSuccessToast =
      'Akun dibisukan dari tampilan Sekitar dan Beranda.';
  static const String sek04IncomingRequestBanner =
      'Mengajakmu menjadi Kenalan (Terhubung)';

  static const String sek04SheetKenalanTitle = 'Kirim Permintaan Kenalan';
  static const String sek04SheetKenalanSubtitle =
      'Pilih sapaan cepat atau tulis pesan pengantar maksimal 200 karakter.';
  static const List<String> sek04QuickGreetings = <String>[
    'Horas! Salam kenal.',
    'Horas dongan sahuta!',
    'Salam keluarga HORAS!',
  ];
  static const String sek04IntroHint = 'Tulis pengantar singkat (opsional)...';
  static const String sek04SendKenalanBtn = 'Kirim Kenalan';
  static const String sek04KenalanSentToast = 'Permintaan Kenalan terkirim.';
  static const String sek04KenalanAcceptedToast =
      'Permintaan Kenalan diterima! Sekarang kalian Terhubung.';
  static const String sek04KenalanRejectedToast = 'Permintaan Kenalan ditolak.';

  static const String sek05AccessOpen = 'Terbuka';
  static const String sek05AccessApproval = 'Dengan persetujuan';
  static const String sek05AccessClosed = 'Tertutup';
  static String sek05MemberCount(int count) => '$count anggota';

  static const String sek06JoinBtn = 'Gabung';
  static const String sek06RequestJoinBtn = 'Minta Gabung';
  static const String sek06WaitingApprovalBtn = 'Menunggu persetujuan';
  static const String sek06ApprovalExpiryHint =
      'Permintaan gabung kedaluwarsa otomatis dalam 14 hari bila belum ditanggapi.';
  static const String sek06LeaveBtn = 'Keluar Komunitas';
  static const String sek06ManageBtn = 'Kelola Komunitas';
  static const String sek06GroupChatBtn = 'Chat Grup Komunitas';
  static const String sek06AnnouncementsSection = 'Pengumuman';
  static const String sek06MembersSection = 'Daftar Anggota';
  static const String sek06PinnedBadge = 'Disematkan';
  static const String sek06NoAnnouncements =
      'Belum ada pengumuman di komunitas ini.';
  static const String sek06OwnerMustTransferTitle =
      'Tidak Dapat Keluar Sebelum Serah Kepemilikan';
  static const String sek06OwnerMustTransferBody =
      'Pemilik harus menyerahkan kepemilikan sebelum keluar. Silakan pilih Pemilik baru melalui menu Kelola Komunitas.';
  static const String sek06OwnerTransferAction = 'Buka Kelola Komunitas';
  static const String sek06ClosedCommunityHint =
      'Komunitas Tertutup · Hanya anggota';
  static const String sek06LeaveConfirmTitle = 'Keluar dari Komunitas?';
  static const String sek06LeaveConfirmBody =
      'Kamu akan keluar dari komunitas dan grup chat komunitas ini.';

  static const String sek07TypeLabel = 'Jenis Komunitas';
  static const String sek07NameLabel = 'Nama Komunitas';
  static const String sek07NameHint = 'Minimal 3 karakter, maksimal 60';
  static const String sek07MargaNameLabel = 'Nama Marga Punguan';
  static const String sek07CityLabel = 'Kota Domisili Komunitas';
  static const String sek07DescLabel = 'Deskripsi Komunitas';
  static const String sek07DescHint =
      'Jelaskan tujuan dan kegiatan komunitas (maks. 500 karakter)';
  static const String sek07AccessLabel = 'Akses Bergabung';
  static const String sek07SubmitBtn = 'Buat Komunitas';
  static const String sek07CreatedToast =
      'Komunitas dan chat grup otomatis berhasil dibuat.';
  static const String sek07PunguanUnverifiedNote =
      'Komunitas Punguan Marga baru berstatus Belum diverifikasi sampai pengajuan verifikasi (SIS-06) disetujui.';

  static const String sek08TabMembers = 'Anggota';
  static const String sek08TabRequests = 'Permintaan';
  static const String sek08TabRoles = 'Peran';
  static const String sek08TabAnnouncements = 'Pengumuman';
  static const String sek08RoleOwner = 'Pemilik';
  static const String sek08RoleManager = 'Pengurus';
  static const String sek08RoleMember = 'Anggota';
  static const String sek08PromoteManager = 'Jadikan Pengurus';
  static const String sek08DemoteMember = 'Jadikan Anggota Biasa';
  static const String sek08TransferOwner = 'Serahkan Kepemilikan';
  static const String sek08KickMember = 'Keluarkan';
  static const String sek08KickConfirmTitle = 'Keluarkan Anggota?';
  static String sek08KickConfirmBody(String name) =>
      '$name akan dikeluarkan dari komunitas dan chat grup komunitas.';
  static const String sek08TransferConfirmTitle = 'Serahkan Kepemilikan?';
  static String sek08TransferConfirmBody(String name) =>
      'Apakah kamu yakin menyerahkan peran Pemilik komunitas kepada $name? Kamu akan menjadi Pengurus.';
  static const String sek08ManagersLimitNote = 'Pengurus maksimal 10 orang';
  static const String sek08PinnedLimitNote = 'Pengumuman disematkan maksimal 3';
  static const String sek08RequestVerificationBtn = 'Ajukan Verifikasi';
  static const String sek08ApproveJoinBtn = 'Setujui';
  static const String sek08RejectJoinBtn = 'Tolak';
  static const String sek08NoJoinRequests =
      'Tidak ada permintaan gabung tertunda.';
  static const String sek08AnnouncementTitleLabel = 'Judul Pengumuman';
  static const String sek08AnnouncementBodyLabel = 'Isi Pengumuman';
  static const String sek08PinAnnouncementToggle = 'Sematkan pengumuman';
  static const String sek08PublishAnnouncementBtn = 'Terbitkan Pengumuman';
  static const String sek08PinToggleBtn = 'Sematkan / Lepas';

  static const String sek12SearchHint = 'Cari nama, marga, atau komunitas...';
  static const String sek12SearchPrompt =
      'Ketik nama orang, marga, atau nama komunitas di Sekitar.';

  // ── Tarombo & Partuturan (Prompt 6: TAR-01 .. TAR-07) ──────────────────────
  static const String tarConsentTitle = 'Persetujuan Data Keluarga (Tarombo)';
  static const String tarConsentBody =
      'Dengan mengisi silsilah Tarombo, kamu menyatakan bahwa kamu memasukkan data anggota keluarga (pihak lain) secara sukarela dan bertanggung jawab, hanya untuk penggunaan di lingkup privasi pilihanmu.';
  static const String tarConsentAcceptBtn = 'Saya Setuju & Lanjutkan';
  static const String tarConsentCancelBtn = 'Nanti Saja';

  static const String tar01IdentityTitle = 'Identitas Adat';
  static const String tar01MotherMargaLabel = 'Marga Ibu';
  static const String tar01MotherMargaEmpty = 'Belum diisi';
  static const String tar01EditMotherMargaBtn = 'Lengkapi Marga Ibu';
  static const String tar01CompletenessTitle = 'Kelengkapan Tarombo';
  static String tar01CompletenessPercent(int percent) => '$percent% Lengkap';
  static const String tar01CompletenessSubtitle =
      'Ajakan melengkapi 5 butir dasar (bukan syarat menggunakan aplikasi).';
  static const String tar01ItemMotherMarga = 'Marga Ibu';
  static const String tar01ItemFather = 'Ayah';
  static const String tar01ItemMother = 'Ibu';
  static const String tar01ItemPaternalGrandfather = 'Kakek dari Ayah';
  static const String tar01ItemMaternalGrandfather = 'Kakek dari Ibu';
  static const String tar01NeutralBanner =
      'Mode netral aktif: sub-suku ini belum memiliki aturan partuturan tervalidasi di Fase 1. Identitas marga dan Semarga tetap aktif.';
  static const String tar01SuggestionsTitle = 'Saran Kerabat';
  static const String tar01IncomingClaimsTitle = 'Permintaan Konfirmasi Masuk';
  static const String tar01EmptySuggestions =
      'Belum ada saran kerabat di sekitar saat ini.';
  static const String tar01OpenTreeBtn = 'Pohon Silsilah';
  static const String tar01AddMemberBtn = 'Tambah Anggota';
  static const String tar01CheckPartuturanBtn = 'Cek Partuturan';
  static const String tar01ConfirmationsBtn = 'Konfirmasi Hubungan';

  static const String tar01PrivacyTitle = 'Privasi & Data Tarombo';
  static const String tar01PrivacyTaromboLabel = 'Visibilitas Tarombo';
  static const String tar01PrivacyMotherMargaLabel = 'Visibilitas Marga Ibu';
  static const String tar01PrivacyParentsLabel = 'Visibilitas Nama Orang Tua';
  static const String tar01VisibilityOnlyMe = 'Hanya saya';
  static const String tar01VisibilityConnected = 'Terhubung';
  static const String tar01VisibilityEveryone = 'Publik';
  static const String tar01DeleteAllBtn = 'Hapus Seluruh Data Tarombo';
  static const String tar01DeleteAllConfirmTitle =
      'Hapus Seluruh Data Tarombo?';
  static const String tar01DeleteAllConfirmBody =
      'Semua catatan anggota keluarga di Tarombo milikmu akan dihapus permanen dan privasi dikembalikan ke Hanya saya.';
  static const String tar01DeleteAllDoneToast =
      'Seluruh data tarombo telah dihapus.';
  static const String tar01EmptyDataMessage =
      'Belum ada anggota keluarga di Tarombo. Mulai dengan menambahkan ayah, ibu, atau kakek.';

  static const String tar02SubtitleFullTreeSoon =
      'Pohon penuh menyusul (Fase 3)';
  static const String tar02ThreeGenNotice =
      'Menampilkan maksimal 3 generasi ke atas dari pemilik. Cubit atau geser untuk menjelajahi silsilah.';
  static const String tar02SelfNodeRole = 'Pemilik';
  static const String tar02ZoomHint = 'Geser atau cubit untuk memperbesar';

  static const String tar03RelationLabel = 'Hubungan Keluarga';
  static const String tar03FullNameLabel = 'Nama Lengkap';
  static const String tar03FullNameHint = 'Contoh: St. Maringan Simanjuntak';
  static const String tar03MargaLabel = 'Marga';
  static const String tar03MargaHint = 'Contoh: Simanjuntak';
  static const String tar03GenderLabel = 'Jenis Kelamin';
  static const String tar03BirthYearLabel = 'Tahun Lahir (Opsional)';
  static const String tar03BirthYearHint = 'Contoh: 1966';
  static const String tar03LifeStatusLabel = 'Status';
  static const String tar03NoPhotoOrContactNote =
      'Sesuai TAR-R3, anggota tarombo non-pengguna tidak dapat dicari publik dan tidak memuat foto maupun kontak.';
  static const String tar03SaveBtn = 'Simpan Anggota';
  static const String tar03SavedToast =
      'Anggota keluarga tersimpan di Tarombo.';

  static const String tar04EditBtn = 'Ubah';
  static const String tar04DeleteBtn = 'Hapus Anggota';
  static const String tar04DeleteConfirmTitle = 'Hapus Anggota Keluarga?';
  static const String tar04DeleteConfirmBody =
      'Anggota ini akan dihapus dari silsilah tarombomu.';
  static const String tar04NotListed = 'Tidak dicantumkan';
  static const String tar04PrivacyNotice =
      'Hanya terlihat oleh pemilik dan pihak yang disetujui; tidak dapat dicari publik; tanpa foto atau kontak (TAR-R3).';
  static const String tar04LinkPromptBtn =
      'Tautkan ke Akun HORAS (Perlu Konfirmasi)';
  static const String tar04LinkDialogTitle =
      'Konfirmasi Penautan Akun (TAR-R4)';
  static String tar04LinkDialogBody(String name) =>
      'Kami menemukan akun HORAS "$name" yang mungkin cocok. Penautan tidak pernah otomatis dan butuh persetujuan kedua pihak. Kirim permintaan konfirmasi?';
  static const String tar04LinkSendBtn = 'Kirim Konfirmasi Penautan';
  static const String tar04LinkSentToast =
      'Permintaan konfirmasi penautan dikirim.';

  static const String tar05SectionCallTerm = 'Panggilan & Hubungan';
  static const String tar05SectionPath = 'Penjelasan Jalur';
  static const String tar05SendWeAreKinBtn = 'Kirim klaim Kami kerabat';
  static const String tar05ReportWrongRuleBtn = 'Laporkan aturan salah';
  static const String tar05ReportWrongRuleTitle =
      'Laporkan Aturan Partuturan Salah';
  static const String tar05ReportWrongRuleHint =
      'Jelaskan ketidaksesuaian menurut adat / wilayah (opsional)...';
  static const String tar05ReportSubmittedToast =
      'Laporan dikirim ke reviewer adat untuk peninjauan.';
  static const String tar05EstimateBadgeDesc =
      'Hasil Perkiraan (bukan fakta silsilah sampai dikonfirmasi kedua pihak).';
  static const String tar05ConfirmedBadgeDesc =
      'Terverifikasi kedua pihak (keyakinan Tinggi).';

  static const String tar06TabPickTwoPeople = 'Pilih Dua Orang';
  static const String tar06TabManualInput = 'Input Manual';
  static const String tar06PersonALabel = 'Orang Pertama (Sudut Pandang)';
  static const String tar06PersonBLabel = 'Orang Kedua (Target)';
  static const String tar06ManualSubEthnicLabel = 'Sub-suku';
  static const String tar06ManualMargaALabel = 'Marga Orang A';
  static const String tar06ManualMotherMargaALabel =
      'Marga Ibu Orang A (Opsional)';
  static const String tar06ManualMargaBLabel = 'Marga Orang B';
  static const String tar06ManualGenDiffLabel = 'Selisih Generasi';
  static const String tar06CalculateBtn = 'Cek Hubungan';
  static const String tar06ResultHeader = 'Hasil Cek Partuturan';
  static const String tar06GenAbove2 = '2 Generasi di Atas (+2 / Ompung)';
  static const String tar06GenAbove1 = '1 Generasi di Atas (+1 / Orang Tua)';
  static const String tar06GenSame = 'Sejajar (0 / Sepupu/Saudara)';
  static const String tar06GenBelow1 = '1 Generasi di Bawah (-1 / Anak)';
  static const String tar06GenUnknown = 'Generasi Tidak Diketahui';

  static const String tar07TabIncoming = 'Masuk';
  static const String tar07TabWaiting = 'Menunggu';
  static const String tar07TabSendNew = 'Kirim Klaim';
  static const String tar07SelectTargetLabel = 'Pilih Kenalan / Pengguna';
  static const String tar07SelectTermLabel = 'Pilih Jenis Hubungan (Panggilan)';
  static const String tar07NoteLabel = 'Catatan Tambahan (Opsional)';
  static const String tar07SendClaimBtn = 'Kirim Klaim Kami Kerabat';
  static const String tar07ClaimSentToast =
      'Klaim Kami kerabat terkirim. Menunggu persetujuan pihak lain.';
  static const String tar07ClaimAcceptedToast =
      'Klaim diterima! Tingkat keyakinan hubungan naik menjadi Tinggi.';
  static const String tar07ClaimRejectedToast = 'Klaim ditolak.';
  static const String tar07EmptyIncoming =
      'Tidak ada permintaan konfirmasi hubungan yang masuk.';
  static const String tar07EmptyWaiting =
      'Belum ada klaim yang sedang menunggu persetujuan.';
  static const String tar07WaitingBadge = 'Menunggu konfirmasi';
  static const List<String> tar07CommonTerms = <String>[
    'Tulang',
    'Nantulang',
    'Amangboru',
    'Namboru',
    'Lae',
    'Ito',
    'Pariban',
    'Dongan Tubu',
    'Amanguda',
    'Inanguda',
    'Hula-hula',
    'Boru',
    'Bere',
  ];

  // ── Main Bareng (Prompt 7: MAN-01 .. MAN-09) ───────────────────────────────
  static const String man01EmptyMessage = 'Belum ada sesi, buat yang pertama';
  static const String man01CreateSessionBtn = 'Buat Sesi';
  static const String man01PopularCourtsSection = 'Lapangan Populer';
  static const String man01HistoryTooltip = 'Riwayat Sesi Saya';
  static const String man01FilterTooltip = 'Filter Sesi';
  static const String man01AllCourtsAction = 'Lihat Lapangan';
  static String man01ParticipantsRatio(int joined, int maxSlots) =>
      '$joined/$maxSlots peserta';
  static const String man01FreeFeeLabel = 'Gratis';

  static const String man02SportLabel = 'Cabang Olahraga';
  static const String man02AllSports = 'Semua Olahraga';
  static const String man02DayLabel = 'Hari';
  static const String man02DayAll = 'Semua Hari';
  static const String man02DayToday = 'Hari Ini';
  static const String man02DayTomorrow = 'Besok';
  static const String man02DayWeekend = 'Akhir Pekan';
  static const String man02LevelLabel = 'Level Pemain';
  static const String man02AllLevels = 'Semua';
  static const String man02RangeLabel = 'Rentang Jarak Area';
  static const String man02RangeAll = 'Semua di kota';
  static const String man02RangeSameSubdistrict = 'Di kecamatanmu';
  static const String man02RangeSameCity = 'Di kotamu';
  static const String man02CostLabel = 'Biaya';
  static const String man02CostAll = 'Semua Biaya';
  static const String man02CostFree = 'Gratis (Rp0)';
  static const String man02CostPaid = 'Patungan Berbayar';

  static const String man03NoGamblingBanner =
      'Taruhan uang atau judi dilarang keras di HORAS. Sesi hanya boleh di tempat umum atau fasilitas olahraga.';
  static const String man03TitleLabel = 'Judul Sesi (Opsional)';
  static const String man03TitleHint = 'Contoh: Badminton Naposo Sore';
  static const String man03VenueModeCourt = 'Pilih Lapangan';
  static const String man03VenueModeManual = 'Tempat Umum / Ketik Manual';
  static const String man03CourtSelectLabel = 'Lapangan Terdaftar';
  static const String man03ManualSummaryLabel =
      'Nama Area / Tempat Umum (tampil ke publik)';
  static const String man03ManualSummaryHint = 'Contoh: Taman Lapangan Merdeka';
  static const String man03ManualFullDetailLabel =
      'Alamat Lengkap / Titik Kumpul (baru tampil ke peserta yang sudah bergabung)';
  static const String man03StartOffsetLabel = 'Jadwal Mulai';
  static const String man03DurationHoursLabel = 'Durasi (Jam)';
  static const String man03SlotsLabel = 'Jumlah Slot Termasuk Host (2-50)';
  static const String man03FeeLabel =
      'Perkiraan Biaya per Orang (Rp0 - 1.000.000)';
  static const String man03NotesLabel = 'Catatan Sesi (Maks. 300 karakter)';
  static const String man03VisibilityLabel = 'Visibilitas Sesi';
  static const String man03VisibilityPublic = 'Publik di area';
  static const String man03VisibilityCommunity = 'Komunitas tertentu';
  static const String man03VisibilityInviteOnly = 'Hanya undangan';
  static const String man03JoinModeLabel = 'Mode Bergabung';
  static const String man03JoinModeInstant = 'Langsung gabung';
  static const String man03JoinModeHostApproval = 'Perlu persetujuan host';
  static const String man03SubmitBtn = 'Terbitkan Sesi';
  static const String man03CreatedToast =
      'Sesi main, chat grup otomatis, dan pengingat lokal berhasil dibuat.';
  static const String man03StartTime2h = '2 jam lagi';
  static const String man03StartTimeTomorrowMorning = 'Besok 08:00';
  static const String man03StartTimeTomorrowNight = 'Besok 19:00';
  static const String man03StartTimeNextWeek = '3 hari lagi';

  static const String man04JoinBtn = 'Gabung';
  static const String man04JoinWaitlistBtn = 'Masuk Daftar Tunggu';
  static const String man04LeaveBtn = 'Keluar dari Sesi';
  static const String man04WaitingHostApproval = 'Menunggu persetujuan host';
  static String man04WaitlistPositionBadge(int pos) =>
      'Daftar Tunggu · Urutan $pos';
  static const String man04StatusUpdatedBadge = 'Jadwal/Lokasi Diubah';
  static const String man04StatusCancelledBadge = 'Dibatalkan';
  static const String man04StatusCompletedBadge = 'Selesai';
  static const String man04Restricted7DaysBanner =
      'Belum bisa bergabung selama 7 hari karena 3 catatan ketidakhadiran/keluar mendadak dalam 30 hari terakhir.';
  static const String man04LateLeaveTitle = 'Keluar Mendadak (< 3 Jam)';
  static const String man04LateLeaveBody =
      'Waktu mulai kurang dari 3 jam. Keluar sekarang akan menambah catatan keandalan (3 catatan dalam 30 hari membatasi gabung sesi baru selama 7 hari). Tetap keluar?';
  static const String man04NormalLeaveTitle = 'Keluar dari Sesi?';
  static const String man04NormalLeaveBody =
      'Slotmu akan dilepaskan untuk peserta lain atau daftar tunggu berikutnya.';
  static const String man04CancelSessionTitle = 'Batalkan Sesi Ini?';
  static const String man04CancelSessionBody =
      'Seluruh peserta yang bergabung akan menerima notifikasi pembatalan.';
  static const String man04CancelSessionBtn = 'Batalkan Sesi';
  static const String man04EditScheduleBtn = 'Edit Jadwal / Lapangan';
  static const String man04EditScheduleNote =
      'Mengubah jadwal/lapangan memberi notifikasi ke peserta dan mengizinkan mereka keluar tanpa catatan keandalan.';
  static const String man04ParticipantsBtn = 'Peserta & Daftar Tunggu';
  static const String man04PatunganBtn = 'Patungan Biaya';
  static const String man04SessionChatBtn = 'Chat Grup Sesi';
  static const String man04ManualDetailHiddenHint =
      'Detail titik kumpul lengkap baru ditampilkan kepada peserta yang sudah bergabung.';
  static String man04RemindersScheduledInfo(String timesSummary) =>
      'Pengingat lokal (jam tenang 22.00-06.00): $timesSummary';

  static const String man05WaitlistSection = 'Daftar Tunggu (FIFO)';
  static const String man05EmptyWaitlist =
      'Belum ada pengguna di daftar tunggu.';
  static const String man05PendingRequestsSection = 'Menunggu Persetujuan Host';
  static const String man05JoinedSection = 'Peserta Bergabung';
  static const String man05MarkAttended = 'Hadir';
  static const String man05MarkAbsent = 'Tidak Hadir';
  static const String man05KickBtn = 'Keluarkan';
  static String man05HostReliabilityCount(int count) =>
      'Catatan keandalan (host): $count';

  static const String man06DisclaimerBanner =
      'Pembayaran terjadi di luar aplikasi; HORAS tidak menyimpan rekening dan tidak memproses uang.';
  static const String man06ModeTotal = 'Isi Total Biaya';
  static const String man06ModePerPerson = 'Isi Biaya per Orang';
  static const String man06AmountLabel = 'Nominal (Rupiah)';
  static const String man06RecalculateBtn = 'Hitung Patungan (Bulatkan Rp500)';
  static String man06PerPersonResult(int rupiah) =>
      'Patungan per orang: Rp$rupiah';
  static const String man06MarkPaidBtn = 'Sudah bayar';
  static const String man06WaitingConfirmBadge = 'Menunggu konfirmasi host';
  static const String man06ConfirmPaidBtn = 'Konfirmasi Lunas';
  static const String man06PaidConfirmedBadge = 'Terkonfirmasi Lunas';

  static const String man07ProposeCourtBtn = 'Usulkan Lapangan';
  static const String man07EmptyCourtsMessage =
      'Belum ada lapangan terdaftar di kota ini.';

  static const String man08EstimatedPricePrefix = 'Perkiraan harga';
  static const String man08OpeningHoursLabel = 'Jam Operasional';
  static const String man08OpenMapsBtn = 'Buka Lokasi di Peta';
  static const String man08ReportWrongInfoBtn = 'Laporkan info salah';
  static const String man08ReportWrongInfoTitle =
      'Laporkan Info Lapangan Salah';
  static const String man08ReportWrongInfoHint =
      'Jelaskan info yang keliru (harga, alamat, jam)...';
  static const String man08ReportWrongInfoSuccess =
      'Laporan dikirim. Lapangan dengan > 3 laporan akan ditandai untuk ditinjau.';
  static const String man08FlaggedForReviewBadge =
      'Ditandai untuk ditinjau (>3 laporan)';
  static const String man08ProposeTitle = 'Usulkan Lapangan Baru';
  static const String man08CourtNameLabel =
      'Nama Lapangan / Fasilitas Olahraga';
  static const String man08CourtAddressLabel = 'Alamat Lengkap';
  static const String man08CourtPriceLabel =
      'Perkiraan Tarif (contoh: Rp50.000/jam)';
  static const String man08CourtHoursLabel = 'Jam Buka (contoh: 07.00 - 22.00)';
  static const String man08SubmitProposeBtn = 'Kirim Usulan (Antrean Moderasi)';
  static const String man08ProposedToast =
      'Usulan lapangan dikirim ke antrean moderasi.';

  static const String man09TabCreated = 'Dibuat';
  static const String man09TabJoined = 'Diikuti';
  static const String man09EmptyCreated = 'Belum ada sesi yang kamu buat.';
  static const String man09EmptyJoined = 'Belum ada sesi yang kamu ikuti.';

  static const String man03VenueModeLabel = 'Lokasi Sesi';
  static const String man03CityLabel = 'Kota / Area Sesi';
  static const String man03CustomTimeBtn = 'Pilih Tanggal & Jam Lain';
  static const String man03CommunitySelectLabel = 'Pilih Komunitas';
  static const String man03NoCommunitiesHint =
      'Belum ada komunitas yang tersedia.';
  static const String man03NoCourtsInCityHint =
      'Belum ada lapangan terdaftar di kota ini. Gunakan tempat umum.';
  static const String man04HostLabel = 'Host Sesi';
  static const String man04NotesLabel = 'Catatan Sesi';
  static const String man04EditScheduleDialogTitle = 'Ubah Jadwal / Lokasi';
  static const String man04Delay1HourBtn = 'Tunda +1 Jam';
  static const String man04Delay1DayBtn = 'Geser +1 Hari';
  static const String man05ApproveBtn = 'Terima';
  static const String man05RejectBtn = 'Tolak';
  static const String man05HostBadge = 'Host';
  static const String man05JoinedBadge = 'Bergabung';
  static const String man05AttendedBadge = 'Hadir';
  static const String man05AbsentBadge = 'Tidak Hadir';
  static const String man06UnpaidBadge = 'Belum lunas';
  static const String man08MapLaunchError =
      'Tidak dapat membuka aplikasi peta eksternal.';
  static const String man08SupportedSportsLabel = 'Olahraga Tersedia';
  static const String man08CityLabel = 'Kota';

  // ── Pesan (Prompt 8: PSN-01 .. PSN-06) ─────────────────────────────────────
  static const String psn01RequestsBannerTitle = 'Permintaan Pesan';
  static String psn01RequestsCountLabel(int count) =>
      '$count permintaan menunggu';
  static const String psn01EmptyMessage =
      'Belum ada percakapan. Mulai kenalan atau ikuti aktivitas untuk mengirim pesan.';
  static const String psn01EmptyAction = 'Jelajahi Sekitar';
  static const String psn01PhotoPreview = 'Mengirim foto';
  static const String psn01DeletedPreview = 'Pesan ini telah dihapus';
  static const String psn01MutedTooltip = 'Percakapan dibisukan';
  static const String psn01ReadOnlyBadge = 'Baca-saja';

  static const String psn02EmptyMessage = 'Tidak ada permintaan pesan baru.';
  static const String psn02AcceptBtn = 'Terima';
  static const String psn02DeleteBtn = 'Hapus';
  static const String psn02BlockBtn = 'Blokir';
  static const String psn02OneMessageLimitHint =
      'Pengirim hanya dapat mengirim maksimal 1 pesan teks sampai kamu menerimanya.';

  static const String psn03DeletedUserLabel = 'Pengguna terhapus';
  static const String psn03ChatBlockedBanner =
      'Percakapan ini ditutup karena salah satu pengguna diblokir.';
  static const String psn03DeletedUserBanner =
      'Lawan bicara telah menghapus akunnya. Kamu tidak dapat mengirim pesan baru.';
  static const String psn03ScamWarningBanner =
      'Peringatan keamanan: Jangan mentransfer uang atau mengklik tautan mencurigakan dari orang yang belum kamu kenal.';
  static const String psn03ReadOnlySessionBanner =
      'Grup sesi ini berstatus baca-saja (24 jam setelah sesi selesai).';
  static const String psn03ComposerHint =
      'Tulis pesan (maks. 2.000 karakter)...';
  static const String psn03SendBtnTooltip = 'Kirim pesan';
  static const String psn03PickPhotoTooltip = 'Kirim foto (maks. 5 MB)';
  static const String psn03PhotoTooLargeError =
      'Ukuran foto chat maksimal 5 MB.';
  static const String psn03MenuInfo = 'Info Percakapan';
  static const String psn03MenuReport = 'Laporkan';
  static const String psn03MenuBlock = 'Blokir';
  static const String psn03ReplyAction = 'Balas';
  static const String psn03DeleteForMeAction = 'Hapus untuk saya';
  static const String psn03DeleteForEveryoneAction =
      'Hapus untuk semua (1 jam)';
  static const String psn03ReportMessageAction = 'Laporkan pesan';
  static const String psn03ReportedMessageToast =
      'Pesan dilaporkan. Salinan disimpan 30 hari untuk tinjauan moderasi.';
  static const String psn03FailedSendLabel = 'Gagal terkirim';
  static const String psn03StatusSent = 'Terkirim';
  static const String psn03StatusDelivered = 'Diterima';
  static const String psn03StatusRead = 'Dibaca';
  static const String psn03ReplyingToLabel = 'Membalas pesan:';
  static const String psn03QuickGreetingDefault = 'Horas!';
  static const String psn03QuickGreetingThanks = 'Mauliate!';
  static String psn03QuickGreetingRelation(String callTerm) =>
      'Horas, $callTerm!';
  static const String psn03ReadReceiptsOffHint =
      'Laporan dibaca dinonaktifkan di pengaturan privasi.';

  static const String psn04PinnedAnnouncementTitle = 'Pengumuman Disematkan';
  static const String psn04SendAnnouncementBtn = 'Kirim Pengumuman';
  static const String psn04AnnouncementHint =
      'Tulis pengumuman resmi yang akan disematkan di grup...';
  static const String psn04AdminDeleteMessageAction = 'Hapus pesan (Admin)';
  static const String psn04AdminKickMemberAction = 'Keluarkan dari grup';
  static const String psn04AdminKickConfirmTitle = 'Keluarkan Anggota Grup?';
  static const String psn04AdminKickConfirmBody =
      'Anggota ini akan dikeluarkan dari percakapan grup.';

  static const String psn05MembersSection = 'Anggota Percakapan';
  static const String psn05MuteSection = 'Bisukan Notifikasi';
  static const String psn05Mute1Hour = '1 jam';
  static const String psn05Mute8Hours = '8 jam';
  static const String psn05Mute1Week = '1 minggu';
  static const String psn05MuteForever = 'Selamanya';
  static const String psn05UnmuteBtn = 'Bunyikan Kembali';
  static const String psn05LeaveGroupBtn = 'Keluar dari Grup';
  static const String psn05LeaveGroupTitle = 'Keluar dari Grup?';
  static const String psn05LeaveGroupBody =
      'Kamu dapat keluar dari grup percakapan ini kapan saja.';
  static const String psn05MutedActiveToast = 'Percakapan dibisukan.';
  static const String psn05UnmutedToast = 'Notifikasi percakapan diaktifkan.';

  static const String psn06SharePhotoBtn = 'Bagikan Foto';
  static const String psn06ShareTextTemplate =
      'Foto dibagikan dari chat HORAS.';
  static const String psn06ShareUnavailableToast =
      'Berbagi gambar hanya tersedia di perangkat seluler.';

  // ── Akun (Prompt 9: AKN-01 .. AKN-15) ──────────────────────────────────────
  static const String akn01TabPosts = 'Postingan';
  static const String akn01TabSaved = 'Tersimpan';
  static const String akn01FollowersCountLabel = 'Pengikut';
  static const String akn01FollowingCountLabel = 'Mengikuti';
  static const String akn01ConnectionsCountLabel = 'Kenalan';
  static const String akn01ConnectionsShortcut = 'Kenalan Saya';
  static const String akn01EmptyPosts = 'Kamu belum membuat postingan.';
  static const String akn01EmptySaved = 'Belum ada postingan tersimpan.';

  static const String akn02PickPhotoBtn = 'Ubah Foto Profil';
  static const String akn02NameLabel = 'Nama Tampil (2-40 karakter)';
  static const String akn02NameCooldownInfo =
      'Nama tampil hanya dapat diubah maksimal sekali per 30 hari.';
  static const String akn02BioLabel = 'Bio (Maks. 150 karakter)';
  static const String akn02CityLabel = 'Kota Domisili';
  static const String akn02SubdistrictLabel = 'Kecamatan';
  static const String akn02HobbiesLabel = 'Minat & Hobi (pisahkan koma)';
  static const String akn02CampusOfficeLabel = 'Kampus / Kantor';
  static const String akn02WebsiteLabel = 'Satu Tautan Opsional';
  static const String akn02LockedIdentityTitle = 'Data Identitas Terkunci';
  static const String akn02LockedIdentityHint =
      'Marga, sub-suku, dan jenis kelamin terkunci. Ubah lewat Hubungi dukungan.';
  static const String akn02PhoneHint =
      'Nomor HP hanya dapat diganti melalui menu Keamanan (AKN-09).';
  static const String akn02SavedToast = 'Profil berhasil diperbarui.';

  static const String akn05EmptyFollowers = 'Belum ada pengikut.';
  static const String akn06EmptyFollowing = 'Belum mengikuti siapa pun.';
  static const String akn06UnfollowBtn = 'Berhenti ikuti';

  static const String akn07AppearanceSection = 'Tampilan & Bahasa';
  static const String akn07ThemeModeLabel = 'Mode Tampilan';
  static const String akn07ThemeSystem = 'Sistem';
  static const String akn07ThemeLight = 'Terang';
  static const String akn07ThemeDark = 'Gelap';
  static const String akn07LanguageLabel = 'Bahasa Aplikasi';
  static const String akn07LanguageValue = 'Indonesia';
  static const String akn07AccountSection = 'Akun & Keamanan';
  static const String akn07SupportSection = 'Bantuan & Info';

  static const String akn08PublicInfoNote =
      'Nama, foto, marga, dan kota selalu terlihat oleh pengguna terdaftar HORAS.';
  static const String akn08AccountTypeLabel = 'Tipe Akun';
  static const String akn08PublicAccount = 'Publik';
  static const String akn08PrivateAccount = 'Privat';
  static const String akn08FieldMotherMarga = 'Marga Ibu';
  static const String akn08FieldAgeGroup = 'Kelompok Usia (dari tahun lahir)';
  static const String akn08FieldSubdistrict = 'Kecamatan';
  static const String akn08FieldCommunities = 'Komunitas yang Diikuti';
  static const String akn08FieldHomeChurch = 'Gereja Asal (Opt-in)';
  static const String akn08FieldTarombo = 'Pohon Tarombo';
  static const String akn08DiscoverableLabel =
      'Tampil di Sekitar dan Pencarian';
  static const String akn08WhoCanConnectLabel =
      'Siapa yang Dapat Mengirim Kenalan';
  static const String akn08SharedContextMsgLabel =
      'Izinkan Pesan dari Konteks Bersama';
  static const String akn08ReadReceiptsLabel = 'Kirim Tanda Terbaca';
  static const String akn08VisEveryone = 'Semua Pengguna';
  static const String akn08VisConnected = 'Hanya Terhubung';
  static const String akn08VisOnlyMe = 'Hanya Saya';
  static const String akn08VisSameMargaOrComm = 'Semarga / Sekomunitas';
  static const String akn08SavedToast = 'Pengaturan privasi disimpan.';

  static const String akn09ActiveDevicesSection = 'Perangkat Aktif (Maks. 3)';
  static const String akn09RevokeDeviceBtn = 'Keluarkan';
  static const String akn09CurrentDeviceBadge = 'Perangkat ini';
  static const String akn09ChangePhoneSection = 'Ganti Nomor HP (Dual OTP)';
  static const String akn09OldPhoneLabel = 'Nomor HP Lama (+62...)';
  static const String akn09OldOtpLabel = 'Kode OTP Nomor Lama';
  static const String akn09NewPhoneLabel = 'Nomor HP Baru (+62...)';
  static const String akn09NewOtpLabel = 'Kode OTP Nomor Baru';
  static const String akn09ChangePhoneBtn = 'Ganti Nomor Sekarang';
  static const String akn09ChangePhoneSuccessToast =
      'Nomor HP berhasil diganti.';
  static const String akn09LoginHistorySection =
      'Riwayat Masuk 30 Hari Terakhir';
  static const String akn09LogoutBtn = 'Keluar dari Akun';

  static const String akn10QuietHoursTitle = 'Jam Tenang (22.00 – 06.00)';
  static const String akn10QuietHoursDesc =
      'Berlaku untuk seluruh notifikasi kecuali keamanan akun.';
  static const String akn10LockedSecurityNote =
      'Notifikasi Keamanan Akun dan Tindakan Moderasi terkunci aktif demi keselamatan akun.';
  static const String akn10SavedToast = 'Preferensi notifikasi disimpan.';

  static const String akn11EmptyBlocked = 'Tidak ada pengguna yang diblokir.';
  static const String akn11UnblockBtn = 'Buka blokir';
  static const String akn11UnblockConfirmTitle = 'Buka Blokir Pengguna?';
  static const String akn11UnblockConfirmBody =
      'Pengguna ini dapat melihat profilmu lagi, namun hubungan Kenalan/Ikuti sebelumnya tidak dipulihkan otomatis.';

  static const String akn12TabConnected = 'Terhubung';
  static const String akn12TabIncoming = 'Permintaan Masuk';
  static const String akn12TabOutgoing = 'Terkirim';
  static const String akn12EmptyConnected = 'Belum ada kenalan terhubung.';
  static const String akn12EmptyIncoming = 'Tidak ada permintaan masuk.';
  static const String akn12EmptyOutgoing = 'Tidak ada permintaan terkirim.';

  static const String akn13InfoText =
      'Unduh arsip profil, postingan, dan tarombo dalam format ZIP (JSON). Maksimal sekali per 7 hari; tautan berlaku 7 hari dan dikirim dalam 48 jam.';
  static const String akn13OtpLabel = 'Kode OTP Verifikasi (dev: 123456)';
  static const String akn13RequestBtn = 'Buat & Unduh Arsip ZIP';
  static const String akn13ShareZipBtn = 'Bagikan / Simpan File ZIP';
  static const String akn13JobReadyStatus =
      'Arsip ZIP siap diunduh dan dibagikan (tautan berlaku 7 hari).';
  static const String akn13JobProcessingStatus =
      'Status: Diproses (dikirim dalam 48 jam).';

  static const String akn14ConsequenceTitle = 'Konsekuensi Hapus Akun';
  static const String akn14ConsequenceBody =
      '• Komunitas yang kamu miliki harus diserahkan dulu sebelum hapus akun.\n'
      '• Masa tunggu 30 hari: login ulang dalam 30 hari membatalkan penghapusan.\n'
      '• Setelah 30 hari, profil, postingan, foto, dan tarombo dihapus permanen.\n'
      '• Pesan lama tetap tampil ke lawan bicara sebagai "Pengguna terhapus".';
  static const String akn14OtpLabel = 'Konfirmasi OTP Hapus Akun (dev: 123456)';
  static const String akn14ConfirmBtn =
      'Ajukan Hapus Akun (Masa Tunggu 30 Hari)';
  static const String akn14PendingBanner =
      'Penghapusan akun dijadwalkan (masa tunggu 30 hari). Login kembali sebelum 30 hari akan membatalkannya.';
  static const String akn14CancelDeletionBtn = 'Batalkan Penghapusan Akun';
  static const String akn14CancelledScreenTitle = 'Penghapusan dibatalkan';
  static const String akn14CancelledScreenBody =
      'Karena kamu masuk kembali sebelum masa tunggu 30 hari berakhir, permintaan penghapusan akunmu otomatis dibatalkan.';
  static const String akn14TransferCommunityBtn = 'Kelola Komunitas Saya';

  static const String akn15LicenseBtn = 'Lihat Lisensi Open Source';
  static const String akn15PrivacyPolicyBtn = 'Kebijakan Privasi & Syarat';
  static const String akn15GuidelinesBtn = 'Pedoman Komunitas';
  static String akn15VersionText(String version, String buildNumber) =>
      'Versi $version (build $buildNumber)';

  // ── Sistem (Prompt 9: SIS-01 .. SIS-08) ────────────────────────────────────
  static const String sis01MarkAllReadBtn = 'Tandai Semua Dibaca';
  static const String sis01GroupToday = 'Hari ini';
  static const String sis01GroupThisWeek = 'Minggu ini';
  static const String sis01GroupEarlier = 'Sebelumnya';
  static const String sis01EmptyMessage =
      'Belum ada notifikasi dalam 90 hari terakhir.';

  static const String sis02ReporterPrivacyNote =
      'Identitas pelapor dirahasiakan dan tidak pernah diberitahukan kepada terlapor. Maksimal 20 laporan per hari dan 1 laporan aktif per target.';
  static const String sis02CategoryLabel = 'Kategori Laporan';
  static const String sis02NoteLabel = 'Catatan Tambahan (Opsional, maks. 500)';
  static const String sis02AlsoBlockLabel = 'Blokir pengguna ini juga';
  static const String sis02SubmitBtn = 'Kirim Laporan';
  static const String sis02SuccessToast =
      'Laporan dikirim dengan status Diterima.';

  static const String sis03EmptyReports = 'Belum ada laporan yang kamu kirim.';
  static const String sis04SearchHint = 'Cari pertanyaan atau topik bantuan...';
  static const String sis04EmptyArticles = 'Tidak ada artikel yang cocok.';

  static const String sis05CategoryGeneral = 'Pertanyaan / Keluhan Umum';
  static const String sis05CategoryIdentity =
      'Ubah Marga / Sub-suku / Jenis Kelamin';
  static const String sis05CategoryAppeal =
      'Banding Sanksi / Akun Ditangguhkan (14 hari)';
  static const String sis05CategoryLabel = 'Kategori Dukungan';
  static const String sis05MessageLabel = 'Jelaskan Keluhan / Bukti Banding';
  static const String sis05EmailLabel = 'Email Balasan Opsional';
  static const String sis05AttachPhotoBtn = 'Lampirkan Foto Bukti (Opsional)';
  static const String sis05SubmitBtn = 'Kirim ke Dukungan HORAS';
  static const String sis05SuccessToast =
      'Tiket dukungan / banding berhasil dikirim.';

  static const String sis06CommunityLabel = 'Pilih Komunitas';
  static const String sis06TypeLabel = 'Tipe Pengajuan: Komunitas / Punguan';
  static const String sis06EvidenceLabel =
      'Bukti (surat penunjukan/keterangan pengurus, atau konfirmasi pengurus pusat)';
  static const String sis06ContactLabel = 'Kontak Pengurus Resmi';
  static const String sis06SubmitBtn = 'Ajukan Verifikasi Komunitas';
  static const String sis06SuccessToast =
      'Pengajuan verifikasi komunitas dikirim.';
  static const String sis06StatusShortcutBtn = 'Lihat Status Verifikasi Saya';

  static const String sis07EmptyRequests =
      'Belum ada pengajuan verifikasi komunitas.';
  static String sis07RejectionReason(String reason) =>
      'Alasan penolakan: $reason';

  static const String sis08PublicReadNotice =
      'Pedoman Komunitas HORAS dapat dibaca bebas tanpa login (SIS-R7).';
}
