# HORAS Backend API & Kontrak Supabase

Dokumen ini memetakan seluruh skema database PostgreSQL (`supabase/migrations/0001..0006`), fungsi RPC, Edge Functions, Storage buckets, Realtime channels, dan jadwal `pg_cron` ke **23 repository domain** pada aplikasi Flutter (`lib/domain/repositories/`).

---

## 1. Arsitektur & Keamanan Inti

- **Auth (`AUT-R1`..`AUT-R9`):** Hanya nomor HP + OTP 6 digit (`auth.sms.enabled = true`, `auth.email.enabled = false`). Edge Function [`auth-otp-guard`](file:///home/man/HORAS-apk/supabase/functions/auth-otp-guard/index.ts) menegakkan batas 5 permintaan OTP/jam (`AUT-R2`), jeda kirim ulang 60 detik, kunci 1 jam setelah 5 kali salah (`AUT-R3`), blokir permanen, dan batas maksimal **3 perangkat aktif** (`AUT-R9`) yang otomatis mengeluarkan perangkat tertua + mengirim notifikasi keamanan.
- **Anti-Leak Privasi (`PRD 7.1, 12`, `AC-07`):**
  - RLS aktif di seluruh tabel `public`.
  - Tabel `public.profiles` **hanya** mengizinkan `SELECT` ke baris milik sendiri (`auth.uid() = id`) atau peran staf (`support`, `moderator`, `admin`). Klien lain **tidak pernah** membaca `phone_e164` maupun `birth_year`.
  - Seluruh tampilan profil orang lain memakai fungsi `SECURITY DEFINER` (`get_person_summary`, `get_nearby_people`, `search_people`) yang tidak pernah mengembalikan `phone_e164`, `birth_year`, usia pasti, koordinat GPS, atau jarak kilometer (`proximity` hanya `DiKotamu` atau `DiKecamatanmu` sesuai pengaturan privasi).
  - Kolom `marga`, `sub_ethnic`, `gender`, `account_status`, dan `phone_e164` dikunci oleh trigger `guard_profile_locked_fields` setelah onboarding selesai (`faq-01`); perubahan `display_name` dibatasi cooldown 30 hari.
- **Partuturan (`TAR-R5`, `TAR-R6`):**
  - `public.generation_delta(viewer_id, target_id)` (`SECURITY DEFINER`) menghitung selisih generasi (dari klaim terkonfirmasi, `sundut`, atau estimasi internal `birth_year`) dan hanya mengembalikan `integer` / `NULL`.
  - `public.evaluate_partuturan(viewer_id, target_id)` membaca ruleset data-driven dari `public.partuturan_rulesets` (`validated`, `reviewed_by`). Hasil dengan keyakinan `sedang`/`rendah` selalu dilabeli `Kemungkinan: ...`.
- **Media Tanpa EXIF/GPS (`BER-R4`, `AC-10`):**
  - Bucket `avatars` (`public`, maks 5 MB), `posts` (privat auth, maks 10 MB), `chat-media` (privat peserta percakapan, maks 5 MB), dan `support` (pemilik + staf, maks 10 MB).
  - Unggahan gambar untuk `avatars`, `posts`, `chat-media` diproses melalui Edge Function [`process-image`](file:///home/man/HORAS-apk/supabase/functions/process-image/index.ts) yang mendekode piksel (`jpeg-js` / `upng-js`) lalu meng-encode ulang tanpa segmen APP1/EXIF/GPS sebelum menyimpannya ke Storage.

---

## 2. Pemetaan Error Server → `AppFailure` (`lib/core/errors/app_failure.dart`)

Semua RPC menulis pesan berformat `HORAS_ERR|<CODE>|<retry_at_iso>|<field>|<message>` dan detail JSON, sedangkan Edge Function mengembalikan JSON `{ ok: false, code, message, retry_at?, field? }`:

| Kode Server | HTTP / SQLSTATE | `AppFailure` di Flutter | Keterangan |
| :--- | :--- | :--- | :--- |
| `RATE_LIMITED` | `429` / `P0001` | `RateLimitedError(retryAt, retryAfter)` | Kuota harian/jam (kenalan 10/hari, ikuti 200/hari, post 20/24j, komen 60/j, pesan baru 20/hari, laporan 20/hari, ekspor 7h, cooldown tolak 30h, lock OTP 1j, penahanan Main 7h). |
| `VALIDATION_ERROR` | `400` / `P0001` | `ValidationError(field)` | Panjang teks, slot 2..50, biaya 0..1jt, umur < 17, kata taruhan/judi (`MAN-R7`), chat read-only 24j (`MAN-R9`), jendela banding 14h, hapus pesan > 1j. |
| `SUSPENDED` | `403` / `P0001` | `SuspendedError(canAppeal)` | Akun disuspend (3 strike dalam 90 hari) atau diblokir permanen. |
| `PERMISSION_DENIED` | `401`/`403` / `42501` | `PermissionDeniedError` | Akses non-anggota, privasi permintaan kenalan/pesan, akun < 7 hari buat komunitas, batas 1 pesan `PSN-R1`, akses staf. |
| `CONTENT_UNAVAILABLE` | `404` / `P0001` | `UnavailableError` | Target diblokir dua arah (`AC-11`), dihapus, atau komunitas `closed` (`AC-13`). |

---

## 3. Pemetaan 23 Domain Repository Flutter

| # | Repository Interface | Tabel / Storage Utama | RPC / Edge Function / Realtime |
| :--- | :--- | :--- | :--- |
| 1 | `AuthRepository` | `otp_security_state`, `otp_request_logs`, `user_devices`, `login_history`, `profiles`, `account_recovery_requests` | Edge `auth-otp-guard` (`request_otp`, `verify_otp`, `register_device`), RPC `complete_onboarding`, `submit_account_recovery` |
| 2 | `ProfileRepository` | `profiles` (owner-only), bucket `avatars` | `profiles` (`SELECT`/`UPDATE` milik sendiri), RPC `get_person_summary`, Edge `process-image` (`bucket='avatars'`) |
| 3 | `PrivacyRepository` | `user_privacy_settings` | `user_privacy_settings` (`SELECT`/`UPDATE` milik sendiri) |
| 4 | `FollowRepository` | `follows` | `follows` (`SELECT`/`DELETE`), RPC `follow_user` |
| 5 | `ConnectionRepository` | `connections`, `connection_requests` | `connections` (`SELECT`), `connection_requests` (`SELECT`), RPC `send_connection_request`, `respond_connection_request` |
| 6 | `BlockRepository` | `blocks` | `blocks` (`SELECT`), RPC `block_user`, `unblock_user` |
| 7 | `PostRepository` | `posts`, `post_media`, `likes`, `saved_posts`, bucket `posts` | `posts` (`SELECT`/`DELETE`), `likes` & `saved_posts` (`SELECT`/`INSERT`/`DELETE`), RPC `create_post`, Edge `process-image` (`bucket='posts'`) |
| 8 | `CommentRepository` | `comments` | `comments` (`SELECT`/`DELETE`), RPC `add_comment` |
| 9 | `SearchRepository` | `communities` (non-closed / anggota), `profiles` (via RPC) | RPC `search_people`, query `communities` (disaring RLS `AC-13`), `posts` |
| 10 | `NearbyRepository` | `profiles` + `user_privacy_settings` (via RPC) | RPC `get_nearby_people` |
| 11 | `CommunityRepository` | `communities`, `community_memberships`, `community_join_requests`, `community_announcements` | RPC `create_community`, `join_community`, `respond_community_join_request`, `create_community_announcement`, `promote_community_manager`, `get_user_visible_communities` |
| 12 | `SessionRepository` | `play_sessions`, `session_participants`, `session_waitlist`, `session_payment_shares`, `reliability_marks` | RPC `create_session`, `join_session`, `leave_session`, `mark_session_no_show` |
| 13 | `CourtRepository` | `courts` | `courts` (`SELECT`/`INSERT pending_review`) |
| 14 | `ChatRepository` | `conversations`, `conversation_participants`, `messages`, `message_requests`, bucket `chat-media` | Realtime (`messages`, `conversations`), RPC `send_first_message`, `send_message`, `respond_message_request`, `delete_message_for_everyone`, Edge `process-image` (`bucket='chat-media'`) |
| 15 | `NotificationRepository` | `notifications`, `notification_preferences` | Realtime (`notifications`), `notifications` (`SELECT`/`UPDATE`), `notification_preferences` (`SELECT`/`UPDATE`) |
| 16 | `ReportRepository` | `reports`, `retained_moderated_content`, `strikes`, `appeals`, `audit_log` | RPC `submit_report`, `submit_appeal`, `admin_resolve_report`, `admin_resolve_appeal` |
| 17 | `VerificationRepository` | `verification_requests`, bucket `support` | RPC `submit_verification_request`, `admin_review_verification` |
| 18 | `TaromboRepository` | `family_members`, `profiles` (`mother_marga`, `sundut`) | `family_members` (`SELECT`/`INSERT`/`UPDATE`/`DELETE`), RPC `propose_partuturan_claim`, `respond_partuturan_claim` |
| 19 | `PartuturanRepository` | `partuturan_rulesets`, `partuturan_claims`, `partuturan_feedback` | RPC `generation_delta`, `evaluate_partuturan`, `propose_partuturan_claim`, `respond_partuturan_claim`, `admin_review_partuturan_ruleset` |
| 20 | `SupportRepository` | `help_articles`, `support_tickets`, `account_recovery_requests`, bucket `support` | `help_articles` (`SELECT`), `support_tickets` (`SELECT`/`INSERT`), RPC `submit_account_recovery` |
| 21 | `AccountLifecycleRepository` | `data_export_jobs`, `account_deletions`, `user_devices`, `login_history` | RPC `request_data_export`, `request_account_deletion`, `cancel_account_deletion` |
| 22 | `NavigationBadgeRepository` | `conversation_participants` (`unread_count`), `notifications` (`is_read`) | Query / Realtime subscription agregasi jumlah pesan & notifikasi belum dibaca |
| 23 | `DebugSimulationRepository` | *Lokal dev-only* | Di produksi digantikan oleh state server asli + `[auth.sms.test_otp]` saat pengembangan |

---

## 4. Peran Database (`app_role`) & Audit Log

Peran pada `public.user_roles`: `user`, `moderator`, `adat_reviewer`, `support`, `admin`.
Setiap tindakan staf (`admin_resolve_report`, `admin_review_verification`, `admin_review_partuturan_ruleset`, `admin_resolve_appeal`) otomatis mencatat baris di `public.audit_log` dengan retensi 12 bulan.

---

## 5. Jadwal Pemeliharaan (`pg_cron`) & Cadangan Infra (PRD 10)

Fungsi di `supabase/migrations/0006_cron_and_retention.sql`:
- `run_session_lifecycle_jobs()` (tiap 15 menit): mengubah sesi menjadi `selesai` 2 jam setelah `end_time`; mengunci chat grup sesi (`is_read_only = true`) 24 jam setelah selesai (`MAN-R9`).
- `run_expiry_jobs()` (tiap jam): kedaluwarsa Kenalan 30 hari, permintaan gabung komunitas 14 hari, tautan ekspor data 7 hari, serta menandai komunitas dengan pengurus pasif >= 90 hari.
- `run_account_purge_jobs()` (harian 02:15 UTC): menghapus permanen akun pada hari ke-30 (`AC-12`) sambil mengubah `messages.sender_id = NULL` & `sender_fallback_label = 'Pengguna terhapus'`.
- `run_retention_cleanup_jobs()` (harian 03:30 UTC): menghapus notifikasi > 90 hari, chat sesi selesai > 12 bulan, laporan & `audit_log` > 12 bulan, `retained_moderated_content` > 30 hari, dan membersihkan `otp_request_logs` > 24 jam.

> **Tugas Infrastruktur Wajib (Cloud Production — PRD 10):** Aktifkan **Daily Automated Backups dengan retensi minimum 30 hari** (atau Point-in-Time Recovery / PITR pada paket Supabase Pro) di Supabase Cloud Dashboard sebelum peluncuran produksi.
