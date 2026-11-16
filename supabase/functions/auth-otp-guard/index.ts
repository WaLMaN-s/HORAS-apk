import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const OTP_RESEND_COOLDOWN_MS = 60_000;
const OTP_WINDOW_MS = 3_600_000;
const OTP_MAX_REQUESTS_PER_HOUR = 5;
const OTP_MAX_WRONG_ATTEMPTS = 5;
const OTP_LOCKOUT_MS = 3_600_000;
const MAX_ACTIVE_DEVICES = 3;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonError(
  status: number,
  code: string,
  message: string,
  extra: Record<string, unknown> = {},
) {
  return new Response(
    JSON.stringify({ ok: false, code, message, ...extra }),
    {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}

function normalizePhoneE164(raw: string): string {
  return raw.trim();
}

function isValidPhoneE164(phone: string): boolean {
  return /^\+[1-9]\d{7,14}$/.test(phone);
}

async function checkPermanentBan(
  supabaseAdmin: ReturnType<typeof createClient>,
  phoneE164: string,
): Promise<boolean> {
  const { data } = await supabaseAdmin
    .from("profiles")
    .select("account_status")
    .eq("phone_e164", phoneE164)
    .maybeSingle();
  return data?.account_status === "permanently_banned";
}

async function enforceMaxDevicesAndLogLogin(
  supabaseAdmin: ReturnType<typeof createClient>,
  params: {
    userId: string;
    deviceKey: string;
    deviceName: string;
    platform: string;
    cityLabel?: string;
  },
) {
  const nowIso = new Date().toISOString();
  const { data: activeDevices } = await supabaseAdmin
    .from("user_devices")
    .select("id, device_key, device_name, logged_in_at")
    .eq("user_id", params.userId)
    .is("revoked_at", null)
    .order("logged_in_at", { ascending: true });

  const others = (activeDevices ?? []).filter((d) => d.device_key !== params.deviceKey);
  const evicted: string[] = [];

  // AUT-R9: Maksimal 3 perangkat aktif; perangkat ke-4 mengeluarkan perangkat tertua.
  while (others.length >= MAX_ACTIVE_DEVICES) {
    const oldest = others.shift();
    if (!oldest) break;
    await supabaseAdmin
      .from("user_devices")
      .update({ revoked_at: nowIso })
      .eq("id", oldest.id);
    evicted.push(oldest.device_name);
  }

  const { data: upserted } = await supabaseAdmin
    .from("user_devices")
    .upsert(
      {
        user_id: params.userId,
        device_key: params.deviceKey,
        device_name: params.deviceName,
        platform: params.platform,
        logged_in_at: nowIso,
        last_active_at: nowIso,
        revoked_at: null,
      },
      { onConflict: "user_id,device_key" },
    )
    .select("id")
    .single();

  await supabaseAdmin.from("login_history").insert({
    user_id: params.userId,
    device_id: upserted?.id ?? null,
    device_name: params.deviceName,
    platform: params.platform,
    city_label: params.cityLabel ?? "",
    logged_in_at: nowIso,
  });

  if (evicted.length > 0) {
    await supabaseAdmin.from("notifications").insert({
      user_id: params.userId,
      type: "sistem_keamanan",
      title: "Perangkat Lama Dikeluarkan",
      body: `Login dari ${params.deviceName} mengeluarkan sesi tertua (${evicted.join(", ")}) karena batas 3 perangkat aktif.`,
      action_route: "/settings/devices",
    });
  }

  // AC-12: Login ulang dalam masa tenggang 30 hari membatalkan penghapusan akun
  const { data: cancelledDeletion } = await supabaseAdmin
    .from("account_deletions")
    .update({ is_cancelled: true, cancelled_at: nowIso })
    .eq("user_id", params.userId)
    .eq("is_cancelled", false)
    .eq("is_permanently_deleted", false)
    .gt("scheduled_permanent_deletion_at", nowIso)
    .select("id")
    .maybeSingle();

  if (cancelledDeletion) {
    await supabaseAdmin
      .from("profiles")
      .update({ deleted_at: null })
      .eq("id", params.userId);
  }

  return { evictedDevices: evicted, deletionCancelled: Boolean(cancelledDeletion) };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonError(405, "VALIDATION_ERROR", "Gunakan metode POST.");
  }

  const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });
  const supabaseAnon = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false },
  });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonError(400, "VALIDATION_ERROR", "Payload JSON tidak valid.");
  }

  const action = String(body.action ?? "");
  const now = new Date();
  const nowMs = now.getTime();

  // -------------------------------------------------------------------------
  // Action: request_otp (AUT-R1, AUT-R2, AUT-R3)
  // -------------------------------------------------------------------------
  if (action === "request_otp") {
    const phoneE164 = normalizePhoneE164(String(body.phoneE164 ?? ""));
    if (!isValidPhoneE164(phoneE164)) {
      return jsonError(
        400,
        "VALIDATION_ERROR",
        "Format nomor HP harus E.164 (contoh +62812...).",
        { field: "phone" },
      );
    }

    if (await checkPermanentBan(supabaseAdmin, phoneE164)) {
      return jsonError(
        403,
        "SUSPENDED",
        "Akun dengan nomor ini diblokir permanen.",
        { canAppeal: false },
      );
    }

    const { data: state } = await supabaseAdmin
      .from("otp_security_state")
      .select("locked_until, last_requested_at")
      .eq("phone_e164", phoneE164)
      .maybeSingle();

    if (state?.locked_until && new Date(state.locked_until).getTime() > nowMs) {
      return jsonError(
        429,
        "RATE_LIMITED",
        "Nomor terkunci sementara selama 1 jam akibat 5 kali salah OTP.",
        { retry_at: state.locked_until },
      );
    }

    if (state?.last_requested_at) {
      const nextResendMs = new Date(state.last_requested_at).getTime() + OTP_RESEND_COOLDOWN_MS;
      if (nextResendMs > nowMs) {
        return jsonError(
          429,
          "RATE_LIMITED",
          "Tunggu 60 detik sebelum meminta kode OTP baru.",
          { retry_at: new Date(nextResendMs).toISOString() },
        );
      }
    }

    const windowStartIso = new Date(nowMs - OTP_WINDOW_MS).toISOString();
    const { data: recentLogs } = await supabaseAdmin
      .from("otp_request_logs")
      .select("created_at")
      .eq("phone_e164", phoneE164)
      .eq("action", "send")
      .gt("created_at", windowStartIso)
      .order("created_at", { ascending: true });

    if ((recentLogs?.length ?? 0) >= OTP_MAX_REQUESTS_PER_HOUR && recentLogs?.[0]) {
      const retryAt = new Date(new Date(recentLogs[0].created_at).getTime() + OTP_WINDOW_MS).toISOString();
      return jsonError(
        429,
        "RATE_LIMITED",
        "Maksimal 5 permintaan OTP per jam.",
        { retry_at: retryAt },
      );
    }

    const { error: otpErr } = await supabaseAnon.auth.signInWithOtp({
      phone: phoneE164,
    });
    if (otpErr) {
      return jsonError(400, "SERVER_ERROR", otpErr.message);
    }

    await supabaseAdmin.from("otp_request_logs").insert({
      phone_e164: phoneE164,
      action: "send",
    });
    await supabaseAdmin.from("otp_security_state").upsert(
      {
        phone_e164: phoneE164,
        last_requested_at: now.toISOString(),
        updated_at: now.toISOString(),
      },
      { onConflict: "phone_e164" },
    );

    return new Response(
      JSON.stringify({
        ok: true,
        resendAvailableAt: new Date(nowMs + OTP_RESEND_COOLDOWN_MS).toISOString(),
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // -------------------------------------------------------------------------
  // Action: verify_otp (AUT-R3 5x salah -> kunci 1 jam, AUT-R9 max 3 device, AC-12)
  // -------------------------------------------------------------------------
  if (action === "verify_otp") {
    const phoneE164 = normalizePhoneE164(String(body.phoneE164 ?? ""));
    const otpCode = String(body.otpCode ?? "").trim();
    if (!isValidPhoneE164(phoneE164) || !/^\d{6}$/.test(otpCode)) {
      return jsonError(400, "VALIDATION_ERROR", "Nomor HP atau kode OTP 6 digit tidak valid.");
    }

    if (await checkPermanentBan(supabaseAdmin, phoneE164)) {
      return jsonError(403, "SUSPENDED", "Akun ini diblokir permanen.", { canAppeal: false });
    }

    const { data: state } = await supabaseAdmin
      .from("otp_security_state")
      .select("wrong_attempts, locked_until")
      .eq("phone_e164", phoneE164)
      .maybeSingle();

    if (state?.locked_until && new Date(state.locked_until).getTime() > nowMs) {
      return jsonError(
        429,
        "RATE_LIMITED",
        "Nomor terkunci selama 1 jam karena 5 kali salah memasukkan OTP.",
        { retry_at: state.locked_until },
      );
    }

    const { data: verifyData, error: verifyErr } = await supabaseAnon.auth.verifyOtp({
      phone: phoneE164,
      token: otpCode,
      type: "sms",
    });

    if (verifyErr || !verifyData.session || !verifyData.user) {
      const nextWrong = (state?.wrong_attempts ?? 0) + 1;
      const shouldLock = nextWrong >= OTP_MAX_WRONG_ATTEMPTS;
      const lockedUntilIso = shouldLock ? new Date(nowMs + OTP_LOCKOUT_MS).toISOString() : null;

      await supabaseAdmin.from("otp_security_state").upsert(
        {
          phone_e164: phoneE164,
          wrong_attempts: nextWrong,
          locked_until: lockedUntilIso,
          updated_at: now.toISOString(),
        },
        { onConflict: "phone_e164" },
      );
      await supabaseAdmin.from("otp_request_logs").insert({
        phone_e164: phoneE164,
        action: shouldLock ? "locked" : "verify_fail",
      });

      if (shouldLock && lockedUntilIso) {
        return jsonError(
          429,
          "RATE_LIMITED",
          "Terlalu banyak percobaan salah. Nomor dikunci selama 1 jam.",
          { retry_at: lockedUntilIso },
        );
      }
      return jsonError(
        400,
        "VALIDATION_ERROR",
        "Kode OTP salah atau sudah kedaluwarsa.",
        { remainingAttempts: Math.max(0, OTP_MAX_WRONG_ATTEMPTS - nextWrong) },
      );
    }

    // Reset OTP lockout state on success
    await supabaseAdmin.from("otp_security_state").upsert(
      {
        phone_e164: phoneE164,
        wrong_attempts: 0,
        locked_until: null,
        updated_at: now.toISOString(),
      },
      { onConflict: "phone_e164" },
    );
    await supabaseAdmin.from("otp_request_logs").insert({
      phone_e164: phoneE164,
      action: "verify_ok",
    });

    const deviceKey = String(body.deviceKey ?? "").trim();
    let deviceResult = { evictedDevices: [] as string[], deletionCancelled: false };
    if (deviceKey.length > 0) {
      deviceResult = await enforceMaxDevicesAndLogLogin(supabaseAdmin, {
        userId: verifyData.user.id,
        deviceKey,
        deviceName: String(body.deviceName ?? "Perangkat HORAS"),
        platform: String(body.platform ?? "android"),
        cityLabel: String(body.cityLabel ?? ""),
      });
    }

    return new Response(
      JSON.stringify({
        ok: true,
        session: verifyData.session,
        user: verifyData.user,
        ...deviceResult,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // -------------------------------------------------------------------------
  // Action: register_device (AUT-R9 + AC-12 setelah login JWT)
  // -------------------------------------------------------------------------
  if (action === "register_device") {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token) {
      return jsonError(401, "PERMISSION_DENIED", "Token Bearer diperlukan.");
    }
    const { data: userRes, error: userErr } = await supabaseAdmin.auth.getUser(token);
    if (userErr || !userRes.user) {
      return jsonError(401, "PERMISSION_DENIED", "Token tidak valid.");
    }

    const deviceKey = String(body.deviceKey ?? "").trim();
    if (!deviceKey) {
      return jsonError(400, "VALIDATION_ERROR", "deviceKey wajib diisi.", { field: "deviceKey" });
    }

    const res = await enforceMaxDevicesAndLogLogin(supabaseAdmin, {
      userId: userRes.user.id,
      deviceKey,
      deviceName: String(body.deviceName ?? "Perangkat HORAS"),
      platform: String(body.platform ?? "android"),
      cityLabel: String(body.cityLabel ?? ""),
    });

    return new Response(
      JSON.stringify({ ok: true, ...res }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  return jsonError(400, "VALIDATION_ERROR", "Action tidak dikenali.");
});
