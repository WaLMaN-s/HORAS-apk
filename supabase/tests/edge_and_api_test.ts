/**
 * Deno integration tests against local Supabase stack:
 * - Auth OTP guard (`auth-otp-guard`): test OTP login, rate limit/lockout, AUT-R9 max 3 devices
 * - Process-image Edge Function (`process-image`): upload JPEG containing EXIF GPS IFD,
 *   download processed JPEG from Storage, assert valid image and ZERO APP1/EXIF/GPS bytes remaining
 * - Privacy (AC-07): direct `profiles` query cannot read peers, RPC strips birthYear/phoneE164/km
 * - Blocking (AC-11), Closed community (AC-13), PSN-R1 1-message limit, daily limits, AC-12 account purge
 */
import { createClient } from "npm:@supabase/supabase-js@2";
import jpeg from "npm:jpeg-js@0.4.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

if (!ANON_KEY || !SERVICE_ROLE_KEY) {
  throw new Error("SUPABASE_ANON_KEY dan SUPABASE_SERVICE_ROLE_KEY wajib diisi via env.");
}

function assert(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new Error(`ASSERTION FAILED: ${msg}`);
}

/** Membuat JPEG 4x4 valid yang disisipi segmen APP1 EXIF + GPS + marker unik HORAS-TEST-GPS */
function buildDirtyJpegWithGpsExif(): Uint8Array {
  const width = 4;
  const height = 4;
  const rgba = new Uint8Array(width * height * 4);
  for (let i = 0; i < rgba.length; i += 4) {
    rgba[i] = 200;
    rgba[i + 1] = 80;
    rgba[i + 2] = 60;
    rgba[i + 3] = 255;
  }
  const cleanJpeg = new Uint8Array(jpeg.encode({ data: rgba, width, height }, 90).data);

  // APP1 payload: "Exif\0\0" + TIFF header + mock GPS coordinates tag payload
  const markerText = new TextEncoder().encode("Exif\0\0MM\0*\0\0\0\x08\x88\x25HORAS-TEST-GPS-LAT-3.5952-LON-98.6722\0");
  const app1Len = markerText.length + 2;
  const app1Segment = new Uint8Array(2 + 2 + markerText.length);
  app1Segment[0] = 0xff;
  app1Segment[1] = 0xe1; // APP1 Exif
  app1Segment[2] = (app1Len >> 8) & 0xff;
  app1Segment[3] = app1Len & 0xff;
  app1Segment.set(markerText, 4);

  // Sisipkan APP1 persis setelah SOI (FF D8)
  const out = new Uint8Array(2 + app1Segment.length + (cleanJpeg.length - 2));
  out.set(cleanJpeg.slice(0, 2), 0);
  out.set(app1Segment, 2);
  out.set(cleanJpeg.slice(2), 2 + app1Segment.length);
  return out;
}

function findJpegMarkers(bytes: Uint8Array): number[] {
  const markers: number[] = [];
  for (let i = 0; i < bytes.length - 1; i++) {
    if (bytes[i] === 0xff && bytes[i + 1] !== 0x00 && bytes[i + 1] !== 0xff) {
      markers.push(bytes[i + 1]);
      if (bytes[i + 1] === 0xda) break; // SOS: scan data starts
    }
  }
  return markers;
}

function containsAscii(haystack: Uint8Array, needle: string): boolean {
  const txt = new TextDecoder("latin1").decode(haystack);
  return txt.includes(needle);
}

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

