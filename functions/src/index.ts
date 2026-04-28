import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import { getAuth } from 'firebase-admin/auth';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';
import { RtcTokenBuilder, RtcRole } from 'agora-access-token';

admin.initializeApp();

// ── Constants ──────────────────────────────────────────────────────────────────
const APP_ID = '443105d5684f492088bb004196b3fee8';
const TOKEN_TTL_SECONDS = 3600; // 1 hour

// App Certificate is injected at deploy time via .env.vyooov1
const APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE ?? '';

// Cloudflare Stream credentials — set in .env.vyooov1
const CF_ACCOUNT_ID = process.env.CLOUDFLARE_ACCOUNT_ID ?? '';
const CF_API_TOKEN = process.env.CLOUDFLARE_API_TOKEN ?? '';
const HIVE_API_KEY = (process.env.HIVE_API_KEY ?? '').trim();
const HIVE_ACCESS_KEY = (process.env.HIVE_ACCESS_KEY ?? '').trim();
const HIVE_SECRET_KEY = (process.env.HIVE_SECRET_KEY ?? '').trim();
const HIVE_V3_BEARER = HIVE_SECRET_KEY || HIVE_API_KEY;
const HIVE_V2_TOKEN = HIVE_ACCESS_KEY || HIVE_API_KEY;
const HIVE_MODERATION_URL = 'https://api.thehive.ai/api/v3/hive/visual-moderation';
const HIVE_V2_SYNC_URL = 'https://api.thehive.ai/api/v2/task/sync';
const HIVE_BLOCK_THRESHOLD = 0.95;
const HIVE_REVIEW_THRESHOLD = 0.90;

// Resend (email OTP). Set RESEND_API_KEY in environment (e.g. functions/.env.vyooov1 — gitignored).
// Set RESEND_FROM_EMAIL to an address on your verified domain (e.g. noreply@vyooo.com). If you omit it,
// the default onboarding@resend.dev sender applies — Resend then only allows "test" recipients (account email).
const RESEND_API_KEY = (process.env.RESEND_API_KEY ?? '').trim();
const RESEND_FROM_EMAIL = (
  process.env.RESEND_FROM_EMAIL ?? 'Vyooo <onboarding@resend.dev>'
).trim();

function parseResendFailureMessage(status: number, body: string): string {
  try {
    const j = JSON.parse(body) as { message?: unknown };
    const m = typeof j.message === 'string' ? j.message.trim() : '';
    if (m.length > 0) {
      return m.length <= 400 ? m : `${m.slice(0, 397)}…`;
    }
  } catch {
    /* not JSON */
  }
  if (status === 401 || status === 403) {
    return 'Email service rejected the request. Check RESEND_API_KEY.';
  }
  if (status === 422) {
    return (
      'Invalid email request. Verify a domain at resend.com/domains and set RESEND_FROM_EMAIL to an address ' +
      'on that domain (required to deliver OTP to any inbox).'
    );
  }
  return `Could not send email (HTTP ${status}).`;
}

const EMAIL_OTP_TTL_MS = 10 * 60 * 1000;
const EMAIL_OTP_MAX_ATTEMPTS = 8;
const EMAIL_OTP_RESEND_COOLDOWN_MS = 60 * 1000;
const WHATSAPP_OTP_TTL_MS = 10 * 60 * 1000;
const WHATSAPP_OTP_MAX_ATTEMPTS = 8;
const WHATSAPP_OTP_RESEND_COOLDOWN_MS = 60 * 1000;
const TWILIO_ACCOUNT_SID = (process.env.TWILIO_ACCOUNT_SID ?? '').trim();
const TWILIO_AUTH_TOKEN = (process.env.TWILIO_AUTH_TOKEN ?? '').trim();
const TWILIO_WHATSAPP_FROM = (process.env.TWILIO_WHATSAPP_FROM ?? '').trim();

function normalizeWhatsAppSender(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) return '';
  return trimmed.toLowerCase().startsWith('whatsapp:')
    ? trimmed
    : `whatsapp:${trimmed}`;
}

function parseTwilioWhatsAppFailureMessage(status: number, body: string): string {
  try {
    const parsed = JSON.parse(body) as { code?: unknown; message?: unknown };
    const code = typeof parsed.code === 'number' ? parsed.code : null;
    const message = typeof parsed.message === 'string' ? parsed.message.trim() : '';
    if (code === 63015) {
      return 'This WhatsApp number is not enabled in your Twilio sandbox. Send the sandbox join code first, then retry.';
    }
    if (code === 21606) {
      return 'Invalid Twilio WhatsApp sender. Set TWILIO_WHATSAPP_FROM to whatsapp:+14155238886 (or your approved business sender).';
    }
    if (message.length > 0) {
      return message.length <= 300 ? message : `${message.slice(0, 297)}...`;
    }
  } catch {
    // Non-JSON body.
  }
  if (status === 401 || status === 403) {
    return 'Twilio credentials are invalid. Check TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN.';
  }
  return `Could not send WhatsApp code (HTTP ${status}).`;
}

