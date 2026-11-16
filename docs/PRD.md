# PRD HORAS: Product Requirements Document

**Satu Aplikasi, Satu Keluarga Orang Batak.**

Versi 1.0 (revisi dari draf awal) · 16 November 2026 · Android dan iOS · Dokumen pendamping: SDD (desain teknis)

Dokumen ini menjadi dasar perancangan UI/UX, pengembangan aplikasi, database, API, pengujian, dan evaluasi produk. Tujuannya memastikan seluruh halaman, fungsi, alur pengguna, aturan bisnis, dan batasan sistem punya penjelasan yang dapat diperiksa dan dipertanggungjawabkan kepada developer maupun pihak berkepentingan.

---

## 0. Catatan Revisi dari Draf Awal

Draf awal berhenti di inventaris halaman dan belum memuat spesifikasi. Perbaikan yang dilakukan:

| # | Temuan di draf awal | Perbaikan |
| --- | --- | --- |
| 1 | Berhenti di inventaris; belum ada spesifikasi, aturan bisnis, alur, kriteria penerimaan | Ditambahkan bagian 6 sampai 15 |
| 2 | Inventaris hanya berupa jumlah dan kategori (Feed, story, dst.) | Tiap halaman diberi ID, tujuan, dan fase rilis (bagian 5) |
| 3 | **Chat tidak ada** di navigasi maupun inventaris, padahal fitur wajib | Ditambah modul **Pesan** (6 halaman), diakses dari bilah atas. Total halaman 69 menjadi **75** |
| 4 | Lupa sandi ada di Autentikasi, padahal login memakai nomor HP + OTP (tanpa sandi) | Diganti **Pemulihan akun**; perlu konfirmasi (keputusan K1) |
| 5 | Beranda dengan story, video, dan postingan melebarkan cakupan jauh dari konsep awal (alat dulu, feed belakangan) | Difasekan: v1 feed ringan, story dan video di v2 (bagian 3) |
| 6 | Pengikut disebut, tetapi hubungan Kenalan (syarat chat) tidak didefinisikan | Dua mekanisme didefinisikan: **Ikuti** dan **Terhubung** (bagian 6.3) |
| 7 | Tidak ada pembeda peran (pengurus, admin gereja, moderator, reviewer adat) | Ditambahkan matriks peran (bagian 2.2) |
| 8 | Tidak ada batas angka (OTP, permintaan, postingan, sesi) | Ditambahkan tabel batas (bagian 7.2) |
| 9 | Keadaan kosong, error, dan izin sistem belum diatur | Ditambahkan ketentuan status standar (bagian 5.2) |
| 10 | Teks pemberitahuan batas pembuatan gambar ikut tercantum | Dihapus; bukan bagian PRD |

---

## 1. Gambaran Umum Aplikasi

| Item | Isi |
| --- | --- |
| Nama | HORAS |
| Tagline | Satu Aplikasi, Satu Keluarga Orang Batak |
| Platform | Android dan iOS (disarankan satu basis kode, Flutter) |
| Jenis | Jejaring sosial, komunitas, kekerabatan, dan aktivitas masyarakat Batak |
| Wilayah | Indonesia dan diaspora (nomor HP dengan kode negara didukung) |
| Bahasa antarmuka | Indonesia (istilah Batak sebagai konten) |
| Usia minimum | 17 tahun |

HORAS menghubungkan masyarakat Batak di berbagai daerah melalui identitas marga, sub-suku, tarombo, partuturan, pertemanan, komunitas, gereja, dan aktivitas bersama. HORAS bukan sekadar media sosial: pembedanya adalah **integrasi hubungan kekerabatan ke dalam aktivitas sosial pengguna**.

### 1.1 Tujuan Utama dan Cara Mengukurnya

| # | Tujuan | Wujud di produk | Indikator (target beta, dapat disesuaikan) |
| --- | --- | --- | --- |
| 1 | Menghubungkan orang Batak di seluruh Indonesia dan luar negeri | Sekitar, Kenalan, Pesan | Permintaan kenalan diterima di atas 50% |
| 2 | Membantu mengenali marga dan partuturan | Tarombo, badge partuturan | Di atas 30% pengguna aktif mingguan membuka detail hubungan |
| 3 | Berbagi foto, video, cerita, informasi | Beranda | Di atas 20% pengguna aktif memposting minimal sekali sebulan |
| 4 | Mencari teman dan komunitas sekitar | Sekitar | Di atas 50% pengguna bergabung ke minimal satu komunitas |
| 5 | Pusat informasi punguan dan gereja | Komunitas, Gereja, Kegiatan | Jumlah kegiatan dibuat per bulan dan tingkat RSVP |
| 6 | Aktivitas olahraga dan pertemuan | Main | Sesi terisi penuh di atas 60% |
| 7 | Melestarikan budaya dan kekeluargaan | Tarombo, kamus partuturan | Penggunaan kamus dan kelengkapan tarombo |

### 1.2 Prinsip Dasar dan Konsekuensi Desainnya

| Prinsip | Konsekuensi yang dapat diuji |
| --- | --- |
| Identitas budaya Batak menjadi inti | Marga dan sub-suku wajib saat daftar; badge partuturan tampil konsisten di profil, chat, anggota, peserta |
| Hubungan kekerabatan tidak ditentukan sembarangan | Aturan berversi dan divalidasi reviewer adat; tiga tingkat keyakinan; hasil tidak pasti ditulis kemungkinan; konfirmasi dua pihak |
| Pengguna mengendalikan data dan privasinya | Privasi per bidang, default ketat, lokasi hanya level area, hapus akun dan unduh data |
| Informasi komunitas dan gereja dapat diverifikasi | Lencana Terverifikasi; label Belum diverifikasi untuk yang belum |
| Antarmuka sederhana, konsisten, mudah | Lima tab; komponen seragam; aksi utama dicapai maksimal 3 ketukan |
| Mendukung perbedaan sistem kekerabatan antar-sub-suku | Aturan per sub-suku; sub-suku tanpa aturan tervalidasi memakai mode netral (tanpa badge partuturan) |

### 1.3 Bukan Sasaran (Non-Goals) v1

- Pembayaran dalam aplikasi, marketplace, iklan.
- Telepon/video call dan siaran langsung.
- Penentu final hukum adat atau perjodohan. Aplikasi hanya memberi informasi dan peringatan.
- Aplikasi ibadah atau liturgi. Gereja hanya direktori dan informasi kegiatan.
- Algoritma rekomendasi feed yang kompleks (v1 kronologis).

---

## 2. Pengguna dan Peran

### 2.1 Persona

| Persona | Kebutuhan | Modul utama |
| --- | --- | --- |
| Perantau baru | Teman, komunitas, dan gereja di kota baru | Sekitar, Main |
| Naposo/mahasiswa | Kenalan, olahraga, tahu cara memanggil kerabat | Tarombo, Main, Pesan |
| Pengurus punguan/komunitas | Mengumpulkan anggota, mengumumkan kegiatan | Sekitar (Komunitas), Beranda |
| Diaspora/orang tua | Terhubung dengan keluarga besar, melestarikan tarombo | Tarombo, Beranda |

### 2.2 Peran Sistem dan Hak Akses

Peran Pengurus komunitas dan Admin gereja berlaku per entitas, bukan global. Moderator, Reviewer adat, dan Admin bekerja lewat panel admin web (lihat SDD bagian 6.10).

| Aksi | Tamu | Pengguna | Pengurus komunitas | Admin gereja | Moderator | Reviewer adat | Admin |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Lihat feed, profil, Sekitar | — | ✓ | ✓ | ✓ | — | — | — |
| Posting, komentar, ikuti | — | ✓ | ✓ | ✓ | — | — | — |
| Kenalan dan pesan | — | ✓ | ✓ | ✓ | — | — | — |
| Buat komunitas (akun minimal 7 hari) | — | ✓ | ✓ | ✓ | — | — | — |
| Kelola anggota dan kegiatan komunitas | — | — | ✓ | — | — | — | ✓ |
| Kelola profil dan kegiatan gereja | — | — | — | ✓ | — | — | ✓ |
| Buat sesi main | — | ✓ | ✓ | ✓ | — | — | — |
| Tinjau dan tindak laporan | — | — | — | — | ✓ | — | ✓ |
| Setujui/ubah aturan partuturan | — | — | — | — | — | ✓ | ✓ |
| Kelola master marga, area, lapangan | — | — | — | — | — | — | ✓ |
| Lihat log audit | — | — | — | — | — | — | ✓ |