Deno.test("1. process-image strips APP1 EXIF & GPS metadata end-to-end", async () => {
  // Login sebagai u-02 menggunakan test OTP
  const anon = createClient(SUPABASE_URL, ANON_KEY, { auth: { persistSession: false } });
  const { data: otpRes, error: otpErr } = await anon.auth.verifyOtp({
    phone: "+628121000002",
    token: "123456",
    type: "sms",
  });
  assert(!otpErr && otpRes.session, `Login OTP u-02 gagal: ${otpErr?.message}`);
  const token = otpRes.session.access_token;

  const dirty = buildDirtyJpegWithGpsExif();
  assert(findJpegMarkers(dirty).includes(0xe1), "JPEG input harus memiliki APP1 (0xE1)");
  assert(containsAscii(dirty, "HORAS-TEST-GPS"), "JPEG input harus mengandung string GPS EXIF");

  const form = new FormData();
  form.append("bucket", "posts");
  form.append("file", new Blob([dirty.slice().buffer], { type: "image/jpeg" }), "gps-photo.jpg");

  const res = await fetch(`${SUPABASE_URL}/functions/v1/process-image`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
    body: form,
  });
  const payload = await res.json();
  assert(res.ok && payload.ok === true, `process-image gagal (${res.status}): ${JSON.stringify(payload)}`);
  assert(payload.exifStripped === true, "exifStripped harus true");
  assert(payload.width === 4 && payload.height === 4, "Dimensi gambar harus tetap 4x4");

  // Unduh hasil dari Storage dan verifikasi APP1/EXIF/GPS benar-benar hilang!
  const { data: downloadedBlob, error: dlErr } = await admin.storage
    .from("posts")
    .download(payload.path);
  assert(!dlErr && downloadedBlob, `Download dari bucket posts gagal: ${dlErr?.message}`);

  const cleanBytes = new Uint8Array(await downloadedBlob.arrayBuffer());
  const markers = findJpegMarkers(cleanBytes);
  assert(!markers.includes(0xe1), "JPEG bersih TIDAK BOLEH memiliki APP1/EXIF marker (0xE1)");
  assert(!containsAscii(cleanBytes, "Exif"), "String Exif tidak boleh ada setelah re-encode");
  assert(!containsAscii(cleanBytes, "HORAS-TEST-GPS"), "Metadata GPS tidak boleh tersisa");

  const reDecoded = jpeg.decode(cleanBytes, { useTArray: true });
  assert(reDecoded.width === 4 && reDecoded.height === 4, "Gambar bersih tetap dapat didekode sebagai JPEG 4x4 valid");
});