function hashEmailOtp(uid: string, plain: string): string {
  return crypto
    .createHash('sha256')
    .update(`vyooo-otp-v1:${RESEND_API_KEY}:${uid}:${plain}`, 'utf8')
    .digest('hex');
}

function hashWhatsAppOtp(uid: string, phone: string, plain: string): string {
  return crypto
    .createHash('sha256')
    .update(`vyooo-wa-otp-v1:${TWILIO_ACCOUNT_SID}:${uid}:${phone}:${plain}`, 'utf8')
    .digest('hex');
}

function normalizePhone(raw: unknown): string {
  const asString = typeof raw === 'string' ? raw.trim() : '';
  if (!asString) return '';
  const normalized = asString.replace(/[^\d+]/g, '');
  if (!normalized.startsWith('+')) return '';
  if (!/^\+\d{8,16}$/.test(normalized)) return '';
  return normalized;
}

// ── generateAgoraTokenOnRequest ────────────────────────────────────────────────
/**
 * Firestore-triggered token generator.
 *
 * Triggered when a document is created at: token_requests/{requestId}
 * Expected fields: { userId, channelName, uid, role }
 * Writes back:     { status: 'done', token, expiresAt }
 *               or { status: 'error', error }
 *
 * This approach avoids the Cloud Run IAM `allUsers` requirement that is blocked
 * by the metatech.ae org policy. Firestore triggers run inside Google's
 * infrastructure and don't require public HTTP access.
 */
export const generateAgoraTokenOnRequest = onDocumentCreated(
  {
    document: 'token_requests/{requestId}',
    timeoutSeconds: 10,
    memory: '128MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() as {
      userId?: unknown;
      channelName?: unknown;
      uid?: unknown;
      role?: unknown;
    };

    // ── Validate ───────────────────────────────────────────────────────────────
    if (
      typeof data.userId !== 'string' ||
      typeof data.channelName !== 'string' ||
      !data.channelName.trim() ||
      typeof data.uid !== 'number' ||
      (data.role !== 'publisher' && data.role !== 'subscriber')
    ) {
      await snap.ref.update({ status: 'error', error: 'Invalid request fields.' });
      return;
    }

    if (!APP_CERTIFICATE) {
      await snap.ref.update({ status: 'error', error: 'AGORA_APP_CERTIFICATE not configured.' });
      return;
    }

    // ── Mint token ─────────────────────────────────────────────────────────────
    try {
      const channelName = data.channelName.trim();
      const uid = data.uid as number;
      const role = data.role === 'publisher' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;

      const nowSeconds = Math.floor(Date.now() / 1000);
      const privilegeExpireTime = nowSeconds + TOKEN_TTL_SECONDS;

      const token = RtcTokenBuilder.buildTokenWithUid(
        APP_ID,
        APP_CERTIFICATE,
        channelName,
        uid,
        role,
        privilegeExpireTime,
      );

      await snap.ref.update({ status: 'done', token, expiresAt: privilegeExpireTime });
    } catch (e) {
      await snap.ref.update({ status: 'error', error: String(e) });
    }
  },
);

// ── getCloudflareUploadUrl ─────────────────────────────────────────────────────
/**
 * Firestore-triggered function — same pattern as generateAgoraTokenOnRequest
 * to avoid the org-policy IAM allUsers restriction.
 *
 * Flutter creates:  cloudflare_upload_requests/{requestId}  { userId }
 * Function writes back: { status: 'done', videoId, uploadUrl }
 *                    or { status: 'error', error }
 */