---

## 3. Strategi Fase Rilis

Cakupan penuh draf awal terlalu besar untuk satu rilis. Rekomendasi: v1 membuktikan nilai inti (kenal, tarombo, main, chat), lalu menambah konten dan verifikasi.

| Modul | Fase 1 (MVP, 12-14 minggu) | Fase 2 | Fase 3 |
| --- | --- | --- | --- |
| Autentikasi | Semua | Login sosial (opsional) |  |
| Beranda | Feed ringan (teks dan foto), suka, komentar, pencarian | Story, video, hashtag | Rekomendasi feed |
| Sekitar | Orang, komunitas dasar, kelola komunitas | Gereja + verifikasi, kegiatan + RSVP | Peta orang/lapangan |
| Tarombo | Dashboard, hubungan, konfirmasi, pohon ringkas (3 generasi) | Kamus partuturan, sub-suku tambahan | Pohon penuh dan edit |
| Main | Semua halaman | Sesi berulang, peta lapangan | Turnamen kecil, iuran |
| Pesan | Pribadi, grup, permintaan pesan | Voice note, stiker |  |
| Akun dan Sistem | Semua |  |  |

Alasan Beranda dibatasi di v1: feed yang sepi tampak mati; story dan video menambah biaya penyimpanan dan beban moderasi; dan itu menempatkan HORAS berhadapan langsung dengan platform raksasa. Kekuatan v1 ada pada Tarombo, Sekitar, Main, dan Pesan.

---

## 4. Navigasi Utama

Lima tab di bilah bawah.

| Tab | Sublabel | Isi |
| --- | --- | --- |
| Beranda | Sosial | Feed, story, postingan, komentar, pencarian, unggah |
| Sekitar | Penemuan | Orang, komunitas, gereja, kegiatan |
| Tarombo | Keluarga | Silsilah, hubungan partuturan, konfirmasi |
| Main | Aktivitas | Sesi olahraga, lapangan |
| Akun | Pengaturan | Profil, kenalan, privasi, keamanan, bantuan |

**Ketentuan:**

1. Komunitas dan gereja berada di dalam Sekitar; pengaturan dan edit profil di dalam Akun; story dan postingan di dalam Beranda.
2. **Pesan dan Notifikasi** diakses dari ikon di bilah atas Beranda (ikon Notifikasi juga ada di bilah atas tab lain). Lencana angka muncul bila ada yang belum dibaca.
3. Tombol tambah (+) di Beranda membuka pilihan Postingan atau Story (Story fase 2). Tombol buat sesi ada di tab Main.
4. Badge partuturan harus tampil pada: profil orang lain, header chat, daftar anggota komunitas, daftar peserta sesi, kartu orang di Sekitar.
5. Tab terakhir yang dibuka diingat selama sesi; ketukan ulang pada tab kembali ke halaman awal tab dan menggulung ke atas.
6. Setiap halaman utama dapat dibuka lewat tautan dalam (deep link) dari notifikasi.

---

## 5. Inventaris Halaman

Fase: 1 = MVP, 2 = rilis berikutnya, 3 = rilis lanjutan. **Total 75 halaman** (69 dari draf awal + 6 Pesan). Subhalaman, dialog konfirmasi, dan variasi status tetap harus dirancang dan mengikuti ketentuan 5.2.

| Modul | Jumlah |
| --- | --- |
| Autentikasi | 7 |
| Beranda | 10 |
| Sekitar | 12 |
| Tarombo | 8 |
| Main | 9 |
| Pesan (tambahan) | 6 |
| Akun | 15 |
| Sistem | 8 |
| **Total** | **75** |

### 5.1 Daftar per Modul

**Autentikasi (AUT)**

| ID | Halaman | Tujuan | Fase |
| --- | --- | --- | --- |
| AUT-01 | Splash | Memuat aplikasi, memeriksa sesi login | 1 |
| AUT-02 | Pengenalan | Tiga layar nilai produk (kenal, tarombo, main) | 1 |
| AUT-03 | Masuk | Input nomor HP | 1 |
| AUT-04 | Daftar | Persetujuan kebijakan, pedoman, konfirmasi usia 17+ | 1 |
| AUT-05 | Verifikasi OTP | Input kode 6 digit | 1 |
| AUT-06 | Onboarding profil | Empat langkah: nama dan foto, jenis kelamin dan tahun lahir, marga dan sub-suku, domisili dan minat | 1 |
| AUT-07 | Pemulihan akun | Mengganti nomor atau memulihkan akses | 1 |

**Beranda (BER)**

| ID | Halaman | Tujuan | Fase |
| --- | --- | --- | --- |
| BER-01 | Feed | Daftar postingan dan baris story | 1 |
| BER-02 | Penampil story | Menonton story | 2 |
| BER-03 | Buat story | Membuat story foto/video | 2 |
| BER-04 | Buat postingan | Teks, foto, visibilitas | 1 |
| BER-05 | Pilih dan edit media | Pangkas dan urutkan foto (video di fase 2) | 1 |
| BER-06 | Detail postingan | Satu postingan lengkap | 1 |
| BER-07 | Komentar | Daftar dan tulis komentar | 1 |
| BER-08 | Daftar suka | Siapa yang menyukai | 1 |
| BER-09 | Pencarian | Kolom cari, riwayat, saran | 1 |
| BER-10 | Hasil pencarian | Tab Orang, Komunitas, Gereja, Postingan | 1 |

**Sekitar (SEK)**

| ID | Halaman | Tujuan | Fase |
| --- | --- | --- | --- |
| SEK-01 | Sekitar (utama) | Segmen Orang, Komunitas, Gereja | 1 |
| SEK-02 | Daftar orang sekitar | Kartu orang dengan badge partuturan | 1 |
| SEK-03 | Filter orang | Marga, kota, kampus/kantor, hobi | 1 |
| SEK-04 | Profil orang lain | Profil, badge, aksi Ikuti/Kenalan/Pesan | 1 |
| SEK-05 | Daftar komunitas | Jelajah dan cari komunitas | 1 |
| SEK-06 | Detail komunitas | Info, anggota, pengumuman, kegiatan | 1 |
| SEK-07 | Buat komunitas | Formulir pembuatan | 1 |
| SEK-08 | Kelola komunitas | Anggota, permintaan gabung, peran, pengumuman | 1 |
| SEK-09 | Detail kegiatan | Info kegiatan dan RSVP | 2 |
| SEK-10 | Daftar gereja | Direktori dan filter | 2 |
| SEK-11 | Detail gereja | Jadwal, kontak, kegiatan, jemaat di HORAS | 2 |
| SEK-12 | Pencarian Sekitar | Cari orang dan komunitas (gereja di fase 2) | 1 |

**Tarombo (TAR)**

| ID | Halaman | Tujuan | Fase |
| --- | --- | --- | --- |
| TAR-01 | Dashboard Tarombo | Ringkasan identitas, kelengkapan, saran kerabat, permintaan konfirmasi | 1 |
| TAR-02 | Pohon silsilah | Tampilan pohon; ringkas 3 generasi di fase 1, penuh di fase 3 | 1 |
| TAR-03 | Tambah/ubah anggota keluarga | Fase 1: ayah, ibu, kakek dari ayah; penuh di fase 3 | 1 |
| TAR-04 | Detail anggota | Data satu anggota tarombo | 1 |
| TAR-05 | Detail hubungan | Panggilan, penjelasan jalur, tingkat keyakinan | 1 |
| TAR-06 | Cek partuturan | Pilih dua orang, lihat hubungannya | 1 |
| TAR-07 | Konfirmasi hubungan | Kirim/terima/tolak pengakuan kerabat | 1 |
| TAR-08 | Kamus partuturan | Cari istilah dan maknanya | 2 |

**Main (MAN)**

