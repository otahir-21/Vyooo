import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import { getAuth } from 'firebase-admin/auth';
import { onDocumentCreated, onDocumentUpdated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
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

    const requestId = event.params.requestId;
    const data = snap.data() as {
      userId?: unknown;
      channelName?: unknown;
      uid?: unknown;
      role?: unknown;
    };

    logger.info(`[AgoraToken] received requestId=${requestId} userId=${data.userId} channelName=${data.channelName} uid=${data.uid} role=${data.role}`);

    // ── Validate ───────────────────────────────────────────────────────────────
    if (
      typeof data.userId !== 'string' ||
      typeof data.channelName !== 'string' ||
      !data.channelName.trim() ||
      typeof data.uid !== 'number' ||
      (data.role !== 'publisher' && data.role !== 'subscriber')
    ) {
      logger.error(`[AgoraToken] invalid fields requestId=${requestId}`);
      await snap.ref.update({ status: 'error', error: 'Invalid request fields.' });
      return;
    }

    if (!APP_CERTIFICATE) {
      logger.error(`[AgoraToken] missing APP_CERTIFICATE requestId=${requestId}`);
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

      logger.info(`[AgoraToken] generating token requestId=${requestId} channel="${channelName}" uid=${uid} role=${data.role} expirySeconds=${TOKEN_TTL_SECONDS}`);

      const token = RtcTokenBuilder.buildTokenWithUid(
        APP_ID,
        APP_CERTIFICATE,
        channelName,
        uid,
        role,
        privilegeExpireTime,
      );

      logger.info(`[AgoraToken] token generated requestId=${requestId} tokenLen=${token.length}`);
      await snap.ref.update({ status: 'done', token, expiresAt: privilegeExpireTime });
    } catch (e) {
      logger.error(`[AgoraToken] generation failed requestId=${requestId} error=${String(e)}`);
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
      if (emailFromDoc.includes('@') || email.includes('@')) {
        email = emailFromDoc;
        if (!email && requestedEmail.includes('@')) {
          email = requestedEmail;
        }
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

// ── Chat: onChatCreate ────────────────────────────────────────────────────────
export const onChatCreate = onDocumentCreated(
  {
    document: 'chats/{chatId}',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const db = admin.firestore();
    const chatId = event.params.chatId;
    const data = snap.data() as Record<string, unknown>;

    const type = typeof data.type === 'string' ? data.type : '';
    const participantIds = Array.isArray(data.participantIds)
      ? data.participantIds.filter((v): v is string => typeof v === 'string' && v.length > 0)
      : [];
    const createdBy = typeof data.createdBy === 'string' ? data.createdBy : '';

    if (!participantIds.includes(createdBy)) {
      logger.error('onChatCreate: createdBy not in participantIds', { chatId, createdBy });
      await snap.ref.update({ _invalid: true, _invalidReason: 'creator_not_participant' });
      return;
    }

    const uniqueIds = [...new Set(participantIds)];

    if (type === 'direct') {
      if (uniqueIds.length !== 2) {
        logger.error('onChatCreate: invalid direct chat', { chatId, type, participantIds });
        await snap.ref.update({ _invalid: true, _invalidReason: 'bad_shape' });
        return;
      }

      const [userASnap, userBSnap] = await Promise.all([
        db.collection('users').doc(uniqueIds[0]).get(),
        db.collection('users').doc(uniqueIds[1]).get(),
      ]);

      const userA = userASnap.data() as Record<string, unknown> | undefined;
      const userB = userBSnap.data() as Record<string, unknown> | undefined;

      const nameOf = (u: Record<string, unknown> | undefined): string => {
        if (!u) return '';
        const dn = typeof u.displayName === 'string' ? u.displayName.trim() : '';
        if (dn) return dn;
        return typeof u.username === 'string' ? u.username.trim() : '';
      };
      const avatarOf = (u: Record<string, unknown> | undefined): string => {
        if (!u) return '';
        return typeof u.profileImage === 'string' ? u.profileImage.trim() : '';
      };

      const baseSummary = {
        type: 'direct',
        participantIds: uniqueIds,
        lastMessage: '',
        lastMessageAt: null,
        lastMessageSenderId: '',
        unreadCount: 0,
        muted: false,
        pinned: false,
        archived: false,
        clearedAt: null,
        requestStatus: 'none',
      };

      const batch = db.batch();

      batch.set(
        db.collection('users').doc(uniqueIds[0]).collection('chatSummaries').doc(chatId),
        { ...baseSummary, chatId, title: nameOf(userB), avatarUrl: avatarOf(userB) },
        { merge: true },
      );

      batch.set(
        db.collection('users').doc(uniqueIds[1]).collection('chatSummaries').doc(chatId),
        { ...baseSummary, chatId, title: nameOf(userA), avatarUrl: avatarOf(userA) },
        { merge: true },
      );

      await batch.commit();
      logger.info('onChatCreate: direct summaries created', { chatId });

    } else if (type === 'group') {
      if (uniqueIds.length < 3 || uniqueIds.length > 256) {
        logger.error('onChatCreate: invalid group size', { chatId, size: uniqueIds.length });
        await snap.ref.update({ _invalid: true, _invalidReason: 'bad_group_size' });
        return;
      }

      const groupName = typeof data.groupName === 'string' ? data.groupName.trim() : 'Group';
      const groupImageUrl = typeof data.groupImageUrl === 'string' ? data.groupImageUrl : '';

      const baseSummary = {
        type: 'group',
        participantIds: uniqueIds,
        lastMessage: '',
        lastMessageAt: null,
        lastMessageSenderId: '',
        unreadCount: 0,
        muted: false,
        pinned: false,
        archived: false,
        clearedAt: null,
        requestStatus: 'none',
        title: groupName,
        avatarUrl: groupImageUrl,
      };

      const batchSize = 500;
      for (let i = 0; i < uniqueIds.length; i += batchSize) {
        const chunk = uniqueIds.slice(i, i + batchSize);
        const batch = db.batch();
        for (const uid of chunk) {
          batch.set(
            db.collection('users').doc(uid).collection('chatSummaries').doc(chatId),
            { ...baseSummary, chatId },
            { merge: true },
          );
        }
        await batch.commit();
      }

      logger.info('onChatCreate: group summaries created', { chatId, members: uniqueIds.length });

    } else {
      logger.error('onChatCreate: unknown chat type', { chatId, type });
      await snap.ref.update({ _invalid: true, _invalidReason: 'unknown_type' });
    }
  },
);

// ── Chat: onChatMessageCreate ─────────────────────────────────────────────────
export const onChatMessageCreate = onDocumentCreated(
  {
    document: 'chats/{chatId}/messages/{messageId}',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const db = admin.firestore();
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const msg = snap.data() as Record<string, unknown>;

    const senderId = typeof msg.senderId === 'string' ? msg.senderId : '';
    const msgType = typeof msg.type === 'string' ? msg.type : '';
    const text = typeof msg.text === 'string' ? msg.text : '';
    const trimmedText = text.trim();
    const mediaUrl = typeof msg.mediaUrl === 'string' ? msg.mediaUrl : '';
    const storagePath = typeof msg.storagePath === 'string' ? msg.storagePath : '';

    const chatSnap = await db.collection('chats').doc(chatId).get();
    if (!chatSnap.exists) {
      logger.error('onChatMessageCreate: parent chat missing', { chatId, messageId });
      await snap.ref.update({ _rejected: true, _rejectedReason: 'no_parent_chat' });
      return;
    }

    const chatData = chatSnap.data() as Record<string, unknown>;
    const chatType = typeof chatData.type === 'string' ? chatData.type : 'direct';
    const participantIds = Array.isArray(chatData.participantIds)
      ? chatData.participantIds.filter((v): v is string => typeof v === 'string' && v.length > 0)
      : [];

    if (!senderId || !participantIds.includes(senderId)) {
      logger.error('onChatMessageCreate: invalid senderId', { chatId, messageId, senderId });
      await snap.ref.update({ _rejected: true, _rejectedReason: 'invalid_sender' });
      return;
    }

    const allowedTypes = ['text', 'image', 'video', 'call', 'audio', 'gif'];
    if (!allowedTypes.includes(msgType)) {
      logger.error('onChatMessageCreate: unsupported type', { chatId, messageId, msgType });
      await snap.ref.update({ _rejected: true, _rejectedReason: 'unsupported_type' });
      return;
    }

    if (msgType === 'text' && !trimmedText) {
      logger.error('onChatMessageCreate: empty text', { chatId, messageId });
      await snap.ref.update({ _rejected: true, _rejectedReason: 'empty_text' });
      return;
    }

    if ((msgType === 'image' || msgType === 'video' || msgType === 'audio') && (!mediaUrl || !storagePath)) {
      logger.error('onChatMessageCreate: missing media fields', { chatId, messageId, msgType });
      await snap.ref.update({ _rejected: true, _rejectedReason: 'missing_media_fields' });
      return;
    }

    const isViewOnce = msg.isViewOnce === true;

    if (isViewOnce && msgType === 'text') {
      logger.error('onChatMessageCreate: view-once text not allowed', { chatId, messageId });
      await snap.ref.update({ _rejected: true, _rejectedReason: 'view_once_text_not_allowed' });
      return;
    }

    if (isViewOnce) {
      const expiresAt = msg.expiresAt;
      if (!expiresAt) {
        const createdAt = msg.createdAt as admin.firestore.Timestamp | undefined;
        const baseMs = createdAt ? createdAt.toMillis() : Date.now();
        const expiry = admin.firestore.Timestamp.fromMillis(baseMs + 14 * 24 * 60 * 60 * 1000);
        await snap.ref.update({ expiresAt: expiry });
      }
    }

    let preview: string;
    if (isViewOnce) {
      preview = msgType === 'video' ? '🔒 View-once video' : '🔒 View-once photo';
    } else if (msgType === 'image') {
      preview = '📷 Photo';
    } else if (msgType === 'video') {
      preview = '🎥 Video';
    } else if (msgType === 'audio') {
      preview = '🎤 Voice message';
    } else {
      preview = trimmedText.length <= 100 ? trimmedText : `${trimmedText.substring(0, 100)}…`;
    }
    const now = admin.firestore.FieldValue.serverTimestamp();

    const batchSize = 500;
    for (let i = 0; i < participantIds.length; i += batchSize) {
      const chunk = participantIds.slice(i, i + batchSize);
      const batch = db.batch();

      if (i === 0) {
        batch.update(db.collection('chats').doc(chatId), {
          lastMessage: preview,
          lastMessageAt: now,
          lastMessageSenderId: senderId,
          lastMessageType: msgType,
          updatedAt: now,
        });
      }

      for (const uid of chunk) {
        if (!uid) continue;
        const isSender = uid === senderId;
        const summaryRef = db.collection('users').doc(uid).collection('chatSummaries').doc(chatId);
        batch.set(
          summaryRef,
          {
            lastMessage: preview,
            lastMessageAt: now,
            lastMessageSenderId: senderId,
            participantIds,
            type: chatType,
            ...(isSender ? { unreadCount: 0 } : { unreadCount: admin.firestore.FieldValue.increment(1) }),
          },
          { merge: true },
        );
      }

      await batch.commit();
    }

    logger.info('onChatMessageCreate: metadata fanout done', { chatId, messageId });

    if (msgType === 'call') return;

    // ── FCM push notifications ────────────────────────────────────────────────
    try {
      const mutedBy = Array.isArray(chatData.mutedBy)
        ? chatData.mutedBy.filter((v): v is string => typeof v === 'string')
        : [];
      const recipientIds = participantIds.filter(
        (uid) => uid !== senderId && !mutedBy.includes(uid),
      );
      if (recipientIds.length === 0) {
        logger.info('onChatMessageCreate: no push recipients', { chatId, messageId });
      } else {
        const tokenSnaps = await Promise.all(
          recipientIds.map((uid) =>
            db.collection('users').doc(uid).collection('push_tokens').get(),
          ),
        );
        const tokens: string[] = [];
        for (const snap of tokenSnaps) {
          for (const doc of snap.docs) {
            const t = doc.data()?.token;
            if (typeof t === 'string' && t.length > 0) tokens.push(t);
          }
        }
        if (tokens.length > 0) {
          const senderMap = chatData.participantMap as Record<string, Record<string, unknown>> | undefined;
          const senderInfo = senderMap?.[senderId];
          const senderDisplayName =
            (typeof senderInfo?.displayName === 'string' && senderInfo.displayName.trim())
              ? senderInfo.displayName.trim()
              : (typeof senderInfo?.username === 'string' && senderInfo.username.trim())
                ? senderInfo.username.trim()
                : 'Someone';
          const groupName = typeof chatData.groupName === 'string' ? chatData.groupName.trim() : '';

          let notifTitle: string;
          if (chatType === 'group' && groupName) {
            notifTitle = groupName;
          } else {
            notifTitle = senderDisplayName;
          }

          let notifBody: string;
          if (msgType === 'image') {
            notifBody = chatType === 'group' ? `${senderDisplayName}: Sent a photo` : 'Sent a photo';
          } else if (msgType === 'video') {
            notifBody = chatType === 'group' ? `${senderDisplayName}: Sent a video` : 'Sent a video';
          } else if (msgType === 'audio') {
            notifBody = chatType === 'group' ? `${senderDisplayName}: Sent a voice message` : 'Sent a voice message';
          } else {
            const bodyPreview = trimmedText.length <= 200 ? trimmedText : `${trimmedText.substring(0, 200)}…`;
            notifBody = chatType === 'group' ? `${senderDisplayName}: ${bodyPreview}` : bodyPreview;
          }

          const FCM_BATCH = 500;
          for (let t = 0; t < tokens.length; t += FCM_BATCH) {
            const batch = tokens.slice(t, t + FCM_BATCH);
            const response = await admin.messaging().sendEachForMulticast({
              tokens: batch,
              notification: { title: notifTitle, body: notifBody },
              data: {
                type: 'chat_message',
                chatId,
                senderId,
                messageId,
                chatType,
              },
              android: { priority: 'high' },
              apns: { payload: { aps: { sound: 'default', badge: 1 } } },
            });
            if (response.failureCount > 0) {
              response.responses.forEach((r, idx) => {
                if (!r.success) {
                  logger.warn('onChatMessageCreate: FCM send failed', {
                    token: batch[idx]?.substring(0, 10),
                    error: r.error?.message,
                  });
                }
              });
            }
          }
          logger.info('onChatMessageCreate: push sent', { chatId, messageId, tokenCount: tokens.length });
        }
      }
    } catch (pushErr) {
      logger.error('onChatMessageCreate: push notification failed (non-fatal)', { chatId, messageId, error: String(pushErr) });
    }
  },
);

// ── Chat: onChatUpdate (sync group metadata to summaries) ─────────────────────
export const onChatUpdate = onDocumentWritten(
  {
    document: 'chats/{chatId}',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (event) => {
    const before = event.data?.before?.data() as Record<string, unknown> | undefined;
    const after = event.data?.after?.data() as Record<string, unknown> | undefined;

    if (!before || !after) return;

    const chatId = event.params.chatId;
    const chatType = typeof after.type === 'string' ? after.type : '';
    if (chatType !== 'group') return;

    const oldName = typeof before.groupName === 'string' ? before.groupName : '';
    const newName = typeof after.groupName === 'string' ? after.groupName : '';
    const oldImage = typeof before.groupImageUrl === 'string' ? before.groupImageUrl : '';
    const newImage = typeof after.groupImageUrl === 'string' ? after.groupImageUrl : '';
    const oldParticipants = Array.isArray(before.participantIds) ? before.participantIds : [];
    const newParticipants = Array.isArray(after.participantIds)
      ? after.participantIds.filter((v): v is string => typeof v === 'string')
      : [];

    if (oldName === newName && oldImage === newImage && JSON.stringify(oldParticipants) === JSON.stringify(newParticipants)) {
      return;
    }

    const db = admin.firestore();
    const updates: Record<string, unknown> = {};
    if (oldName !== newName) updates.title = newName;
    if (oldImage !== newImage) updates.avatarUrl = newImage;
    if (JSON.stringify(oldParticipants) !== JSON.stringify(newParticipants)) {
      updates.participantIds = newParticipants;
    }

    if (Object.keys(updates).length === 0) return;

    const batchSize = 500;
    for (let i = 0; i < newParticipants.length; i += batchSize) {
      const chunk = newParticipants.slice(i, i + batchSize);
      const batch = db.batch();
      for (const uid of chunk) {
        if (typeof uid !== 'string' || !uid) continue;
        batch.set(
          db.collection('users').doc(uid).collection('chatSummaries').doc(chatId),
          updates,
          { merge: true },
        );
      }
      await batch.commit();
    }

    logger.info('onChatUpdate: synced group metadata', { chatId, fields: Object.keys(updates) });
  },
);

// ── Chat: onViewOnceMessageUpdate ─────────────────────────────────────────────
export const onViewOnceMessageUpdate = onDocumentUpdated(
  {
    document: 'chats/{chatId}/messages/{messageId}',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (event) => {
    const before = event.data?.before?.data() as Record<string, unknown> | undefined;
    const after = event.data?.after?.data() as Record<string, unknown> | undefined;
    if (!before || !after) return;

    if (after.isViewOnce !== true) return;

    const beforeViewedBy = Array.isArray(before.viewedBy) ? before.viewedBy : [];
    const afterViewedBy = Array.isArray(after.viewedBy) ? after.viewedBy : [];

    if (afterViewedBy.length <= beforeViewedBy.length) return;

    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const senderId = typeof after.senderId === 'string' ? after.senderId : '';
    const storagePath = typeof after.storagePath === 'string' ? after.storagePath : '';

    const db = admin.firestore();
    const chatSnap = await db.collection('chats').doc(chatId).get();
    if (!chatSnap.exists) return;

    const chatData = chatSnap.data() as Record<string, unknown>;
    const participantIds = Array.isArray(chatData.participantIds)
      ? chatData.participantIds.filter((v): v is string => typeof v === 'string' && v.length > 0)
      : [];

    const eligibleRecipients = participantIds.filter((uid) => uid !== senderId);
    const allViewed = eligibleRecipients.length > 0 &&
      eligibleRecipients.every((uid) => afterViewedBy.includes(uid));

    if (!allViewed) {
      logger.info('onViewOnceMessageUpdate: not all recipients viewed yet', {
        chatId, messageId, viewed: afterViewedBy.length, eligible: eligibleRecipients.length,
      });
      return;
    }

    logger.info('onViewOnceMessageUpdate: all recipients viewed, cleaning up', { chatId, messageId });

    if (storagePath) {
      try {
        await admin.storage().bucket().file(storagePath).delete();
        logger.info('onViewOnceMessageUpdate: deleted storage file', { storagePath });
      } catch (err) {
        logger.warn('onViewOnceMessageUpdate: storage delete failed (non-fatal)', { storagePath, error: String(err) });
      }
    }

    try {
      await event.data!.after.ref.update({
        mediaUrl: '',
        thumbnailUrl: '',
        storagePath: '',
        'metadata.cleanedUpAt': admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      logger.error('onViewOnceMessageUpdate: doc cleanup update failed', { chatId, messageId, error: String(err) });
    }
  },
);

// ── Chat: cleanupExpiredViewOnceMessages (scheduled) ──────────────────────────
export const cleanupExpiredViewOnceMessages = onSchedule(
  {
    schedule: 'every 6 hours',
    timeoutSeconds: 120,
    memory: '256MiB',
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const batchLimit = 200;

    const expiredSnap = await db.collectionGroup('messages')
      .where('isViewOnce', '==', true)
      .where('expiresAt', '<=', now)
      .where('storagePath', '!=', '')
      .limit(batchLimit)
      .get();

    if (expiredSnap.empty) {
      logger.info('cleanupExpiredViewOnceMessages: no expired view-once messages');
      return;
    }

    logger.info('cleanupExpiredViewOnceMessages: found expired messages', { count: expiredSnap.size });

    for (const doc of expiredSnap.docs) {
      const data = doc.data();
      const storagePath = typeof data.storagePath === 'string' ? data.storagePath : '';

      if (storagePath) {
        try {
          await admin.storage().bucket().file(storagePath).delete();
        } catch (err) {
          logger.warn('cleanupExpiredViewOnceMessages: storage delete failed', { docPath: doc.ref.path, error: String(err) });
        }
      }

      try {
        await doc.ref.update({
          mediaUrl: '',
          thumbnailUrl: '',
          storagePath: '',
          'metadata.cleanedUpAt': admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (err) {
        logger.error('cleanupExpiredViewOnceMessages: doc update failed', { docPath: doc.ref.path, error: String(err) });
      }
    }

    logger.info('cleanupExpiredViewOnceMessages: cleanup done', { processed: expiredSnap.size });
  },
);

// ── Calls: onCallSessionCreate ────────────────────────────────────────────────
export const onCallSessionCreate = onDocumentCreated(
  {
    document: 'callSessions/{callId}',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const db = admin.firestore();
    const callId = event.params.callId;
    const data = snap.data() as Record<string, unknown>;

    const callerId = typeof data.callerId === 'string' ? data.callerId : '';
    const callType = typeof data.type === 'string' ? data.type : 'audio';
    const chatId = typeof data.chatId === 'string' ? data.chatId : '';
    const agoraChannelName = typeof data.agoraChannelName === 'string' ? data.agoraChannelName : '';
    const calleeIds = Array.isArray(data.calleeIds)
      ? data.calleeIds.filter((v): v is string => typeof v === 'string' && v.length > 0)
      : [];

    if (!callerId || calleeIds.length === 0 || !chatId) {
      logger.error('onCallSessionCreate: invalid call data', { callId });
      return;
    }

    let callerDisplayName = 'Someone';
    try {
      const chatSnap = await db.collection('chats').doc(chatId).get();
      if (chatSnap.exists) {
        const chatData = chatSnap.data() as Record<string, unknown>;
        const pMap = chatData.participantMap as Record<string, Record<string, unknown>> | undefined;
        const callerInfo = pMap?.[callerId];
        if (callerInfo) {
          const dn = typeof callerInfo.displayName === 'string' ? callerInfo.displayName.trim() : '';
          const un = typeof callerInfo.username === 'string' ? callerInfo.username.trim() : '';
          callerDisplayName = dn || un || callerDisplayName;
        }
      }
    } catch (err) {
      logger.warn('onCallSessionCreate: could not fetch caller name', { error: String(err) });
    }

    const tokenSnaps = await Promise.all(
      calleeIds.map((uid) =>
        db.collection('users').doc(uid).collection('push_tokens').get(),
      ),
    );
    const tokens: string[] = [];
    for (const tSnap of tokenSnaps) {
      for (const doc of tSnap.docs) {
        const t = doc.data()?.token;
        if (typeof t === 'string' && t.length > 0) tokens.push(t);
      }
    }

    if (tokens.length === 0) {
      logger.info('onCallSessionCreate: no push tokens for callees', { callId });
      return;
    }

    const notifTitle = callerDisplayName;
    const notifBody = callType === 'video' ? 'Incoming video call' : 'Incoming audio call';

    const FCM_BATCH = 500;
    for (let t = 0; t < tokens.length; t += FCM_BATCH) {
      const batch = tokens.slice(t, t + FCM_BATCH);
      try {
        const response = await admin.messaging().sendEachForMulticast({
          tokens: batch,
          notification: { title: notifTitle, body: notifBody },
          data: {
            type: 'incoming_call',
            callId,
            chatId,
            callerId,
            callType,
            agoraChannelName,
          },
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default', badge: 1, 'content-available': 1 } } },
        });
        if (response.failureCount > 0) {
          logger.warn('onCallSessionCreate: FCM partial failure', {
            callId,
            failureCount: response.failureCount,
          });
        }
      } catch (err) {
        logger.error('onCallSessionCreate: FCM send error', { callId, error: String(err) });
      }
    }

    logger.info('onCallSessionCreate: push sent', { callId, tokenCount: tokens.length });
  },
);

// ── Calls: onCallSessionUpdate ────────────────────────────────────────────────
export const onCallSessionUpdate = onDocumentUpdated(
  {
    document: 'callSessions/{callId}',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (event) => {
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;
    if (!beforeSnap || !afterSnap) return;

    const db = admin.firestore();
    const callId = event.params.callId;
    const before = beforeSnap.data() as Record<string, unknown>;
    const after = afterSnap.data() as Record<string, unknown>;

    const oldStatus = typeof before.status === 'string' ? before.status : '';
    const newStatus = typeof after.status === 'string' ? after.status : '';

    if (oldStatus === newStatus) return;

    const terminalStatuses = ['ended', 'missed', 'declined', 'failed'];
    if (!terminalStatuses.includes(newStatus)) return;

    const chatId = typeof after.chatId === 'string' ? after.chatId : '';
    const callerId = typeof after.callerId === 'string' ? after.callerId : '';
    const callType = typeof after.type === 'string' ? after.type : 'audio';
    const durationSeconds = typeof after.durationSeconds === 'number' ? after.durationSeconds : 0;
    const participantIds = Array.isArray(after.participantIds)
      ? after.participantIds.filter((v): v is string => typeof v === 'string')
      : [];

    if (!chatId || !callerId) {
      logger.error('onCallSessionUpdate: missing chatId or callerId', { callId });
      return;
    }

    const existingMsg = await db.collection('chats').doc(chatId).collection('messages')
      .where('type', '==', 'call')
      .where('metadata.callId', '==', callId)
      .limit(1)
      .get();

    if (!existingMsg.empty) {
      const msgDoc = existingMsg.docs[0];
      await msgDoc.ref.update({
        'metadata.callStatus': newStatus,
        'metadata.durationSeconds': durationSeconds,
        text: _callPreviewText(callType, newStatus, durationSeconds),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      logger.info('onCallSessionUpdate: updated existing call message', { callId, newStatus });
      return;
    }

    let preview = _callPreviewText(callType, newStatus, durationSeconds);

    const msgRef = db.collection('chats').doc(chatId).collection('messages').doc();
    await msgRef.set({
      senderId: callerId,
      type: 'call',
      text: preview,
      metadata: {
        callId,
        callType,
        callStatus: newStatus,
        durationSeconds,
      },
      participantIds,
      isViewOnce: false,
      mediaUrl: '',
      storagePath: '',
      thumbnailUrl: '',
      seenBy: [],
      deletedForEveryone: false,
      deletedFor: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('onCallSessionUpdate: call system message created', { callId, chatId, newStatus });
  },
);

function _callPreviewText(callType: string, status: string, durationSeconds: number): string {
  const typeLabel = callType === 'video' ? 'Video call' : 'Audio call';
  if (status === 'ended' && durationSeconds > 0) {
    const m = Math.floor(durationSeconds / 60).toString().padStart(2, '0');
    const s = (durationSeconds % 60).toString().padStart(2, '0');
    return `${typeLabel} (${m}:${s})`;
  }
  if (status === 'missed') return `Missed ${typeLabel.toLowerCase()}`;
  if (status === 'declined') return `Declined ${typeLabel.toLowerCase()}`;
  if (status === 'failed') return 'Call failed';
  return typeLabel;
}

// ── Calls: cleanupStaleRingingCalls (scheduled) ───────────────────────────────
export const cleanupStaleRingingCalls = onSchedule(
  {
    schedule: 'every 1 minutes',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async () => {
    const db = admin.firestore();
    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 45 * 1000);
    const staleSnap = await db.collection('callSessions')
      .where('status', '==', 'ringing')
      .where('createdAt', '<=', cutoff)
      .limit(50)
      .get();

    if (staleSnap.empty) return;

    logger.info('cleanupStaleRingingCalls: found stale calls', { count: staleSnap.size });

    for (const doc of staleSnap.docs) {
      try {
        await doc.ref.update({
          status: 'missed',
          endedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (err) {
        logger.error('cleanupStaleRingingCalls: update failed', { callId: doc.id, error: String(err) });
      }
    }

    logger.info('cleanupStaleRingingCalls: done', { processed: staleSnap.size });
  },
);
