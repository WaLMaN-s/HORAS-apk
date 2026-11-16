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
}