| ID | Halaman | Tujuan | Fase |
| --- | --- | --- | --- |
| MAN-01 | Main (utama) | Daftar sesi di sekitar | 1 |
| MAN-02 | Filter sesi | Olahraga, hari, level, jarak, biaya | 1 |
| MAN-03 | Buat sesi | Formulir sesi | 1 |
| MAN-04 | Detail sesi | Info, gabung/keluar | 1 |
| MAN-05 | Peserta dan daftar tunggu | Daftar peserta dengan badge | 1 |
| MAN-06 | Patungan | Biaya per orang dan status bayar | 1 |
| MAN-07 | Daftar lapangan | Lapangan yang sering dipakai | 1 |
| MAN-08 | Detail/usul lapangan | Info lapangan, usulkan lapangan baru | 1 |
| MAN-09 | Riwayat sesi saya | Sesi yang dibuat dan diikuti | 1 |

**Pesan (PSN), tambahan dari revisi**

| ID | Halaman | Tujuan | Fase |
| --- | --- | --- | --- |
| PSN-01 | Daftar pesan | Semua percakapan | 1 |
| PSN-02 | Permintaan pesan | Pesan dari orang yang belum terhubung | 1 |
| PSN-03 | Chat pribadi | Percakapan satu lawan satu | 1 |
| PSN-04 | Chat grup | Grup komunitas dan sesi | 1 |
| PSN-05 | Info percakapan | Anggota, bisukan, keluar, lapor | 1 |
| PSN-06 | Penampil media | Foto dalam chat | 1 |

**Akun (AKN)**

| ID | Halaman | Tujuan | Fase |
| --- | --- | --- | --- |
| AKN-01 | Profil saya | Tampilan profil sendiri | 1 |
| AKN-02 | Edit profil | Ubah bio, foto, domisili, hobi | 1 |
| AKN-03 | Postingan saya | Daftar postingan sendiri | 1 |
| AKN-04 | Tersimpan | Postingan yang disimpan | 1 |
| AKN-05 | Pengikut | Daftar pengikut | 1 |
| AKN-06 | Mengikuti | Daftar yang diikuti | 1 |
| AKN-07 | Pengaturan | Menu pengaturan utama, mode gelap | 1 |
| AKN-08 | Privasi | Visibilitas per bidang | 1 |
| AKN-09 | Keamanan | Perangkat aktif, ganti nomor | 1 |
| AKN-10 | Pengaturan notifikasi | Preferensi per jenis, jam tenang | 1 |
| AKN-11 | Pengguna diblokir | Daftar dan buka blokir | 1 |
| AKN-12 | Kenalan saya | Daftar terhubung dan permintaan | 1 |
| AKN-13 | Data saya | Unduh data | 1 |
| AKN-14 | Hapus akun | Alur penghapusan | 1 |
| AKN-15 | Tentang HORAS | Versi, lisensi, kebijakan | 1 |

**Sistem (SIS)**

| ID | Halaman | Tujuan | Fase |
| --- | --- | --- | --- |
| SIS-01 | Notifikasi | Daftar notifikasi dalam aplikasi | 1 |
| SIS-02 | Laporkan | Formulir laporan untuk pengguna, konten, komunitas, sesi | 1 |
| SIS-03 | Status laporan saya | Riwayat dan hasil laporan | 1 |
| SIS-04 | Pusat bantuan | Artikel dan pertanyaan umum | 1 |
| SIS-05 | Hubungi dukungan | Kirim keluhan | 1 |
| SIS-06 | Ajukan verifikasi | Verifikasi komunitas (gereja di fase 2) | 1 |
| SIS-07 | Status verifikasi | Status pengajuan | 1 |
| SIS-08 | Pedoman komunitas | Aturan perilaku | 1 |

### 5.2 Ketentuan Status Standar (berlaku di setiap halaman)

| Status | Perilaku |
| --- | --- |
| Memuat | Kerangka (skeleton), bukan putaran layar penuh |
| Kosong | Satu kalimat penjelas dan satu tombol aksi, misal Belum ada sesi, buat yang pertama |
| Tanpa koneksi | Pesan jelas, tombol Coba lagi, tampilkan data tersimpan bila ada |
| Error server | Pesan umum dan kode referensi untuk dukungan |
| Izin ditolak (lokasi, kamera, galeri, notifikasi) | Jelaskan manfaatnya, tawarkan buka pengaturan, fitur tetap bisa dipakai tanpa izin bila memungkinkan |
| Konten tidak tersedia (dihapus, privat, pengguna memblokir) | Pesan netral tanpa membocorkan alasan |
| Akun dibatasi atau ditangguhkan | Layar penjelasan, alasan umum, jalur banding |
| Tindakan merusak (hapus, keluar grup, blokir) | Dialog konfirmasi dengan tombol berlabel jelas |
| Aksesibilitas | Ukuran teks dinamis, kontras cukup, label pembaca layar, target sentuh minimal 44 px |

---

## 6. Spesifikasi per Modul

Setiap aturan memiliki ID agar dapat dirujuk oleh desainer, developer, dan QA. Aturan di sini bersifat mengikat; angka batas dikumpulkan lagi di bagian 7.2.

### 6.1 Autentikasi (AUT)

| ID | Ketentuan |
| --- | --- |
| AUT-R1 | Login hanya dengan nomor HP + OTP; tidak ada sandi. Format E.164, +62 sebagai bawaan, kode negara lain didukung untuk diaspora. |
| AUT-R2 | OTP 6 digit, berlaku 5 menit, maksimal 5 kali salah, kirim ulang setelah 60 detik, maksimal 5 permintaan OTP per nomor per jam. Melewati batas: nomor dikunci 1 jam. |
| AUT-R3 | Satu nomor = satu akun. Nomor yang pernah diblokir permanen tidak dapat mendaftar. |
| AUT-R4 | Daftar memuat dua persetujuan terpisah (Kebijakan Privasi + Syarat Layanan; Pedoman Komunitas) dan pernyataan usia 17 tahun ke atas. Persetujuan pemrosesan data silsilah diminta terpisah saat pertama kali mengisi Tarombo, bukan di sini. |
| AUT-R5 | Onboarding 4 langkah. Wajib: nama tampil (2-40 karakter), jenis kelamin, tahun lahir (usia minimal 17), marga, sub-suku, domisili (kota/kecamatan). Opsional: foto, marga ibu, hobi, kampus/kantor. Onboarding dapat dilanjutkan bila aplikasi ditutup di tengah jalan. |
| AUT-R6 | Marga dipilih dari daftar baku (cari saat mengetik). Bila tidak ada, pilih Marga belum ada: masuk antrean verifikasi admin dan sementara tampil tanpa badge partuturan. |
| AUT-R7 | Marga, sub-suku, dan jenis kelamin terkunci setelah onboarding. Perubahan lewat Hubungi dukungan (mencegah penyalahgunaan badge partuturan). |
| AUT-R8 | Pemulihan akun: (a) nomor lama masih dipegang: ganti nomor dengan OTP ke nomor lama dan baru; (b) nomor lama hilang: pengajuan manual dengan bukti kepemilikan (tanggal daftar, marga, beberapa kenalan) yang ditinjau dukungan, target 3 hari kerja. |
| AUT-R9 | Maksimal 3 perangkat aktif. Login di perangkat ke-4 mengeluarkan perangkat tertua dan mengirim notifikasi keamanan. |
| AUT-R10 | Izin notifikasi dan lokasi perkiraan diminta setelah ada layar penjelas manfaat, bukan di splash. Aplikasi tetap berfungsi bila izin ditolak (area diisi manual). |

**Status khusus:** format nomor salah, OTP salah, OTP kedaluwarsa, nomor terkunci, tanpa koneksi, akun ditangguhkan (layar penjelasan dan jalur banding).

### 6.2 Beranda (BER)

