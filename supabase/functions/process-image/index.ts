import { createClient } from "npm:@supabase/supabase-js@2";
import jpeg from "npm:jpeg-js@0.4.4";
import UPNG from "npm:upng-js@2.1.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const BUCKET_LIMITS: Record<string, number> = {
  avatars: 5 * 1024 * 1024,
  posts: 10 * 1024 * 1024,
  "chat-media": 5 * 1024 * 1024,
  support: 10 * 1024 * 1024,
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonError(status: number, code: string, message: string) {
  return new Response(
    JSON.stringify({ ok: false, code, message }),
    { status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
}

function detectImageType(bytes: Uint8Array): "jpeg" | "png" | null {
  if (bytes.length < 12) return null;
  // JPEG magic: FF D8 FF
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return "jpeg";
  }
  // PNG magic: 89 50 4E 47 0D 0A 1A 0A
  if (
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return "png";
  }
  return null;
}

/**
 * Re-encode piksel gambar (decode -> encode ulang) sehingga seluruh segmen EXIF/GPS/XMP/COM
 * benar-benar hilang dari berkas hasil (PRD BER-R4, AC-10).
 */
function reencodeStripMetadata(input: Uint8Array): {
  bytes: Uint8Array;
  width: number;
  height: number;
  mimeType: string;
  ext: string;
} {
  const kind = detectImageType(input);
  if (!kind) {
    throw new Error("UNSUPPORTED_FORMAT");
  }

  if (kind === "jpeg") {
    const decoded = jpeg.decode(input, { useTArray: true });
    if (!decoded || decoded.width <= 0 || decoded.height <= 0) {
      throw new Error("INVALID_IMAGE");
    }
    const encoded = jpeg.encode(
      { data: decoded.data, width: decoded.width, height: decoded.height },
      88,
    );
    return {
      bytes: new Uint8Array(encoded.data),
      width: decoded.width,
      height: decoded.height,
      mimeType: "image/jpeg",
      ext: "jpg",
    };
  }

  // PNG decode -> re-encode tanpa chunk teks/eXIf
  const decoded = UPNG.decode(input.buffer.slice(input.byteOffset, input.byteOffset + input.byteLength));
  const rgbaFrames = UPNG.toRGBA8(decoded);
  if (!rgbaFrames || rgbaFrames.length === 0 || decoded.width <= 0 || decoded.height <= 0) {
    throw new Error("INVALID_IMAGE");
  }
  const encodedBuf = UPNG.encode([rgbaFrames[0]], decoded.width, decoded.height, 0);
  return {
    bytes: new Uint8Array(encodedBuf),
    width: decoded.width,
    height: decoded.height,
    mimeType: "image/png",
    ext: "png",
  };
}

function decodeBase64(b64: string): Uint8Array {
  const clean = b64.includes(",") ? b64.split(",").pop() ?? "" : b64;
  const bin = atob(clean);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) {
    out[i] = bin.charCodeAt(i);
  }
  return out;
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

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return jsonError(401, "PERMISSION_DENIED", "Autentikasi Bearer diperlukan.");
  }
  const { data: userRes, error: userErr } = await supabaseAdmin.auth.getUser(token);
  if (userErr || !userRes.user) {
    return jsonError(401, "PERMISSION_DENIED", "Token pengguna tidak valid.");
  }
  const userId = userRes.user.id;

  let bucket = "";
  let conversationId = "";
  let rawBytes: Uint8Array | null = null;

  const contentType = req.headers.get("Content-Type") ?? "";
  if (contentType.includes("multipart/form-data")) {
    const form = await req.formData();
    bucket = String(form.get("bucket") ?? "");
    conversationId = String(form.get("conversationId") ?? "").trim();
    const file = form.get("file");
    if (file instanceof File) {
      rawBytes = new Uint8Array(await file.arrayBuffer());
    }
  } else {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(400, "VALIDATION_ERROR", "Body request tidak valid.");
    }
    bucket = String(body.bucket ?? "");
    conversationId = String(body.conversationId ?? "").trim();
    if (typeof body.base64Data === "string") {
      rawBytes = decodeBase64(body.base64Data);
    }
  }

  if (!Object.prototype.hasOwnProperty.call(BUCKET_LIMITS, bucket)) {
    return jsonError(400, "VALIDATION_ERROR", "Bucket tujuan tidak valid.");
  }
  if (!rawBytes || rawBytes.byteLength === 0) {
    return jsonError(400, "VALIDATION_ERROR", "Berkas gambar tidak ditemukan.");
  }
  if (rawBytes.byteLength > BUCKET_LIMITS[bucket]) {
    return jsonError(400, "VALIDATION_ERROR", `Ukuran gambar melebihi batas bucket ${bucket}.`);
  }

  if (bucket === "chat-media") {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(conversationId)) {
      return jsonError(400, "VALIDATION_ERROR", "conversationId UUID valid wajib diisi untuk chat-media.");
    }
    const { data: part } = await supabaseAdmin
      .from("conversation_participants")
      .select("user_id")
      .eq("conversation_id", conversationId)
      .eq("user_id", userId)
      .maybeSingle();
    if (!part) {
      return jsonError(403, "PERMISSION_DENIED", "Kamu bukan peserta percakapan ini.");
    }
  }

  let cleaned: ReturnType<typeof reencodeStripMetadata>;
  try {
    cleaned = reencodeStripMetadata(rawBytes);
  } catch (err) {
    const msg = err instanceof Error && err.message === "UNSUPPORTED_FORMAT"
      ? "Hanya gambar JPEG dan PNG yang didukung untuk pembersihan metadata EXIF/GPS."
      : "Berkas gambar rusak atau tidak dapat diproses.";
    return jsonError(400, "VALIDATION_ERROR", msg);
  }

  const fileId = crypto.randomUUID();
  const objectPath = bucket === "chat-media"
    ? `${userId}/${conversationId}/${fileId}.${cleaned.ext}`
    : `${userId}/${fileId}.${cleaned.ext}`;

  const { error: uploadErr } = await supabaseAdmin.storage
    .from(bucket)
    .upload(objectPath, cleaned.bytes, {
      contentType: cleaned.mimeType,
      upsert: false,
    });

  if (uploadErr) {
    return jsonError(500, "SERVER_ERROR", `Gagal mengunggah gambar bersih: ${uploadErr.message}`);
  }

  const publicUrl = bucket === "avatars"
    ? supabaseAdmin.storage.from("avatars").getPublicUrl(objectPath).data.publicUrl
    : null;

  return new Response(
    JSON.stringify({
      ok: true,
      bucket,
      path: objectPath,
      publicUrl,
      mimeType: cleaned.mimeType,
      width: cleaned.width,
      height: cleaned.height,
      sizeBytes: cleaned.bytes.byteLength,
      exifStripped: true,
    }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