export const getCloudflareUploadUrl = onDocumentCreated(
  {
    document: 'cloudflare_upload_requests/{requestId}',
    timeoutSeconds: 30,
    memory: '128MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() as { userId?: unknown };

    if (typeof data.userId !== 'string' || !data.userId) {
      await snap.ref.update({ status: 'error', error: 'Missing userId.' });
      return;
    }

    if (!CF_ACCOUNT_ID || !CF_API_TOKEN) {
      await snap.ref.update({ status: 'error', error: 'Cloudflare credentials not configured.' });
      return;
    }

    try {
      const response = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/stream/direct_upload`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${CF_API_TOKEN}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ maxDurationSeconds: 600, requireSignedURLs: false }),
        },
      );

      if (!response.ok) {
        await snap.ref.update({ status: 'error', error: `Cloudflare API error: ${response.status}` });
        return;
      }

      const result = await response.json() as {
        result: { uid: string; uploadURL: string };
        success: boolean;
      };

      if (!result.success) {
        await snap.ref.update({ status: 'error', error: 'Cloudflare returned failure.' });
        return;
      }

      await snap.ref.update({
        status: 'done',
        videoId: result.result.uid,
        uploadUrl: result.result.uploadURL,
      });
    } catch (e) {
      await snap.ref.update({ status: 'error', error: String(e) });
    }
  },
);

// ── syncFollowersCountOnFollowingChange ───────────────────────────────────────
/**
 * Keeps users/{uid}.followersCount in sync based on changes to users/{uid}.following.
 *
 * We diff `following` before/after and increment/decrement each affected target
 * user's followersCount atomically. This avoids expensive count queries in app UI.
 */
export const syncFollowersCountOnFollowingChange = onDocumentWritten(
  {
    document: 'users/{userId}',
    timeoutSeconds: 20,
    memory: '256MiB',
  },
  async (event) => {
    const beforeData = event.data?.before.data() as { following?: unknown } | undefined;
    const afterData = event.data?.after.data() as { following?: unknown } | undefined;
    const before = Array.isArray(beforeData?.following)
      ? beforeData!.following.map((v) => String(v))
      : [];
    const after = Array.isArray(afterData?.following)
      ? afterData!.following.map((v) => String(v))
      : [];

    const beforeSet = new Set(before);
    const afterSet = new Set(after);

    const added: string[] = [];
    const removed: string[] = [];
    for (const id of afterSet) {
      if (!beforeSet.has(id)) added.push(id);
    }
    for (const id of beforeSet) {
      if (!afterSet.has(id)) removed.push(id);
    }
    if (!added.length && !removed.length) return;

    const db = admin.firestore();
    const writes: Promise<unknown>[] = [];
    for (const targetUid of added) {
      if (!targetUid) continue;
      writes.push(
        db.collection('users').doc(targetUid).set(
          { followersCount: admin.firestore.FieldValue.increment(1) },
          { merge: true },
        ),
      );
    }
    for (const targetUid of removed) {
      if (!targetUid) continue;
      writes.push(
        db.collection('users').doc(targetUid).set(
          { followersCount: admin.firestore.FieldValue.increment(-1) },
          { merge: true },
        ),
      );
    }
    await Promise.all(writes);
  },
);

// ── moderateReelOnCreate (Hive Visual Moderation) ────────────────────────────
type HiveClassScore = { class: string; score: number };
type HiveV3Class = { class_name?: unknown; value?: unknown };
type HiveV3OutputItem = { classes?: unknown };
type HiveV3Payload = { output?: unknown };
type HiveRequestResult = {
  ok: boolean;
  status: number;
  endpoint: 'v3' | 'v2';
  payloadText: string;
};

function toHiveImageUrl(videoUrl: string): string {
  // Cloudflare Stream HLS URL:
  // https://<subdomain>/<videoId>/manifest/video.m3u8
  // Convert to thumbnail image supported by Hive image moderation:
  // https://<subdomain>/<videoId>/thumbnails/thumbnail.jpg
  const m = videoUrl.match(/^(https?:\/\/[^/]+)\/([^/]+)\/manifest\/video\.m3u8$/i);
  if (!m) return videoUrl;
  return `${m[1]}/${m[2]}/thumbnails/thumbnail.jpg`;
}

function evaluateHive(classes: HiveClassScore[]): {
  status: 'clear' | 'review' | 'blocked';
  score: number;
  reasons: string[];
} {
  const denySignals = [
    'general_nsfw',
    'yes_sexual_activity',
    'yes_realistic_nsfw',
    'yes_female_nudity',
    'yes_male_nudity',
    'yes_genitals',
    'yes_blood',
    'very_bloody',
    'yes_self_harm',
    'yes_animal_abuse',
    'gun_in_hand',
    'knife_in_hand',
    'yes_terrorist',
    'yes_nazi',
    'yes_kkk',
  ];
  let max = 0;
  const reasons: string[] = [];
  for (const c of classes) {
    if (!denySignals.some((s) => c.class === s)) continue;
    if (c.score > max) max = c.score;
    if (c.score >= HIVE_REVIEW_THRESHOLD) reasons.push(c.class);
  }
  if (max >= HIVE_BLOCK_THRESHOLD) {
    return { status: 'blocked', score: max, reasons };
  }
  if (max >= HIVE_REVIEW_THRESHOLD) {
    return { status: 'review', score: max, reasons };
  }
  return { status: 'clear', score: max, reasons };
}

function extractHiveClassScores(payload: HiveV3Payload): HiveClassScore[] {
  const output = Array.isArray(payload.output) ? payload.output : [];
  const maxScores = new Map<string, number>();
  for (const item of output) {
    const maybeItem = item as HiveV3OutputItem;
    const classes = Array.isArray(maybeItem.classes) ? maybeItem.classes : [];
    for (const c of classes) {
      const entry = c as HiveV3Class;
      const className = typeof entry.class_name === 'string' ? entry.class_name.trim() : '';
      const value = typeof entry.value === 'number' ? entry.value : NaN;
      if (!className || !Number.isFinite(value)) continue;
      const prev = maxScores.get(className) ?? 0;
      if (value > prev) maxScores.set(className, value);
    }
  }
  return Array.from(maxScores.entries()).map(([className, score]) => ({
    class: className,
    score,
  }));
}

function summarizeErrorBody(body: string): string {
  const trimmed = body.trim();
  if (!trimmed) return 'empty_response';
  const compact = trimmed.replace(/\s+/g, ' ');
  return compact.length <= 180 ? compact : `${compact.slice(0, 177)}...`;
}

async function callHiveModeration(mediaUrl: string): Promise<HiveRequestResult> {
  // Preferred path: Hive V3 Visual Moderation API.
  const v3Res = await fetch(HIVE_MODERATION_URL, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${HIVE_V3_BEARER}`,
      'Content-Type': 'application/json',
      accept: 'application/json',
    },
    body: JSON.stringify({
      input: [{ media_url: mediaUrl }],
    }),
  });
  const v3Text = await v3Res.text();
  const v3FallbackOn = new Set([401, 403, 404]);
  if (v3Res.ok || !v3FallbackOn.has(v3Res.status)) {
    return {
      ok: v3Res.ok,
      status: v3Res.status,
      endpoint: 'v3',
      payloadText: v3Text,
    };
  }

  // Backward-compatible fallback for projects still provisioned on legacy endpoint/key format.
  const form = new FormData();
  form.append('url', mediaUrl);
  const v2Res = await fetch(HIVE_V2_SYNC_URL, {
    method: 'POST',
    headers: {
      authorization: `Token ${HIVE_V2_TOKEN}`,
      accept: 'application/json',
    },
    body: form,
  });
  const v2Text = await v2Res.text();
  return {
    ok: v2Res.ok,
    status: v2Res.status,
    endpoint: 'v2',
    payloadText: v2Text,
  };
}