| ID | Ketentuan |
| --- | --- |
| BER-R1 | Feed v1 kronologis menurun, berisi postingan dari akun yang diikuti, komunitas yang diikuti, dan diri sendiri. Postingan publik dari luar lingkaran itu ditemukan lewat Sekitar dan pencarian, bukan di feed. |
| BER-R2 | Isi postingan: teks maksimal 2.000 karakter; 0 sampai 10 foto (maksimal 10 MB per foto sebelum kompres; kompres di sisi klien). Minimal ada teks atau satu foto. Video (fase 2): maksimal 60 detik. |
| BER-R3 | Visibilitas: Publik, Pengikut saja, atau Komunitas tertentu (satu atau lebih komunitas yang diikuti). Bawaan mengikuti tipe akun: akun publik = Publik, akun privat = Pengikut saja. |
| BER-R4 | Metadata lokasi (EXIF) dihapus dari semua foto di server. Tag lokasi opsional dan hanya level kota. |
| BER-R5 | Komentar maksimal 1.000 karakter, balasan satu tingkat. Pembuat postingan dapat mematikan komentar dan menghapus komentar di postingannya; pemilik komentar dapat menghapus komentarnya. |
| BER-R6 | Satu suka per pengguna per postingan. Daftar suka tidak menampilkan akun yang saling memblokir dengan pelihat. |
| BER-R7 | Edit postingan: hanya teks, dengan label Diedit. Foto tidak dapat diganti (hapus dan unggah ulang). |
| BER-R8 | Hapus postingan bersifat langsung; komentar ikut terhapus. Bila ada laporan terbuka, salinan disimpan 30 hari untuk moderasi. |
| BER-R9 | Aksi pada postingan: suka, komentar, simpan, bagikan (salin tautan; tautan ke postingan terbatas tetap tidak dapat dibuka orang tanpa hak), laporkan, bisukan akun, blokir. |
| BER-R10 | Batas: 20 postingan per 24 jam, 60 komentar per jam. Postingan bertautan eksternal dari akun berusia kurang dari 7 hari ditahan untuk tinjauan otomatis. |
| BER-R11 | Filter kata dan deteksi spam berjalan sebelum tayang. Postingan yang ditahan terlihat oleh pembuatnya sebagai Sedang ditinjau. |
| BER-R12 | Story (fase 2): foto/video maksimal 15 detik, tayang 24 jam, hanya untuk pengikut, daftar penonton hanya terlihat pembuat, tidak dapat dibagikan ulang. |
| BER-R13 | Pencarian: orang (nama, marga), komunitas (nama, kota); gereja dan postingan publik di fase 2. Hasil menghormati blokir dan privasi. Pengguna bermode tersembunyi tidak muncul di pencarian kecuali bagi yang sudah terhubung. |

**Keadaan kosong:** feed kosong menampilkan ajakan Ikuti orang dan Gabung komunitas, disertai pintasan ke Sekitar.

### 6.3 Sekitar (SEK)

**Ikuti dan Terhubung adalah dua hal berbeda:**

|  | Ikuti | Terhubung (Kenalan) |
| --- | --- | --- |
| Sifat | Satu arah | Dua arah |
| Tujuan | Melihat postingan di feed | Membuka chat langsung dan bidang privasi untuk Terhubung |
| Persetujuan | Tidak untuk akun publik; ya untuk akun privat | Selalu |
| Batas harian | 200 ikuti baru | 10 permintaan baru |
| Berhenti | Berhenti ikuti | Hapus koneksi (tanpa pemberitahuan) |

| ID | Ketentuan |
| --- | --- |
| SEK-R1 | Daftar orang menampilkan pengguna di kota/kecamatan yang sama dengan pelihat, berdasarkan area di profil, bukan GPS. Pelihat dapat mengganti area (misal kota tujuan pindah). Urutan: kerabat (keyakinan tinggi/sedang), komunitas sama, hobi sama, aktivitas terbaru. 20 hasil per halaman. |
| SEK-R2 | Kartu orang menampilkan foto, nama, marga, kota, badge partuturan (bila ada), dan jumlah komunitas yang sama. Tidak menampilkan usia pasti, nomor HP, atau jarak presisi; jarak hanya berupa rentang (Di kotamu, Di kecamatanmu). |
| SEK-R3 | Pengguna dapat memilih tampil atau tersembunyi dari Sekitar (AKN-08). Bawaan: tampil, level kota. |
| SEK-R4 | Profil orang lain menampilkan bidang sesuai pengaturan privasi pemilik. Tombol: Ikuti, Kenalan, Pesan (aktif sesuai PSN-R1); menu: Laporkan, Blokir, Bisukan. Nomor HP tidak pernah ditampilkan. |
| SEK-R5 | Permintaan Kenalan membawa sapaan cepat atau pesan pengantar maksimal 200 karakter. Penerima dapat menerima, menolak, atau mengabaikan. Penolakan tidak diberitahukan ke pengirim. Permintaan tak ditanggapi kedaluwarsa 30 hari; pengirim tidak dapat mengirim ulang ke orang yang sama selama 30 hari setelah ditolak atau kedaluwarsa. |
| SEK-R6 | Bila marga pelihat dan target sama, kartu dan profil menampilkan label Semarga (dongan tubu) dengan penjelasan singkat. Ini informasi, bukan pemblokiran. HORAS tidak memiliki fitur pencocokan jodoh. |
| SEK-R7 | Komunitas berjenis: Punguan marga, Kota, Kampus/profesi, Minat (Gereja di fase 2). Akses: Terbuka (gabung langsung), Dengan persetujuan, Tertutup (hanya undangan, tidak muncul di pencarian). Nama 3-60 karakter, unik per jenis dan kota; deskripsi maksimal 500 karakter. |
| SEK-R8 | Pembuat komunitas: akun minimal 7 hari, maksimal 5 komunitas per akun. Pembuat menjadi Pemilik, dapat menunjuk Pengurus (maksimal 10). Pemilik tidak dapat keluar sebelum menyerahkan kepemilikan. Komunitas tanpa pengurus aktif 90 hari ditandai untuk ditinjau. |
| SEK-R9 | Komunitas jenis Punguan marga berlencana Belum diverifikasi sampai pengajuan di SIS-06 disetujui. |
| SEK-R10 | Daftar anggota menampilkan badge partuturan terhadap pelihat; pada komunitas Tertutup hanya anggota yang dapat melihatnya. Pengurus dapat menyetujui/menghapus anggota, menghapus konten, memposting pengumuman (disematkan maksimal 3), membuat kegiatan, dan mengelola chat grup. |
| SEK-R11 | Gabung: Terbuka langsung; Dengan persetujuan menghasilkan permintaan tertunda yang kedaluwarsa 14 hari. Anggota dapat keluar kapan saja. Chat grup komunitas dibuat otomatis dan anggota baru ditambahkan otomatis. |
| SEK-R12 | Kegiatan (fase 2): judul, waktu mulai dan selesai, lokasi (teks + tautan peta), deskripsi, kapasitas opsional, RSVP (Hadir, Mungkin, Tidak). Tidak dapat dibuat di masa lalu. Pengingat H-1. Pembatalan mengirim notifikasi ke yang sudah RSVP. |
| SEK-R13 | Gereja (fase 2): nama, denominasi (HKBP, GKPI, HKI, GKPS, GBKP, lainnya), alamat, kota, jadwal ibadah, bahasa pengantar, kontak, kegiatan. Sumber: tim HORAS dan usulan pengguna (dimoderasi). Lencana Terverifikasi hanya bila admin gereja dikonfirmasi lewat saluran resmi gereja. Gereja asal pengguna bersifat opsional dan dapat disembunyikan; jumlah jemaat di HORAS baru ditampilkan bila minimal 5 orang. Admin gereja hanya mengelola informasi dan kegiatan, tidak dapat melihat data pribadi jemaat. |

### 6.4 Tarombo (TAR)