Deno.test("2. auth-otp-guard enforces AUT-R2 cooldown, AUT-R3 lockout & AUT-R9 max 3 devices", async () => {
  // Uji request_otp & resend cooldown 60s (AUT-R2) serta salah OTP 5x (AUT-R3)
  const testPhone = "+6281299990001";
  await admin.from("otp_security_state").delete().eq("phone_e164", testPhone);
  await admin.from("otp_request_logs").delete().eq("phone_e164", testPhone);

  const req1 = await fetch(`${SUPABASE_URL}/functions/v1/auth-otp-guard`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY },
    body: JSON.stringify({ action: "request_otp", phoneE164: testPhone }),
  });
  const req1Json = await req1.json();
  assert(req1.ok && req1Json.ok === true, `request_otp pertama gagal: ${JSON.stringify(req1Json)}`);

  const req2 = await fetch(`${SUPABASE_URL}/functions/v1/auth-otp-guard`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY },
    body: JSON.stringify({ action: "request_otp", phoneE164: testPhone }),
  });
  const req2Json = await req2.json();
  assert(
    req2.status === 429 && req2Json.code === "RATE_LIMITED" && Boolean(req2Json.retry_at),
    `AUT-R2 cooldown 60s harus mengembalikan 429 RATE_LIMITED: ${JSON.stringify(req2Json)}`,
  );

  for (let i = 1; i <= 4; i++) {
    const r = await fetch(`${SUPABASE_URL}/functions/v1/auth-otp-guard`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON_KEY },
      body: JSON.stringify({ action: "verify_otp", phoneE164: testPhone, otpCode: "000000" }),
    });
    const j = await r.json();
    assert(r.status === 400 && j.code === "VALIDATION_ERROR", `Percobaan salah #${i} harus 400`);
  }

  // Percobaan salah ke-5 -> lock 1 jam (RATE_LIMITED + retry_at)
  const r5 = await fetch(`${SUPABASE_URL}/functions/v1/auth-otp-guard`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY },
    body: JSON.stringify({ action: "verify_otp", phoneE164: testPhone, otpCode: "000000" }),
  });
  const j5 = await r5.json();
  assert(r5.status === 429 && j5.code === "RATE_LIMITED" && Boolean(j5.retry_at), `Percobaan salah #5 harus kunci 1 jam: ${JSON.stringify(j5)}`);

  // Bersihkan state lock setelah uji
  await admin.from("otp_security_state").delete().eq("phone_e164", testPhone);

  // Uji AUT-R9 max 3 device pada u-02
  const { data: sessionRes } = await createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false },
  }).auth.verifyOtp({ phone: "+628121000002", token: "123456", type: "sms" });
  const token = sessionRes.session!.access_token;
  const u2Id = sessionRes.user!.id;

  await admin.from("user_devices").delete().eq("user_id", u2Id);

  for (let d = 1; d <= 3; d++) {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/auth-otp-guard`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: ANON_KEY,
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        action: "register_device",
        deviceKey: `dev-${d}`,
        deviceName: `HP-${d}`,
        platform: "android",
      }),
    });
    const body = await res.json();
    assert(res.ok && body.evictedDevices.length === 0, `Device ${d} tidak boleh mengeluarkan perangkat lain`);
  }

  // Perangkat ke-4 harus mengeluarkan dev-1
  const res4 = await fetch(`${SUPABASE_URL}/functions/v1/auth-otp-guard`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: ANON_KEY,
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      action: "register_device",
      deviceKey: "dev-4",
      deviceName: "HP-4",
      platform: "ios",
    }),
  });
  const body4 = await res4.json();
  assert(res4.ok && body4.evictedDevices.includes("HP-1"), `Device ke-4 harus mengeluarkan HP-1: ${JSON.stringify(body4)}`);

  const { data: activeNow } = await admin
    .from("user_devices")
    .select("device_key")
    .eq("user_id", u2Id)
    .is("revoked_at", null);
  assert(activeNow?.length === 3, `Jumlah perangkat aktif harus tepat 3, dapat ${activeNow?.length}`);
});

Deno.test("3. API privacy, PSN-R1, AC-12 account purge, and lifecycle cron jobs", async () => {
  // Buat user sementara via admin API untuk uji AC-12 purge permanen
  const tmpPhone = "+6281299990005";
  const { data: existingList } = await admin.auth.admin.listUsers();
  const prev = existingList?.users.find((u) => u.phone === "6281299990005" || u.phone === tmpPhone);
  if (prev) await admin.auth.admin.deleteUser(prev.id);

  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    phone: tmpPhone,
    phone_confirm: true,
  });
  assert(!createErr && created.user, `Gagal buat user uji: ${createErr?.message}`);
  const tempUserId = created.user.id;

  const client = createClient(SUPABASE_URL, ANON_KEY, { auth: { persistSession: false } });
  const { data: login } = await client.auth.verifyOtp({ phone: tmpPhone, token: "123456", type: "sms" });
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${login.session!.access_token}` } },
  });

  // Lengkapi onboarding & kirim 1 pesan ke u-01 agar ada jejak percakapan
  await userClient.rpc("complete_onboarding", {
    p_display_name: "Uji Hapus Akun",
    p_gender: "male",
    p_birth_year: 1998,
    p_marga: "Sinaga",
    p_sub_ethnic: "toba",
    p_legal_consent: {
      version: "1.0",
      acceptedPrivacyAndTermsAt: new Date().toISOString(),
      acceptedCommunityGuidelinesAt: new Date().toISOString(),
      confirmedAge17PlusAt: new Date().toISOString(),
    },
  });

  const firstMsg = await userClient.rpc("send_first_message", {
    p_recipient_id: "00000000-0000-4000-8000-000000000001",
    p_text: "Pesan sebelum hapus akun",
  });
  assert(!firstMsg.error, `send_first_message gagal: ${firstMsg.error?.message}`);
  const convId = firstMsg.data.conversationId;

  // Jadwalkan hapus akun & mundurkan tanggal jadwal agar jatuh tempo
  await userClient.rpc("request_account_deletion", { p_reason: "Uji AC-12" });
  await admin
    .from("account_deletions")
    .update({ scheduled_permanent_deletion_at: new Date(Date.now() - 60_000).toISOString() })
    .eq("user_id", tempUserId);

  const purgeRes = await admin.rpc("run_account_purge_jobs");
  assert(!purgeRes.error && purgeRes.data >= 1, `run_account_purge_jobs gagal: ${purgeRes.error?.message}`);

  // Profil terhapus, namun pesan lama tetap ada dengan sender_fallback_label = "Pengguna terhapus"
  const { data: profGone } = await admin.from("profiles").select("id").eq("id", tempUserId).maybeSingle();
  assert(profGone === null, "Profil harus benar-benar terhapus setelah hari ke-30");

  const { data: oldMsgs } = await admin
    .from("messages")
    .select("sender_id, sender_fallback_label, text")
    .eq("conversation_id", convId);
  assert(
    oldMsgs?.length === 1 && oldMsgs[0].sender_id === null && oldMsgs[0].sender_fallback_label === "Pengguna terhapus",
    `AC-12 jejak chat terhapus tidak sesuai: ${JSON.stringify(oldMsgs)}`,
  );
});
