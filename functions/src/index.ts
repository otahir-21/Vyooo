import * as admin from 'firebase-admin';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
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
const HIVE_API_KEY = process.env.HIVE_API_KEY ?? '';
const HIVE_SYNC_URL = 'https://api.thehive.ai/api/v2/task/sync';
const HIVE_BLOCK_THRESHOLD = 0.95;
const HIVE_REVIEW_THRESHOLD = 0.90;

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

export const moderateReelOnCreate = onDocumentCreated(
  {
    document: 'reels/{reelId}',
    timeoutSeconds: 25,
    memory: '256MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() as { videoUrl?: unknown };
    if (!HIVE_API_KEY) {
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
    if (!videoUrl) return;
    const mediaUrl = toHiveImageUrl(videoUrl);

    try {
      const form = new FormData();
      form.append('url', mediaUrl);
      const res = await fetch(HIVE_SYNC_URL, {
        method: 'POST',
        headers: {
          authorization: `Token ${HIVE_API_KEY}`,
          accept: 'application/json',
        },
        body: form,
      });
      if (!res.ok) {
        await snap.ref.set(
          {
            moderation: {
              provider: 'hive',
              status: 'error',
              score: 0,
              reasons: [`http_${res.status}`],
              checkedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          { merge: true },
        );
        return;
      }
      const payload = (await res.json()) as { output?: Array<{ classes?: HiveClassScore[] }> };
      const classes = payload.output?.[0]?.classes ?? [];
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
    } catch (e) {
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