| ID | Ketentuan |
| --- | --- |
| TAR-R1 | Data minimal untuk partuturan: jenis kelamin, tahun lahir, marga, marga ibu, sub-suku. Tanpa marga ibu, hubungan jalur ibu tidak dapat dihitung; UI mengajak melengkapi. |
| TAR-R2 | Persetujuan terpisah saat pertama kali mengisi tarombo, menyatakan bahwa pengguna memasukkan data keluarga (pihak lain). |
| TAR-R3 | Anggota yang bukan pengguna HORAS hanya berisi nama, marga, jenis kelamin, tahun lahir (opsional), dan status hidup/almarhum. Tidak dapat dicari publik; tanpa foto atau kontak; terlihat oleh pemilik dan pihak yang disetujui. |
| TAR-R4 | Bila orang yang dicantumkan kemudian mendaftar, sistem menawarkan penautan dengan permintaan konfirmasi ke kedua pihak. Tidak ada penautan otomatis. |
| TAR-R5 | Tiga tingkat keyakinan. Tinggi: jalur tarombo terkonfirmasi kedua pihak. Sedang: inferensi marga + generasi (dari sundut atau tahun lahir). Rendah: data kurang. Teks UI: Tinggi, Dia adalah Tulangmu; Sedang, Kemungkinan: Tulang; Rendah, Belum bisa dipastikan disertai pertanyaan pelengkap. Hasil Sedang dan Rendah tidak boleh ditulis sebagai fakta. |
| TAR-R6 | Mesin aturan bersifat data-driven, berversi, dan divalidasi reviewer adat per sub-suku. Aturan tidak dikodekan keras di aplikasi. Sub-suku tanpa aturan tervalidasi berjalan di mode netral (tanpa badge). Pada fase 1 hanya Toba yang aktif penuh. |
| TAR-R7 | Konfirmasi hubungan: A mengirim klaim Kami kerabat beserta jenis hubungan ke B; B menerima atau menolak. Bila diterima, keyakinan pasangan itu menjadi Tinggi. Penolakan tidak diberitahukan. Satu klaim aktif per pasangan. |
| TAR-R8 | Tombol Bukan pada hasil Sedang/Rendah menyimpan umpan balik sebagai sinyal tinjauan aturan, tidak mengubah aturan otomatis. Tombol Laporkan aturan salah mengirim ke reviewer adat. |
| TAR-R9 | Cek partuturan (TAR-06): pilih dua orang dari kerabat/kenalan, atau input manual dua marga + jenis kelamin + generasi. Hasil berlabel Perkiraan. |
| TAR-R10 | Privasi tarombo: bawaan hanya pemilik. Pemilik dapat membagikan per bagian (marga ibu, nama orang tua) ke Terhubung atau Publik, dan dapat menghapus seluruh data tarombonya kapan saja. |
| TAR-R11 | Kelengkapan tarombo (persen) dihitung dari lima butir: marga ibu, ayah, ibu, kakek dari ayah, kakek dari ibu. Berfungsi sebagai ajakan, bukan syarat. |
| TAR-R12 | Pohon silsilah fase 1: maksimal tiga generasi ke atas dari pemilik. Pohon penuh dan edit lengkap di fase 3. |

### 6.5 Main (MAN)

| ID | Ketentuan |
| --- | --- |
| MAN-R1 | Sesi: olahraga (badminton, futsal, voli, basket, tenis meja, jogging, lainnya), judul opsional, lapangan (dari daftar atau tempat umum), waktu mulai dan selesai (minimal 1 jam dari sekarang, maksimal 60 hari ke depan), slot 2-50 termasuk host, level (pemula, menengah, mahir, semua), biaya per orang Rp0 sampai Rp1.000.000, catatan maksimal 300 karakter. Pembuat sesi harus sudah menyelesaikan onboarding. |
| MAN-R2 | Visibilitas: Publik di area, Komunitas tertentu, atau Hanya undangan. Mode gabung: Langsung atau Perlu persetujuan host. |
| MAN-R3 | Slot penuh menghasilkan daftar tunggu FIFO. Saat slot terbuka, orang pertama di daftar tunggu otomatis masuk dan diberi notifikasi; ia dapat keluar tanpa catatan dalam 1 jam. |
| MAN-R4 | Keluar mendadak (kurang dari 3 jam sebelum mulai) atau tidak hadir (ditandai host) menambah catatan keandalan. Tiga catatan dalam 30 hari: tidak dapat bergabung sesi baru selama 7 hari. Catatan terlihat oleh host, bukan publik. |
| MAN-R5 | Host: maksimal 5 sesi aktif; dapat mengedit waktu/lapangan (peserta diberi notifikasi dan boleh keluar tanpa catatan), membatalkan sesi, mengeluarkan peserta, dan menandai kehadiran. |
| MAN-R6 | Badge partuturan antar-peserta tampil di daftar peserta. |
| MAN-R7 | Patungan: host mengisi total atau biaya per orang; sistem menghitung (dibulatkan ke atas Rp500). Peserta menekan Sudah bayar, host mengonfirmasi. Semua pembayaran terjadi di luar aplikasi; HORAS tidak menyimpan rekening atau memproses uang. **Taruhan uang atau judi dalam bentuk apa pun dilarang**; sesi yang terindikasi dihapus dan akun ditindak. |
| MAN-R8 | Lapangan dari daftar tampil publik. Lokasi yang diketik manual baru ditampilkan lengkap kepada peserta yang sudah bergabung. Sesi hanya boleh di tempat umum atau fasilitas olahraga. |
| MAN-R9 | Chat sesi dibuat otomatis, anggotanya peserta, menjadi baca-saja 24 jam setelah selesai. Sesi otomatis berstatus Selesai 2 jam setelah waktu selesai. |
| MAN-R10 | Lapangan: nama, alamat, kota, olahraga, perkiraan harga (berlabel perkiraan), jam. Usulan pengguna masuk antrean moderasi. Lapangan dengan lebih dari 3 laporan salah info ditandai untuk ditinjau. |
| MAN-R11 | Pengingat: H-1 pukul 19.00 dan 2 jam sebelum mulai. |

### 6.6 Pesan (PSN)

| ID | Ketentuan |
| --- | --- |
| PSN-R1 | Chat pribadi terbuka bila (a) kedua pengguna Terhubung, atau (b) mereka berbagi konteks (komunitas atau sesi yang sama) dan penerima mengizinkan pesan dari konteks bersama. Selain itu tidak ada tombol Pesan. |
| PSN-R2 | Pada kasus (b), pesan pertama masuk ke Permintaan pesan (PSN-02), maksimal satu pesan teks sampai diterima. Penerima memilih Terima, Hapus, atau Blokir. |
| PSN-R3 | Jenis pesan v1: teks (maksimal 2.000 karakter), foto (maksimal 5 MB, dikompres), balas pesan, status terkirim dan terbaca (dapat dimatikan di Privasi). Voice note di fase 2. |
| PSN-R4 | Hapus untuk saya kapan saja; Hapus untuk semua dalam 1 jam setelah kirim. Pesan yang dilaporkan tetap tersimpan 30 hari untuk moderasi walau dihapus. |
| PSN-R5 | Grup v1: grup komunitas dan grup sesi (otomatis). Grup buatan pengguna di fase 2. Admin grup (Pengurus/host) dapat menghapus pesan, mengeluarkan anggota, dan mengirim Pengumuman yang disematkan. |
| PSN-R6 | Bisukan percakapan: 1 jam, 8 jam, 1 minggu, selamanya. Keluar grup bebas. Blokir menutup chat dua arah dan menyembunyikan percakapan. |
| PSN-R7 | Header chat menampilkan foto, nama, badge partuturan, tombol sapaan cepat sesuai hubungan (misal Horas, Lae!), dan menu Laporkan/Blokir. |
| PSN-R8 | Perlindungan penipuan: pesan pertama dari non-terhubung yang berisi tautan atau permintaan uang ditandai peringatan agar tidak mentransfer uang ke orang yang belum dikenal. |
| PSN-R9 | Tidak ada telepon/video, dan tidak ada kirim lokasi presisi. Batas: pesan pertama ke maksimal 20 orang baru per hari. |

### 6.7 Akun (AKN)

| ID | Ketentuan |
| --- | --- |
| AKN-R1 | Profil saya: foto, nama, marga, kota, bio (maksimal 150 karakter), hitungan Pengikut, Mengikuti, dan Kenalan, serta tab Postingan dan Tersimpan. |
| AKN-R2 | Dapat diubah: foto, nama tampil (maksimal sekali per 30 hari), bio, domisili, hobi, kampus/kantor, satu tautan. Terkunci: marga, sub-suku, jenis kelamin (lewat dukungan), nomor HP (ganti lewat AKN-09). |
| AKN-R3 | Privasi diatur per bidang sesuai tabel bawaan di bagian 7.1. Tipe akun: Publik atau Privat. |
| AKN-R4 | Keamanan: daftar perangkat aktif (dapat dikeluarkan), ganti nomor (OTP ke nomor lama dan baru), riwayat masuk 30 hari terakhir. |
| AKN-R5 | Notifikasi dapat dimatikan per jenis (kecuali keamanan akun dan tindakan moderasi). Jam tenang bawaan 22.00 sampai 06.00. |
| AKN-R6 | Blokir: kedua pihak tidak saling melihat profil, postingan, komentar, pencarian, dan Sekitar; chat pribadi ditutup; koneksi dan ikuti dihapus; di grup bersama pesan yang diblokir disembunyikan bagi pemblokir. Buka blokir lewat AKN-11; hubungan sebelumnya tidak dipulihkan otomatis. |
| AKN-R7 | Data saya: arsip profil, postingan, dan tarombo dalam format terbuka (ZIP/JSON), dikirim sebagai tautan berlaku 7 hari dalam 48 jam, dengan verifikasi OTP. Maksimal sekali per 7 hari. |
| AKN-R8 | Hapus akun: konfirmasi OTP, masa tunggu 30 hari (login ulang membatalkan). Setelah itu profil, postingan, foto, dan tarombo dihapus permanen. Pesan yang pernah dikirim tetap terlihat oleh lawan bicara sebagai Pengguna terhapus. Komunitas yang dimiliki harus diserahkan dulu. Log keamanan minimal disimpan sesuai kewajiban hukum. |
| AKN-R9 | Kenalan saya: tab Terhubung, Permintaan masuk, Terkirim. |