export const moderateReelOnCreate = onDocumentCreated(
  {
    document: 'reels/{reelId}',
    timeoutSeconds: 25,
    memory: '256MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const reelId = event.params.reelId as string;
    const data = snap.data() as { videoUrl?: unknown; imageUrl?: unknown; thumbnailUrl?: unknown };
    logger.info(`[moderateReelOnCreate] start reelId=${reelId}`);
    if (!HIVE_V3_BEARER && !HIVE_V2_TOKEN) {
      logger.warn(`[moderateReelOnCreate] skipped_missing_key reelId=${reelId}`);
      await snap.ref.set(
        {
          moderation: {
            provider: 'hive',
            status: 'skipped',
            score: 0,
            reasons: ['missing_hive_api_key'],
            checkedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );
      return;
    }

    const videoUrl = typeof data.videoUrl === 'string' ? data.videoUrl.trim() : '';
    const imageUrl = typeof data.imageUrl === 'string' ? data.imageUrl.trim() : '';
    const thumbnailUrl = typeof data.thumbnailUrl === 'string' ? data.thumbnailUrl.trim() : '';
    const mediaUrl = imageUrl || thumbnailUrl || (videoUrl ? toHiveImageUrl(videoUrl) : '');
    if (!mediaUrl) {
      logger.warn(`[moderateReelOnCreate] no_media_url reelId=${reelId}`);
      return;
    }

    try {
      const res = await callHiveModeration(mediaUrl);
      logger.info(
        `[moderateReelOnCreate] hive_http_status reelId=${reelId} endpoint=${res.endpoint} status=${res.status} ok=${res.ok}`,
      );
      if (!res.ok) {
        const errSummary = summarizeErrorBody(res.payloadText);
        logger.error(
          `[moderateReelOnCreate] hive_http_error reelId=${reelId} endpoint=${res.endpoint} status=${res.status} body=${errSummary}`,
        );
        await snap.ref.set(
          {
            moderation: {
              provider: 'hive',
              status: 'error',
              score: 0,
              reasons: [`http_${res.status}`, `hive_endpoint:${res.endpoint}`, `hive:${errSummary}`],
              checkedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          { merge: true },
        );
        return;
      }
      let classes: HiveClassScore[] = [];
      if (res.endpoint === 'v3') {
        const payload = JSON.parse(res.payloadText) as HiveV3Payload;
        classes = extractHiveClassScores(payload);
      } else {
        const payload = JSON.parse(res.payloadText) as { output?: Array<{ classes?: HiveClassScore[] }> };
        classes = payload.output?.[0]?.classes ?? [];
      }
      const result = evaluateHive(classes);
      await snap.ref.set(
        {
          moderation: {
            provider: 'hive',
            status: result.status,
            score: result.score,
            reasons: result.reasons,
            mediaUrl,
            checkedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );
      logger.info(
        `[moderateReelOnCreate] final_status reelId=${reelId} status=${result.status} score=${result.score} reasons=${result.reasons.join('|')}`,
      );
    } catch (e) {
      logger.error(`[moderateReelOnCreate] exception reelId=${reelId} error=${String(e)}`);
      await snap.ref.set(
        {
          moderation: {
            provider: 'hive',
            status: 'error',
            score: 0,
            reasons: [String(e)],
            checkedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );
    }
  },
);

// Re-run moderation when media URL changes or moderation is reset to pending.
export const moderateReelOnWrite = onDocumentWritten(
  {
    document: 'reels/{reelId}',
    timeoutSeconds: 25,
    memory: '256MiB',
  },
  async (event) => {
    const before = event.data?.before.data() as
      | { videoUrl?: unknown; imageUrl?: unknown; thumbnailUrl?: unknown; moderation?: unknown }
      | undefined;
    const after = event.data?.after.data() as
      | { videoUrl?: unknown; imageUrl?: unknown; thumbnailUrl?: unknown; moderation?: unknown }
      | undefined;
    const ref = event.data?.after.ref;
    if (!after || !ref) return;
    const reelId = event.params.reelId as string;
    logger.info(`[moderateReelOnWrite] start reelId=${reelId}`);

    const beforeVideo = typeof before?.videoUrl === 'string' ? before.videoUrl.trim() : '';
    const beforeImage = typeof before?.imageUrl === 'string' ? before.imageUrl.trim() : '';
    const beforeThumb = typeof before?.thumbnailUrl === 'string' ? before.thumbnailUrl.trim() : '';
    const afterVideo = typeof after.videoUrl === 'string' ? after.videoUrl.trim() : '';
    const afterImage = typeof after.imageUrl === 'string' ? after.imageUrl.trim() : '';
    const afterThumb = typeof after.thumbnailUrl === 'string' ? after.thumbnailUrl.trim() : '';

    const afterStatus =
      typeof (after.moderation as { status?: unknown } | undefined)?.status === 'string'
        ? String((after.moderation as { status: string }).status).toLowerCase()
        : '';

    const mediaChanged = beforeVideo !== afterVideo || beforeImage !== afterImage || beforeThumb !== afterThumb;
    const needsModeration = afterStatus === 'pending' || afterStatus === 'review' || afterStatus === '';
    if (!mediaChanged && !needsModeration) {
      logger.info(`[moderateReelOnWrite] skip_no_change reelId=${reelId} afterStatus=${afterStatus}`);
      return;
    }

    if (!HIVE_V3_BEARER && !HIVE_V2_TOKEN) {
      logger.warn(`[moderateReelOnWrite] skipped_missing_key reelId=${reelId}`);
      await ref.set(
        {
          moderation: {
            provider: 'hive',
            status: 'skipped',
            score: 0,
            reasons: ['missing_hive_api_key'],
            checkedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );
      return;
    }

    const mediaUrl = afterImage || afterThumb || (afterVideo ? toHiveImageUrl(afterVideo) : '');
    if (!mediaUrl) {
      logger.warn(`[moderateReelOnWrite] no_media_url reelId=${reelId}`);
      return;
    }

    try {
      const res = await callHiveModeration(mediaUrl);
      logger.info(
        `[moderateReelOnWrite] hive_http_status reelId=${reelId} endpoint=${res.endpoint} status=${res.status} ok=${res.ok}`,
      );
      if (!res.ok) {
        const errSummary = summarizeErrorBody(res.payloadText);
        logger.error(
          `[moderateReelOnWrite] hive_http_error reelId=${reelId} endpoint=${res.endpoint} status=${res.status} body=${errSummary}`,
        );
        await ref.set(
          {
            moderation: {
              provider: 'hive',
              status: 'error',
              score: 0,
              reasons: [`http_${res.status}`, `hive_endpoint:${res.endpoint}`, `hive:${errSummary}`],
              checkedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          { merge: true },
        );
        return;
      }
      let classes: HiveClassScore[] = [];
      if (res.endpoint === 'v3') {
        const payload = JSON.parse(res.payloadText) as HiveV3Payload;
        classes = extractHiveClassScores(payload);
      } else {
        const payload = JSON.parse(res.payloadText) as { output?: Array<{ classes?: HiveClassScore[] }> };
        classes = payload.output?.[0]?.classes ?? [];
      }
      const result = evaluateHive(classes);
      await ref.set(
        {
          moderation: {
            provider: 'hive',
            status: result.status,
            score: result.score,
            reasons: result.reasons,
            mediaUrl,
            checkedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );
      logger.info(
        `[moderateReelOnWrite] final_status reelId=${reelId} status=${result.status} score=${result.score} reasons=${result.reasons.join('|')}`,
      );
    } catch (e) {
      logger.error(`[moderateReelOnWrite] exception reelId=${reelId} error=${String(e)}`);
      await ref.set(
        {
          moderation: {
            provider: 'hive',
            status: 'error',
            score: 0,
            reasons: [String(e)],
            checkedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );
    }
  },
);

// ── Email signup OTP (Resend) — Firestore-triggered (no Cloud Run `allUsers` invoker) ──
// Same pattern as generateAgoraTokenOnRequest: org policy blocks public IAM on HTTP callables.

/**
 * Client creates: email_otp_send_requests/{id}  { userId, status: 'pending', createdAt }
 * Function writes:   { status: 'done' }  or  { status: 'error', error }
 */
export const processEmailOtpSendRequest = onDocumentCreated(
  {
    document: 'email_otp_send_requests/{requestId}',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const markError = async (msg: string) => {
      await snap.ref.update({ status: 'error', error: msg });
    };

    if (!RESEND_API_KEY) {
      await markError('Email delivery is not configured.');
      return;
    }

    const raw = snap.data() as { userId?: unknown; email?: unknown };
    const uid =
      typeof raw.userId === 'string'
        ? raw.userId.trim()
        : typeof raw.userId === 'number'
          ? String(raw.userId)
          : '';
    const requestedEmail =
      typeof raw.email === 'string' ? raw.email.trim().toLowerCase() : '';
    if (!uid) {
      await markError('Invalid request.');
      return;
    }

    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(uid).get();
    const profile = userDoc.data() as
      | { email?: unknown; emailOtpVerified?: unknown }
      | undefined;

    // Resolve email + password provider via Auth; fall back to Firestore profile when
    // getUser fails (e.g. transient API errors). Client rules ensure userId matches signer;
    // emailOtpVerified === false means email/password signup path.
    let email = requestedEmail;
    let isPasswordSignup = false;
    let isAnonymous = false;

    try {
      const userRecord = await getAuth().getUser(uid);
      if (!email) {
        email = (userRecord.email ?? '').trim();
      }
      isPasswordSignup = userRecord.providerData.some((p) => p.providerId === 'password');
      isAnonymous = userRecord.providerData.some((p) => p.providerId === 'anonymous');
    } catch (e: unknown) {
      console.error('processEmailOtpSendRequest getUser failed', uid, e);
      const emailFromDoc =
        typeof profile?.email === 'string' ? profile.email.trim() : '';
      if ((emailFromDoc.includes('@') || email.includes('@')) && userDoc.exists) {
        email = emailFromDoc;
        // Fallback path for transient Auth Admin lookup failures:
        // this request can only be created by the signed-in user for their own uid.
        isPasswordSignup = true;
      } else {
        const code =
          e && typeof e === 'object' && 'code' in e
            ? String((e as { code: unknown }).code)
            : '';
        if (code === 'auth/user-not-found') {
          await markError('Account not found.');
        } else {
          await markError('Could not verify account. Try again in a moment.');
        }
        return;
      }
    }

    if (!email) {
      await markError('No email on this account.');
      return;
    }
    if (!isPasswordSignup && !isAnonymous) {
      await markError('Email verification not required.');
      return;
    }
    if (!email.includes('@')) {
      await markError('Invalid email.');
      return;
    }

    const challengeRef = db.collection('email_otp_challenges').doc(uid);
    const challengeSnap = await challengeRef.get();
    const now = Date.now();
    if (challengeSnap.exists) {
      const last = challengeSnap.data()?.lastSentAt as admin.firestore.Timestamp | undefined;
      if (last && now - last.toMillis() < EMAIL_OTP_RESEND_COOLDOWN_MS) {
        await markError('Please wait a moment before requesting a new code.');
        return;
      }
    }

    const code = String(Math.floor(1000 + Math.random() * 9000));
    const codeHash = hashEmailOtp(uid, code);
    await challengeRef.set({
      codeHash,
      expiresAt: admin.firestore.Timestamp.fromMillis(now + EMAIL_OTP_TTL_MS),
      attempts: 0,
      lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: RESEND_FROM_EMAIL,
        to: [email],
        subject: 'Your Vyooo verification code',
        text: `Your Vyooo verification code is: ${code}. It expires in 10 minutes.`,
        html: `<p>Your verification code is:</p><p style="font-size:24px;font-weight:bold;letter-spacing:6px;">${code}</p><p>This code expires in 10 minutes.</p>`,
      }),
    });

    if (!res.ok) {
      const errBody = await res.text();
      console.error('Resend error', res.status, errBody);
      await challengeRef.delete();
      await markError(parseResendFailureMessage(res.status, errBody));
      return;
    }

    await snap.ref.update({ status: 'done' });
  },
);

/**
 * Client creates: email_otp_verify_requests/{id}  { userId, code, status: 'pending', createdAt }
 * Function writes:   { status: 'done' }  or  { status: 'error', error }
 */
export const processEmailOtpVerifyRequest = onDocumentCreated(
  {
    document: 'email_otp_verify_requests/{requestId}',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const markError = async (msg: string) => {
      await snap.ref.update({ status: 'error', error: msg });
    };

    if (!RESEND_API_KEY) {
      await markError('Email delivery is not configured.');
      return;
    }

    const raw = snap.data() as { userId?: unknown; code?: unknown; email?: unknown };
    const uid = typeof raw.userId === 'string' ? raw.userId : '';
    const code =
      typeof raw.code === 'string' ? raw.code.replace(/\D/g, '').slice(0, 4) : '';
    const requestedEmail =
      typeof raw.email === 'string' ? raw.email.trim().toLowerCase() : '';
    if (!uid || code.length !== 4) {
      await markError('Enter the 4-digit code.');
      return;
    }

    const db = admin.firestore();
    const userRef = db.collection('users').doc(uid);
    const challengeRef = db.collection('email_otp_challenges').doc(uid);
    const challengeSnap = await challengeRef.get();
    if (!challengeSnap.exists) {
      await markError('No active code. Request a new one.');
      return;
    }

    const data = challengeSnap.data()!;
    const expiresAt = data.expiresAt as admin.firestore.Timestamp;
    if (expiresAt.toMillis() < Date.now()) {
      await challengeRef.delete();
      await markError('Code expired. Request a new one.');
      return;
    }

    let attempts = (data.attempts as number) ?? 0;
    if (attempts >= EMAIL_OTP_MAX_ATTEMPTS) {
      await challengeRef.delete();
      await markError('Too many attempts. Request a new code.');
      return;
    }

    const expectedHash = data.codeHash as string;
    if (hashEmailOtp(uid, code) !== expectedHash) {
      attempts += 1;
      await challengeRef.update({ attempts });
      await markError('Invalid code.');
      return;
    }

    let shouldUpdateUserDoc = true;
    try {
      const userRecord = await getAuth().getUser(uid);
      const isAnonymous = userRecord.providerData.some((p) => p.providerId === 'anonymous');
      const normalizedAuthEmail = (userRecord.email ?? '').trim().toLowerCase();
      if (isAnonymous) {
        shouldUpdateUserDoc = false;
      }
      if (requestedEmail.length > 0 && normalizedAuthEmail.length > 0 && requestedEmail != normalizedAuthEmail) {
        shouldUpdateUserDoc = false;
      }
    } catch {
      shouldUpdateUserDoc = false;
    }
    if (shouldUpdateUserDoc) {
      await userRef.set({ emailOtpVerified: true }, { merge: true });
    }
    await challengeRef.delete();
    await snap.ref.update({ status: 'done' });
  },
);

/**
 * Client creates: whatsapp_otp_send_requests/{id}
 * { userId, phoneNumber, status: 'pending', createdAt }
 */
export const processWhatsAppOtpSendRequest = onDocumentCreated(
  {
    document: 'whatsapp_otp_send_requests/{requestId}',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const markError = async (msg: string) => {
      await snap.ref.update({ status: 'error', error: msg });
    };

    const twilioSender = normalizeWhatsAppSender(TWILIO_WHATSAPP_FROM);
    if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !twilioSender) {
      await markError('WhatsApp delivery is not configured.');
      return;
    }

    const raw = snap.data() as { userId?: unknown; phoneNumber?: unknown };
    const uid =
      typeof raw.userId === 'string'
        ? raw.userId.trim()
        : typeof raw.userId === 'number'
          ? String(raw.userId)
          : '';
    const phoneNumber = normalizePhone(raw.phoneNumber);
    if (!uid || !phoneNumber) {
      await markError('Invalid request.');
      return;
    }

    const db = admin.firestore();
    const challengeRef = db.collection('whatsapp_otp_challenges').doc(uid);
    const challengeSnap = await challengeRef.get();
    const now = Date.now();
    if (challengeSnap.exists) {
      const last = challengeSnap.data()?.lastSentAt as admin.firestore.Timestamp | undefined;
      if (last && now - last.toMillis() < WHATSAPP_OTP_RESEND_COOLDOWN_MS) {
        await markError('Please wait a moment before requesting a new code.');
        return;
      }
    }

    const code = String(Math.floor(1000 + Math.random() * 9000));
    const codeHash = hashWhatsAppOtp(uid, phoneNumber, code);
    await challengeRef.set({
      phoneNumber,
      codeHash,
      expiresAt: admin.firestore.Timestamp.fromMillis(now + WHATSAPP_OTP_TTL_MS),
      attempts: 0,
      lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const body = new URLSearchParams({
      To: `whatsapp:${phoneNumber}`,
      From: twilioSender,
      Body: `Your VyooO verification code is ${code}. It expires in 10 minutes.`,
    });
    const twilioRes = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`,
      {
        method: 'POST',
        headers: {
          authorization: `Basic ${Buffer.from(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body,
      },
    );
    if (!twilioRes.ok) {
      const errBody = await twilioRes.text();
      logger.error('Twilio WhatsApp send failed', { status: twilioRes.status, body: errBody.slice(0, 500) });
      await challengeRef.delete();
      await markError(parseTwilioWhatsAppFailureMessage(twilioRes.status, errBody));
      return;
    }

    await snap.ref.update({ status: 'done' });
  },
);

/**
 * Client creates: whatsapp_otp_verify_requests/{id}
 * { userId, phoneNumber, code, status: 'pending', createdAt }
 */
export const processWhatsAppOtpVerifyRequest = onDocumentCreated(
  {
    document: 'whatsapp_otp_verify_requests/{requestId}',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const markError = async (msg: string) => {
      await snap.ref.update({ status: 'error', error: msg });
    };

    const raw = snap.data() as { userId?: unknown; phoneNumber?: unknown; code?: unknown };
    const uid = typeof raw.userId === 'string' ? raw.userId.trim() : '';
    const code = typeof raw.code === 'string' ? raw.code.replace(/\D/g, '').slice(0, 4) : '';
    const phoneNumber = normalizePhone(raw.phoneNumber);
    if (!uid || !phoneNumber || code.length !== 4) {
      await markError('Enter the 4-digit code.');
      return;
    }

    const db = admin.firestore();
    const userRef = db.collection('users').doc(uid);
    const challengeRef = db.collection('whatsapp_otp_challenges').doc(uid);
    const challengeSnap = await challengeRef.get();
    if (!challengeSnap.exists) {
      await markError('No active code. Request a new one.');
      return;
    }

    const data = challengeSnap.data()!;
    const expectedPhone = normalizePhone(data.phoneNumber);
    if (!expectedPhone || expectedPhone !== phoneNumber) {
      await markError('This code does not match the selected phone number.');
      return;
    }
    const expiresAt = data.expiresAt as admin.firestore.Timestamp;
    if (expiresAt.toMillis() < Date.now()) {
      await challengeRef.delete();
      await markError('Code expired. Request a new one.');
      return;
    }

    let attempts = (data.attempts as number) ?? 0;
    if (attempts >= WHATSAPP_OTP_MAX_ATTEMPTS) {
      await challengeRef.delete();
      await markError('Too many attempts. Request a new code.');
      return;
    }

    const expectedHash = data.codeHash as string;
    if (hashWhatsAppOtp(uid, phoneNumber, code) !== expectedHash) {
      attempts += 1;
      await challengeRef.update({ attempts });
      await markError('Invalid code.');
      return;
    }

    await userRef.set({ emailOtpVerified: true }, { merge: true });
    await challengeRef.delete();
    await snap.ref.update({ status: 'done' });
  },
);

// ── sendPushOnNotificationCreate ───────────────────────────────────────────────
export const sendPushOnNotificationCreate = onDocumentCreated(
  {
    document: 'notifications/{notificationId}',
    timeoutSeconds: 20,
    memory: '256MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() as {
      recipientId?: unknown;
      actorUsername?: unknown;
      message?: unknown;
      type?: unknown;
    };
    const recipientId =
      typeof data.recipientId === 'string' ? data.recipientId.trim() : '';
    if (!recipientId) return;

    const actor =
      typeof data.actorUsername === 'string' && data.actorUsername.trim().length > 0
        ? data.actorUsername.trim()
        : 'Someone';
    const body =
      typeof data.message === 'string' && data.message.trim().length > 0
        ? `${actor} ${data.message.trim()}`
        : `${actor} sent you a notification`;
    const type = typeof data.type === 'string' ? data.type.trim() : 'notification';

    const tokenSnap = await admin
      .firestore()
      .collection('users')
      .doc(recipientId)
      .collection('push_tokens')
      .get();
    const tokens = tokenSnap.docs
      .map((d) => {
        const token = d.data().token;
        return typeof token === 'string' ? token.trim() : '';
      })
      .filter((t) => t.length > 0);
    if (tokens.length === 0) {
      await snap.ref.set(
        {
          pushDelivery: {
            status: 'no_tokens',
            tokenCount: 0,
            attemptedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );
      return;
    }

    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: 'Vyooo',
          body,
        },
        data: {
          type,
          recipientId,
          notificationId: snap.id,
        },
      });

      const errorCodes = new Set<string>();
      for (const r of response.responses) {
        const code = r.error?.code?.trim();
        if (code) errorCodes.add(code);
      }

      await snap.ref.set(
        {
          pushDelivery: {
            status: response.failureCount == 0 ? 'sent' : 'partial_failure',
            tokenCount: tokens.length,
            successCount: response.successCount,
            failureCount: response.failureCount,
            errorCodes: Array.from(errorCodes),
            attemptedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );

      if (response.failureCount > 0) {
        logger.warn('sendPushOnNotificationCreate partial failure', {
          notificationId: snap.id,
          successCount: response.successCount,
          failureCount: response.failureCount,
        });
      }
    } catch (e) {
      await snap.ref.set(
        {
          pushDelivery: {
            status: 'error',
            tokenCount: tokens.length,
            attemptedAt: admin.firestore.FieldValue.serverTimestamp(),
            error: String(e),
          },
        },
        { merge: true },
      );
      throw e;
    }
  },
);