### 6.8 Sistem (SIS)

| ID | Ketentuan |
| --- | --- |
| SIS-R1 | Notifikasi dikelompokkan (Hari ini, Minggu ini, Sebelumnya), dapat ditandai terbaca, dan membuka halaman terkait lewat deep link. Disimpan 90 hari. |
| SIS-R2 | Laporan: kategori (Pelecehan, SARA/ujaran kebencian, Spam/penipuan, Konten tidak pantas, Identitas palsu, Aturan partuturan salah, Lainnya), catatan opsional maksimal 500 karakter. Target: pengguna, postingan, komentar, pesan, komunitas, sesi, gereja, lapangan. Identitas pelapor tidak diberitahukan ke terlapor. Satu laporan aktif per target per pelapor. |
| SIS-R3 | Status laporan: Diterima, Ditinjau, Selesai (hasil umum: Tindakan diambil atau Tidak melanggar). Target tinjauan 24 jam; laporan keselamatan diprioritaskan. |
| SIS-R4 | Sanksi bertahap: peringatan; hapus konten + strike; suspend 7-30 hari; blokir permanen. Pelanggaran berat (pelecehan seksual, penipuan, ancaman, ujaran kebencian) dapat langsung suspend atau blokir. Tiga strike dalam 90 hari = suspend. Banding lewat SIS-05 dalam 14 hari. |
| SIS-R5 | Pusat bantuan berisi artikel dan FAQ. Hubungi dukungan: formulir dengan kategori dan lampiran foto; balasan lewat notifikasi dan email opsional. |
| SIS-R6 | Verifikasi komunitas: nama, tipe, bukti (surat penunjukan/keterangan pengurus, atau konfirmasi pengurus pusat), kontak. Status: Diajukan, Perlu data tambahan, Disetujui, Ditolak (disertai alasan). Lencana dapat dicabut bila informasi tidak benar. Verifikasi gereja (fase 2) lewat kontak resmi gereja. |
| SIS-R7 | Pedoman komunitas dapat dibaca tanpa login. Larangan inti: SARA dan ujaran kebencian, kampanye politik dan ajakan memilih, pelecehan, penipuan, konten dewasa, taruhan, membagikan data pribadi orang lain tanpa izin, mencatut nama marga atau organisasi. |

---

## 7. Aturan Bisnis Lintas Modul

### 7.1 Privasi Bawaan per Bidang

| Bidang | Pilihan | Bawaan |
| --- | --- | --- |
| Nama, foto, marga, kota | Terlihat pengguna terdaftar (akun Privat tetap menampilkan ini, menyembunyikan konten) | Semua pengguna |
| Marga ibu | Semua / Terhubung / Hanya saya | Terhubung |
| Tahun lahir | Kelompok usia (misal 25-34) atau tersembunyi. Mesin partuturan tetap memakainya di server tanpa menampilkannya | Tersembunyi |
| Kecamatan | Semua / Terhubung / Hanya saya | Terhubung |
| Komunitas yang diikuti | Semua / Terhubung / Hanya saya (komunitas Tertutup tidak pernah tampil) | Terhubung |
| Gereja asal | Semua / Terhubung / Hanya saya | Hanya saya (opt-in) |
| Tarombo | Terhubung / Hanya saya | Hanya saya |
| Tampil di Sekitar dan pencarian | Ya / Tidak | Ya |
| Siapa dapat mengirim Kenalan | Semua / Satu komunitas / Tidak ada | Semua |
| Pesan dari konteks bersama | Izinkan (sebagai Permintaan) / Tidak | Izinkan |
| Tanda terbaca | Ya / Tidak | Ya |
| Tipe akun | Publik / Privat | Publik |

### 7.2 Tabel Batas (rate limit dan kuota)

Batas yang terlampaui tidak menghukum pengguna: tampilkan pesan jelas dan kapan dapat mencoba lagi.

| Aksi | Batas |
| --- | --- |
| Permintaan OTP | 5 per jam per nomor; 5 salah memasukkan = kunci 1 jam |
| Perangkat aktif | 3 |
| Permintaan Kenalan baru | 10 per hari; kedaluwarsa 30 hari |
| Ikuti baru | 200 per hari |
| Pesan pertama ke orang baru | 20 per hari |
| Postingan | 20 per 24 jam; teks 2.000 karakter; 10 foto; foto 10 MB |
| Komentar | 60 per jam; 1.000 karakter |
| Bio | 150 karakter |
| Ganti nama tampil | Sekali per 30 hari |
| Komunitas dibuat | 5 per akun; 10 Pengurus; 3 pengumuman disematkan |
| Permintaan gabung komunitas | Kedaluwarsa 14 hari |
| Sesi aktif milik host | 5; slot 2-50; biaya maksimal Rp1.000.000 per orang |
| Catatan keandalan | 3 dalam 30 hari = tidak dapat gabung sesi 7 hari |
| Foto di chat | 5 MB |
| Laporan | 20 per hari per pengguna |
| Unduh data | Sekali per 7 hari |
| Banding sanksi | 14 hari setelah sanksi |

### 7.3 Istilah Antarmuka Baku

Agar konsisten di desain dan teks: **Ikuti** (satu arah), **Kenalan** (tombol mengirim permintaan), **Terhubung** (status setelah diterima), **Pesan**, **Semarga** (label marga sama), **Kemungkinan** (hasil partuturan keyakinan Sedang), **Belum diverifikasi** dan **Terverifikasi**. Sapaan Horas dipakai di titik yang relevan (pembuka, sapaan chat), tidak di setiap layar.

---

## 8. Alur Pengguna Utama

**A1. Daftar sampai melihat Sekitar**

1. Splash → Pengenalan → Masuk (nomor HP).
2. Daftar: setujui kebijakan dan pedoman, nyatakan usia 17+.
3. Verifikasi OTP.
4. Onboarding 4 langkah (nama, lahir, marga dan sub-suku, domisili).
5. Penjelasan manfaat izin notifikasi dan lokasi perkiraan.
6. Tiba di Sekitar dengan saran kerabat dan komunitas.

*Pengecualian:* OTP salah/kedaluwarsa; marga tidak ditemukan (antrean verifikasi); usia di bawah 17 (ditolak); onboarding terputus (dilanjutkan dari langkah terakhir).

**A2. Kenalan sampai chat**

1. Sekitar → Daftar orang → Profil orang lain (badge partuturan).
2. Ketuk Kenalan → pilih sapaan atau tulis pengantar → kirim.
3. Penerima mendapat notifikasi → Terima.
4. Status menjadi Terhubung → tombol Pesan aktif → chat terbuka.

*Pengecualian:* penerima menolak/mengabaikan (pengirim tidak diberi tahu); batas harian tercapai; salah satu memblokir; permintaan kedaluwarsa 30 hari.

**A3. Cek partuturan dan konfirmasi kerabat**

1. Tarombo → Cek partuturan, atau buka profil seseorang.
2. Detail hubungan menampilkan panggilan, penjelasan jalur, dan tingkat keyakinan.
3. Bila keyakinan Sedang: ketuk Konfirmasi atau Bukan.
4. Ingin memastikan: Kirim klaim Kami kerabat → pihak lain menyetujui → keyakinan menjadi Tinggi.

*Pengecualian:* data kurang (pertanyaan pelengkap); sub-suku mode netral (tanpa badge); klaim ditolak (tanpa pemberitahuan).

**A4. Buat dan ikuti sesi main**

1. Main → Buat sesi → isi olahraga, lapangan, waktu, slot, level, biaya, visibilitas.
2. Sesi tampil di Main untuk area terkait; undang kenalan atau bagikan ke komunitas.
3. Peserta Gabung (langsung atau menunggu persetujuan); penuh masuk daftar tunggu.
4. Grup chat sesi terbentuk otomatis; pengingat H-1 dan 2 jam.
5. Selesai → host menandai kehadiran dan mencatat patungan.

*Pengecualian:* sesi diubah/dibatalkan; peserta keluar mendadak (catatan keandalan); indikasi taruhan (dilaporkan, ditindak).

**A5. Gabung dan kelola komunitas**

1. Sekitar → Komunitas → Detail → Gabung (langsung atau minta persetujuan).
2. Pengurus menyetujui di Kelola komunitas; anggota otomatis masuk chat grup.
3. Pengurus memposting pengumuman dan (fase 2) membuat kegiatan dengan RSVP.

*Pengecualian:* komunitas Tertutup (hanya undangan); permintaan kedaluwarsa 14 hari; pemilik hendak keluar (harus serahkan kepemilikan).

**A6. Membuat postingan**

1. Beranda → tombol tambah → Postingan.
2. Tulis teks dan/atau pilih foto → pangkas dan urutkan → pilih visibilitas.
3. Kirim → filter otomatis → tayang atau Sedang ditinjau.

*Pengecualian:* batas harian; unggahan gagal (draf tersimpan, coba lagi); izin galeri ditolak.

**A7. Lapor dan blokir**

1. Menu pada profil, postingan, komentar, pesan, komunitas, atau sesi → Laporkan.
2. Pilih kategori, catatan opsional → kirim; opsional langsung Blokir.
3. Pantau di Status laporan saya; hasil disampaikan secara umum.

**A8. Hapus akun**

1. Akun → Pengaturan → Hapus akun → baca konsekuensi (komunitas yang dimiliki, data hilang).
2. Konfirmasi OTP → masa tunggu 30 hari.
3. Login dalam 30 hari membatalkan; setelahnya data dihapus permanen.

---

## 9. Notifikasi

Kanal: push (utama) dan dalam aplikasi (SIS-01). Jam tenang 22.00-06.00 berlaku untuk semua kecuali keamanan akun. Pesan baru dikelompokkan per percakapan.

| Peristiwa | Penerima | Tujuan ketukan | Dapat dimatikan |
| --- | --- | --- | --- |
| Permintaan Kenalan masuk | Penerima | AKN-12 | Ya |
| Kenalan diterima | Pengirim | Profil / chat | Ya |
| Pesan baru | Penerima | Chat | Ya (per percakapan) |
| Permintaan pesan | Penerima | PSN-02 | Ya |
| Suka dan komentar | Pemilik postingan | Postingan | Ya |
| Pengikut baru / permintaan ikuti | Pemilik akun | AKN-05 / AKN-12 | Ya |
| Permintaan gabung komunitas | Pengurus | SEK-08 | Ya |
| Persetujuan gabung | Pemohon | SEK-06 | Ya |
| Pengumuman komunitas | Anggota | SEK-06 | Ya |
| Pengingat kegiatan (fase 2) | Yang RSVP Hadir/Mungkin | SEK-09 | Ya |
| Gabung sesi disetujui, daftar tunggu naik | Peserta | MAN-04 | Ya |
| Sesi diubah atau dibatalkan | Peserta | MAN-04 | Tidak |
| Pengingat sesi (H-1, 2 jam) | Peserta | MAN-04 | Ya |
| Klaim Kami kerabat masuk | Penerima | TAR-07 | Ya |
| Hasil laporan | Pelapor | SIS-03 | Ya |
| Tindakan moderasi pada akun/konten | Pemilik | Layar penjelasan | Tidak |
| Keamanan akun (login perangkat baru, ganti nomor) | Pemilik | AKN-09 | Tidak |

---

## 10. Kebutuhan Data dan Retensi

Skema rinci ada di SDD bagian 5. Berikut aturan retensi dari sisi produk.

| Data | Retensi |
| --- | --- |
| Akun, profil | Selama akun aktif; hapus akun = masa tunggu 30 hari lalu dihapus permanen |
| Postingan dan komentar | Sampai dihapus pembuat atau akun dihapus |
| Story (fase 2) | Tayang 24 jam, lalu dihapus |
| Pesan | Pribadi: sampai dihapus; chat sesi: 12 bulan; pesan dilaporkan: 30 hari tambahan untuk moderasi |
| Tarombo | Sampai dihapus pemilik |
| Laporan dan tindakan moderasi | 12 bulan |
| Log audit admin | 12 bulan |
| Kode OTP | Dibuang saat kedaluwarsa atau terpakai |
| Cadangan (backup) | 30 hari |

Prinsip minimisasi: tahun lahir (bukan tanggal lengkap), area (bukan koordinat), tidak ada data anak di profil, tidak ada isi chat atau tarombo pada data analitik.

---

## 11. Kebutuhan Non-Fungsional

| Kategori | Target |
| --- | --- |
| Performa | API p95 di bawah 500 ms; hasil partuturan di bawah 200 ms (cache); feed pertama tampil di bawah 2 detik pada 4G |
| Chat | Pesan terkirim di bawah 2 detik pada 4G |
| Ketersediaan | 99,5% per bulan |
| Skalabilitas | 10.000 MAU saat peluncuran; siap 100.000 tanpa perubahan arsitektur besar |
| Kompatibilitas | Android 8.0+, iOS 15+ |
| Ukuran aplikasi | Unduhan di bawah 40 MB |
| Jaringan lemah | Cache feed/profil, kompres gambar di klien, unggah dapat dilanjutkan, coba ulang otomatis |
| Aksesibilitas | Teks dinamis, kontras, label pembaca layar, target sentuh minimal 44 px |
| Bahasa | Indonesia; istilah Batak sebagai konten |
| Stabilitas | Crash-free sessions di atas 99% |

---

## 12. Keamanan, Privasi, dan Kepatuhan

- Kepatuhan pada **UU 27/2022 tentang Pelindungan Data Pribadi**. Marga, silsilah, dan gereja asal diperlakukan sebagai data yang sangat sensitif secara sosial meski tidak semuanya tergolong data spesifik menurut undang-undang.
- Persetujuan eksplisit dan terpisah untuk: kebijakan privasi dan syarat, pedoman komunitas, pemrosesan data silsilah, notifikasi pemasaran (bila ada).
- Hak pengguna: akses dan unduh data (AKN-13), koreksi (AKN-02), hapus akun (AKN-14).
- Lokasi hanya level area; tidak ada koordinat pengguna; foto bebas EXIF.
- Pendaftaran PSE privat sesuai ketentuan Komdigi; kebijakan privasi dan syarat layanan dalam bahasa Indonesia; penanggung jawab pelindungan data ditunjuk.
- Kontrol teknis (TLS, token berumur pendek, rate limit, enkripsi penyimpanan, audit log admin, uji penetrasi) mengikuti SDD bagian 9.
- **Tinjauan konsultan hukum wajib sebelum peluncuran publik.**

---

## 13. Kriteria Penerimaan

Dipakai QA sebagai uji penerimaan. Format: Diberikan, Ketika, Maka.

| ID | Skenario |
| --- | --- |
| AC-01 | **Diberikan** OTP salah dimasukkan 5 kali, **Ketika** mencoba lagi, **Maka** nomor terkunci 1 jam dan pesan menyebut kapan dapat mencoba. |
| AC-02 | **Diberikan** tahun lahir yang menghasilkan usia di bawah 17, **Ketika** melanjutkan, **Maka** pendaftaran ditolak dengan pesan sopan dan data tidak disimpan. |
| AC-03 | **Diberikan** pengguna Toba dan target bermarga sama dengan marga ibunya, satu generasi di atasnya, tanpa jalur terkonfirmasi, **Ketika** membuka profil target, **Maka** tampil Kemungkinan: \[istilah\] dengan tombol Konfirmasi dan Bukan, bukan pernyataan pasti. |
| AC-04 | **Diberikan** pengguna sub-suku tanpa aturan tervalidasi, **Ketika** membuka profil orang lain, **Maka** tidak ada badge partuturan; marga dan label Semarga (bila berlaku) tetap tampil. |
| AC-05 | **Diberikan** B menolak permintaan Kenalan dari A, **Maka** A tidak menerima pemberitahuan penolakan dan tidak dapat mengirim ulang selama 30 hari. |
| AC-06 | **Diberikan** A dan B belum terhubung dan tidak berbagi komunitas/sesi, **Ketika** A membuka profil B, **Maka** tombol Pesan tidak tersedia. |
| AC-07 | **Ketika** pengguna membuka kartu orang di Sekitar, **Maka** tampilan dan respons API tidak memuat koordinat, jarak presisi, atau nomor HP. |
| AC-08 | **Diberikan** sesi terisi 8 dari 8, **Ketika** pengguna ke-9 menekan Gabung, **Maka** ia masuk daftar tunggu urutan 1; saat satu peserta keluar, ia otomatis masuk dan menerima notifikasi. |
| AC-09 | **Ketika** peserta keluar kurang dari 3 jam sebelum mulai, **Maka** catatan keandalannya bertambah dan host menerima notifikasi. |
| AC-10 | **Diberikan** foto dengan EXIF lokasi, **Ketika** diposting, **Maka** berkas yang disajikan tidak mengandung metadata lokasi. |
| AC-11 | **Ketika** A memblokir B, **Maka** keduanya tidak saling terlihat di profil, postingan, pencarian, dan Sekitar; chat tertutup; koneksi dihapus. |
| AC-12 | **Diberikan** permintaan hapus akun, **Ketika** pengguna login dalam 30 hari, **Maka** penghapusan dibatalkan; bila tidak, data dihapus permanen pada hari ke-30. |
| AC-13 | **Diberikan** komunitas berakses Tertutup, **Ketika** non-anggota mencari, **Maka** komunitas dan daftar anggotanya tidak muncul. |
| AC-14 | **Ketika** pengguna melaporkan postingan, **Maka** laporan masuk antrean berstatus Diterima, terlihat di SIS-03, dan identitas pelapor tidak terlihat oleh terlapor. |
| AC-15 | **Diberikan** perangkat tanpa koneksi, **Ketika** membuka feed, **Maka** data tersimpan tampil dengan penanda dan tombol Coba lagi. |
| AC-16 | **Ketika** pesan pertama dari non-terhubung memuat tautan atau permintaan uang, **Maka** tampil peringatan penipuan kepada penerima. |

**Definisi selesai (Definition of Done) sebuah fitur:** desain disetujui dan mencakup semua status di 5.2; aturan di bagian 6 terimplementasi; uji unit dan integrasi lulus; kriteria penerimaan terkait lulus; untuk fitur Tarombo, hasil ditinjau reviewer adat; untuk fitur data pribadi, tinjau privasi selesai.

---

## 14. Metrik dan Analitik

| Metrik | Definisi | Target beta |
| --- | --- | --- |
| Penyelesaian onboarding | Pendaftar yang menyelesaikan AUT-06 | Di atas 70% |
| Aktif mingguan | Pengguna aktif 7 hari dibanding terdaftar, di komunitas pilot | Di atas 40% |
| Kenalan diterima | Permintaan diterima dibanding terkirim | Di atas 50% |
| Sesi terisi penuh | Sesi dengan semua slot terisi | Di atas 60% |
| Retensi minggu ke-4 | Pengguna kembali di minggu ke-4 | Di atas 30% |
| Pembukaan detail hubungan | Pengguna aktif mingguan yang membuka TAR-05 | Di atas 30% |
| Laporan ditangani 24 jam | Laporan selesai ditinjau dalam 24 jam | Di atas 90% |
| Akurasi partuturan | Persetujuan reviewer pada kasus yang ditinjau | Di atas 95% |
| Crash-free sessions |  | Di atas 99% |

Analitik hanya memuat peristiwa penggunaan (layar dibuka, aksi diselesaikan) tanpa isi chat, isi tarombo, atau data pribadi sensitif.

---

## 15. Risiko, Keputusan Terbuka, dan Keselarasan

### 15.1 Risiko Utama

| Risiko | Mitigasi |
| --- | --- |
| Aturan partuturan keliru atau dianggap tidak tepat oleh pemangku adat | Validasi reviewer adat, tingkat keyakinan, tombol koreksi, mulai dari Toba |
| Cakupan terlalu besar (Beranda, story, video) sehingga MVP molor | Fasekan sesuai bagian 3; jaga v1 pada Tarombo, Sekitar, Main, Pesan |
| Feed sepi di awal | Mulai dari satu kota/komunitas; feed berisi komunitas yang diikuti |
| Pelecehan atau penipuan lewat pesan | Permintaan kenalan/pesan, peringatan penipuan, blokir, moderasi 24 jam |
| Isu SARA dan politik | Pedoman tegas, filter kata, moderator, sanksi bertahap |
| Kebocoran data silsilah | Minimisasi, privasi bawaan ketat, enkripsi, uji penetrasi |
| Pemakaian taruhan di sesi olahraga | Larangan eksplisit, pelaporan, tindakan akun |
| Beban moderasi melebihi kapasitas tim | Rate limit, filter otomatis, rekrut moderator komunitas, antrean prioritas |

### 15.2 Keputusan Terbuka

| ID | Keputusan | Rekomendasi |
| --- | --- | --- |
| K1 | Login: OTP saja atau OTP + sandi | OTP saja (draf awal menyebut lupa sandi; jika sandi dipertahankan, tambah halaman atur sandi dan reset) |
| K2 | Cakupan Beranda v1 | Feed ringan (teks dan foto), story dan video di fase 2 |
| K3 | Perlukah Story sama sekali | Tunda; putuskan setelah data penggunaan beta |
| K4 | Mempertahankan Ikuti dan Terhubung sekaligus | Pertahankan (Ikuti untuk konten, Terhubung untuk chat); alternatif lebih sederhana: hanya Terhubung |
| K5 | Reviewer adat: siapa, per sub-suku, dan kompensasi | Mulai dari Toba dengan 1-2 reviewer sebelum pengembangan aturan |
| K6 | Kota dan komunitas pilot | Satu kota dengan satu komunitas olahraga atau naposo |
| K7 | Gereja asal tampil publik atau opt-in | Opt-in, bawaan tersembunyi |
| K8 | Nama tampil: nama asli atau boleh panggilan | Nama yang dikenal komunitas; tidak wajib sama dengan KTP |
| K9 | Model bisnis awal | Gratis di v1; tentukan komisi/langganan setelah v2 |
| K10 | Penanggung jawab hukum dan pelindungan data | Tunjuk sebelum beta |

### 15.3 Keselarasan dengan SDD

SDD v0.1 dibuat sebelum PRD ini. Perubahan yang perlu diterapkan:

- Nama Hita menjadi **HORAS**; empat tab menjadi **lima tab** (tambah Beranda).
- Tambah modul Beranda: entitas posts, post\_media, comments, likes, follows, saved\_posts, stories (fase 2), beserta endpoint feed, posting, komentar, ikuti, simpan, pencarian.
- Autentikasi: OTP saja, pemulihan akun, maksimal 3 perangkat.
- SDD FR-B3 bergantung pada tujuan interaksi yang tidak ada di PRD; diganti label **Semarga** (SEK-R6).
- Moderasi: tambah strike, banding, dan status laporan (SIS-R3, SIS-R4).
- Entitas baru: partuturan\_claims, reliability\_marks, strikes, verification\_requests, data\_export\_jobs.
- Chat grup sesi menjadi baca-saja 24 jam setelah selesai (SDD: ditutup saat selesai).
- Estimasi 12-14 minggu dan komposisi tim v1 perlu ditinjau ulang karena Beranda dan Pesan masuk MVP.

---

## Lampiran: Riwayat Versi

| Versi | Tanggal | Perubahan |
| --- | --- | --- |
| 0.x | Sebelum 16 November 2026 | Draf awal (gambaran umum, navigasi, inventaris halaman) |
| 1.0 | 16 November 2026 | Revisi dan pelengkapan: spesifikasi per modul, aturan bisnis, alur, kriteria penerimaan, keputusan terbuka |
