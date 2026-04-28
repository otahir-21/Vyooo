"use strict";
var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l;
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendPushOnNotificationCreate = exports.processWhatsAppOtpVerifyRequest = exports.processWhatsAppOtpSendRequest = exports.processEmailOtpVerifyRequest = exports.processEmailOtpSendRequest = exports.moderateReelOnWrite = exports.moderateReelOnCreate = exports.syncFollowersCountOnFollowingChange = exports.getCloudflareUploadUrl = exports.generateAgoraTokenOnRequest = void 0;
const crypto = require("crypto");
const admin = require("firebase-admin");
const auth_1 = require("firebase-admin/auth");
const firestore_1 = require("firebase-functions/v2/firestore");
const firebase_functions_1 = require("firebase-functions");
const agora_access_token_1 = require("agora-access-token");
admin.initializeApp();
// ── Constants ──────────────────────────────────────────────────────────────────
const APP_ID = '443105d5684f492088bb004196b3fee8';
const TOKEN_TTL_SECONDS = 3600; // 1 hour
// App Certificate is injected at deploy time via .env.vyooov1
const APP_CERTIFICATE = (_a = process.env.AGORA_APP_CERTIFICATE) !== null && _a !== void 0 ? _a : '';
// Cloudflare Stream credentials — set in .env.vyooov1
const CF_ACCOUNT_ID = (_b = process.env.CLOUDFLARE_ACCOUNT_ID) !== null && _b !== void 0 ? _b : '';
const CF_API_TOKEN = (_c = process.env.CLOUDFLARE_API_TOKEN) !== null && _c !== void 0 ? _c : '';
const HIVE_API_KEY = ((_d = process.env.HIVE_API_KEY) !== null && _d !== void 0 ? _d : '').trim();
const HIVE_ACCESS_KEY = ((_e = process.env.HIVE_ACCESS_KEY) !== null && _e !== void 0 ? _e : '').trim();
const HIVE_SECRET_KEY = ((_f = process.env.HIVE_SECRET_KEY) !== null && _f !== void 0 ? _f : '').trim();
const HIVE_V3_BEARER = HIVE_SECRET_KEY || HIVE_API_KEY;
const HIVE_V2_TOKEN = HIVE_ACCESS_KEY || HIVE_API_KEY;
const HIVE_MODERATION_URL = 'https://api.thehive.ai/api/v3/hive/visual-moderation';
const HIVE_V2_SYNC_URL = 'https://api.thehive.ai/api/v2/task/sync';
const HIVE_BLOCK_THRESHOLD = 0.95;
const HIVE_REVIEW_THRESHOLD = 0.90;
// Resend (email OTP). Set RESEND_API_KEY in environment (e.g. functions/.env.vyooov1 — gitignored).
// Set RESEND_FROM_EMAIL to an address on your verified domain (e.g. noreply@vyooo.com). If you omit it,
// the default onboarding@resend.dev sender applies — Resend then only allows "test" recipients (account email).
const RESEND_API_KEY = ((_g = process.env.RESEND_API_KEY) !== null && _g !== void 0 ? _g : '').trim();
const RESEND_FROM_EMAIL = ((_h = process.env.RESEND_FROM_EMAIL) !== null && _h !== void 0 ? _h : 'Vyooo <onboarding@resend.dev>').trim();
function parseResendFailureMessage(status, body) {
    try {
        const j = JSON.parse(body);
        const m = typeof j.message === 'string' ? j.message.trim() : '';
        if (m.length > 0) {
            return m.length <= 400 ? m : `${m.slice(0, 397)}…`;
        }
    }
    catch (_a) {
        /* not JSON */
    }
    if (status === 401 || status === 403) {
        return 'Email service rejected the request. Check RESEND_API_KEY.';
    }
    if (status === 422) {
        return ('Invalid email request. Verify a domain at resend.com/domains and set RESEND_FROM_EMAIL to an address ' +
            'on that domain (required to deliver OTP to any inbox).');
    }
    return `Could not send email (HTTP ${status}).`;
}
const EMAIL_OTP_TTL_MS = 10 * 60 * 1000;
const EMAIL_OTP_MAX_ATTEMPTS = 8;
const EMAIL_OTP_RESEND_COOLDOWN_MS = 60 * 1000;
const WHATSAPP_OTP_TTL_MS = 10 * 60 * 1000;
const WHATSAPP_OTP_MAX_ATTEMPTS = 8;
const WHATSAPP_OTP_RESEND_COOLDOWN_MS = 60 * 1000;
const TWILIO_ACCOUNT_SID = ((_j = process.env.TWILIO_ACCOUNT_SID) !== null && _j !== void 0 ? _j : '').trim();
const TWILIO_AUTH_TOKEN = ((_k = process.env.TWILIO_AUTH_TOKEN) !== null && _k !== void 0 ? _k : '').trim();
const TWILIO_WHATSAPP_FROM = ((_l = process.env.TWILIO_WHATSAPP_FROM) !== null && _l !== void 0 ? _l : '').trim();
function normalizeWhatsAppSender(raw) {
    const trimmed = raw.trim();
    if (!trimmed)
        return '';
    return trimmed.toLowerCase().startsWith('whatsapp:')
        ? trimmed
        : `whatsapp:${trimmed}`;
}
function parseTwilioWhatsAppFailureMessage(status, body) {
    try {
        const parsed = JSON.parse(body);
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
    }
    catch (_a) {
        // Non-JSON body.
    }
    if (status === 401 || status === 403) {
        return 'Twilio credentials are invalid. Check TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN.';
    }
    return `Could not send WhatsApp code (HTTP ${status}).`;
}
function hashEmailOtp(uid, plain) {
    return crypto
        .createHash('sha256')
        .update(`vyooo-otp-v1:${RESEND_API_KEY}:${uid}:${plain}`, 'utf8')
        .digest('hex');
}
function hashWhatsAppOtp(uid, phone, plain) {
    return crypto
        .createHash('sha256')
        .update(`vyooo-wa-otp-v1:${TWILIO_ACCOUNT_SID}:${uid}:${phone}:${plain}`, 'utf8')
        .digest('hex');
}
function normalizePhone(raw) {
    const asString = typeof raw === 'string' ? raw.trim() : '';
    if (!asString)
        return '';
    const normalized = asString.replace(/[^\d+]/g, '');
    if (!normalized.startsWith('+'))
        return '';
    if (!/^\+\d{8,16}$/.test(normalized))
        return '';
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
exports.generateAgoraTokenOnRequest = (0, firestore_1.onDocumentCreated)({
    document: 'token_requests/{requestId}',
    timeoutSeconds: 10,
    memory: '128MiB',
}, async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const data = snap.data();
    // ── Validate ───────────────────────────────────────────────────────────────
    if (typeof data.userId !== 'string' ||
        typeof data.channelName !== 'string' ||
        !data.channelName.trim() ||
        typeof data.uid !== 'number' ||
        (data.role !== 'publisher' && data.role !== 'subscriber')) {
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
        const uid = data.uid;
        const role = data.role === 'publisher' ? agora_access_token_1.RtcRole.PUBLISHER : agora_access_token_1.RtcRole.SUBSCRIBER;
        const nowSeconds = Math.floor(Date.now() / 1000);
        const privilegeExpireTime = nowSeconds + TOKEN_TTL_SECONDS;
        const token = agora_access_token_1.RtcTokenBuilder.buildTokenWithUid(APP_ID, APP_CERTIFICATE, channelName, uid, role, privilegeExpireTime);
        await snap.ref.update({ status: 'done', token, expiresAt: privilegeExpireTime });
    }
    catch (e) {
        await snap.ref.update({ status: 'error', error: String(e) });
    }
});
// ── getCloudflareUploadUrl ─────────────────────────────────────────────────────
/**
 * Firestore-triggered function — same pattern as generateAgoraTokenOnRequest
 * to avoid the org-policy IAM allUsers restriction.
 *
 * Flutter creates:  cloudflare_upload_requests/{requestId}  { userId }
 * Function writes back: { status: 'done', videoId, uploadUrl }
 *                    or { status: 'error', error }
 */
exports.getCloudflareUploadUrl = (0, firestore_1.onDocumentCreated)({
    document: 'cloudflare_upload_requests/{requestId}',
    timeoutSeconds: 30,
    memory: '128MiB',
}, async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const data = snap.data();
    if (typeof data.userId !== 'string' || !data.userId) {
        await snap.ref.update({ status: 'error', error: 'Missing userId.' });
        return;
    }
    if (!CF_ACCOUNT_ID || !CF_API_TOKEN) {
        await snap.ref.update({ status: 'error', error: 'Cloudflare credentials not configured.' });
        return;
    }
    try {
        const response = await fetch(`https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/stream/direct_upload`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${CF_API_TOKEN}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ maxDurationSeconds: 600, requireSignedURLs: false }),
        });
        if (!response.ok) {
            await snap.ref.update({ status: 'error', error: `Cloudflare API error: ${response.status}` });
            return;
        }
        const result = await response.json();
        if (!result.success) {
            await snap.ref.update({ status: 'error', error: 'Cloudflare returned failure.' });
            return;
        }
        await snap.ref.update({
            status: 'done',
            videoId: result.result.uid,
            uploadUrl: result.result.uploadURL,
        });
    }
    catch (e) {
        await snap.ref.update({ status: 'error', error: String(e) });
    }
});
// ── syncFollowersCountOnFollowingChange ───────────────────────────────────────
/**
 * Keeps users/{uid}.followersCount in sync based on changes to users/{uid}.following.
 *
 * We diff `following` before/after and increment/decrement each affected target
 * user's followersCount atomically. This avoids expensive count queries in app UI.
 */
exports.syncFollowersCountOnFollowingChange = (0, firestore_1.onDocumentWritten)({
    document: 'users/{userId}',
    timeoutSeconds: 20,
    memory: '256MiB',
}, async (event) => {
    var _a, _b;
    const beforeData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const afterData = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    const before = Array.isArray(beforeData === null || beforeData === void 0 ? void 0 : beforeData.following)
        ? beforeData.following.map((v) => String(v))
        : [];
    const after = Array.isArray(afterData === null || afterData === void 0 ? void 0 : afterData.following)
        ? afterData.following.map((v) => String(v))
        : [];
    const beforeSet = new Set(before);
    const afterSet = new Set(after);
    const added = [];
    const removed = [];
    for (const id of afterSet) {
        if (!beforeSet.has(id))
            added.push(id);
    }
    for (const id of beforeSet) {
        if (!afterSet.has(id))
            removed.push(id);
    }
    if (!added.length && !removed.length)
        return;
    const db = admin.firestore();
    const writes = [];
    for (const targetUid of added) {
        if (!targetUid)
            continue;
        writes.push(db.collection('users').doc(targetUid).set({ followersCount: admin.firestore.FieldValue.increment(1) }, { merge: true }));
    }
    for (const targetUid of removed) {
        if (!targetUid)
            continue;
        writes.push(db.collection('users').doc(targetUid).set({ followersCount: admin.firestore.FieldValue.increment(-1) }, { merge: true }));
    }
    await Promise.all(writes);
});
function toHiveImageUrl(videoUrl) {
    // Cloudflare Stream HLS URL:
    // https://<subdomain>/<videoId>/manifest/video.m3u8
    // Convert to thumbnail image supported by Hive image moderation:
    // https://<subdomain>/<videoId>/thumbnails/thumbnail.jpg
    const m = videoUrl.match(/^(https?:\/\/[^/]+)\/([^/]+)\/manifest\/video\.m3u8$/i);
    if (!m)
        return videoUrl;
    return `${m[1]}/${m[2]}/thumbnails/thumbnail.jpg`;
}
function evaluateHive(classes) {
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
    const reasons = [];
    for (const c of classes) {
        if (!denySignals.some((s) => c.class === s))
            continue;
        if (c.score > max)
            max = c.score;
        if (c.score >= HIVE_REVIEW_THRESHOLD)
            reasons.push(c.class);
    }
    if (max >= HIVE_BLOCK_THRESHOLD) {
        return { status: 'blocked', score: max, reasons };
    }
    if (max >= HIVE_REVIEW_THRESHOLD) {
        return { status: 'review', score: max, reasons };
    }
    return { status: 'clear', score: max, reasons };
}
function extractHiveClassScores(payload) {
    var _a;
    const output = Array.isArray(payload.output) ? payload.output : [];
    const maxScores = new Map();
    for (const item of output) {
        const maybeItem = item;
        const classes = Array.isArray(maybeItem.classes) ? maybeItem.classes : [];
        for (const c of classes) {
            const entry = c;
            const className = typeof entry.class_name === 'string' ? entry.class_name.trim() : '';
            const value = typeof entry.value === 'number' ? entry.value : NaN;
            if (!className || !Number.isFinite(value))
                continue;
            const prev = (_a = maxScores.get(className)) !== null && _a !== void 0 ? _a : 0;
            if (value > prev)
                maxScores.set(className, value);
        }
    }
    return Array.from(maxScores.entries()).map(([className, score]) => ({
        class: className,
        score,
    }));
}
function summarizeErrorBody(body) {
    const trimmed = body.trim();
    if (!trimmed)
        return 'empty_response';
    const compact = trimmed.replace(/\s+/g, ' ');
    return compact.length <= 180 ? compact : `${compact.slice(0, 177)}...`;
}
async function callHiveModeration(mediaUrl) {
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
exports.moderateReelOnCreate = (0, firestore_1.onDocumentCreated)({
    document: 'reels/{reelId}',
    timeoutSeconds: 25,
    memory: '256MiB',
}, async (event) => {
    var _a, _b, _c;
    const snap = event.data;
    if (!snap)
        return;
    const reelId = event.params.reelId;
    const data = snap.data();
    firebase_functions_1.logger.info(`[moderateReelOnCreate] start reelId=${reelId}`);
    if (!HIVE_V3_BEARER && !HIVE_V2_TOKEN) {
        firebase_functions_1.logger.warn(`[moderateReelOnCreate] skipped_missing_key reelId=${reelId}`);
        await snap.ref.set({
            moderation: {
                provider: 'hive',
                status: 'skipped',
                score: 0,
                reasons: ['missing_hive_api_key'],
                checkedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        }, { merge: true });
        return;
    }
    const videoUrl = typeof data.videoUrl === 'string' ? data.videoUrl.trim() : '';
    const imageUrl = typeof data.imageUrl === 'string' ? data.imageUrl.trim() : '';
    const thumbnailUrl = typeof data.thumbnailUrl === 'string' ? data.thumbnailUrl.trim() : '';
    const mediaUrl = imageUrl || thumbnailUrl || (videoUrl ? toHiveImageUrl(videoUrl) : '');
    if (!mediaUrl) {
        firebase_functions_1.logger.warn(`[moderateReelOnCreate] no_media_url reelId=${reelId}`);
        return;
    }
    try {
        const res = await callHiveModeration(mediaUrl);
        firebase_functions_1.logger.info(`[moderateReelOnCreate] hive_http_status reelId=${reelId} endpoint=${res.endpoint} status=${res.status} ok=${res.ok}`);
        if (!res.ok) {
            const errSummary = summarizeErrorBody(res.payloadText);
            firebase_functions_1.logger.error(`[moderateReelOnCreate] hive_http_error reelId=${reelId} endpoint=${res.endpoint} status=${res.status} body=${errSummary}`);
            await snap.ref.set({
                moderation: {
                    provider: 'hive',
                    status: 'error',
                    score: 0,
                    reasons: [`http_${res.status}`, `hive_endpoint:${res.endpoint}`, `hive:${errSummary}`],
                    checkedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
            }, { merge: true });
            return;
        }
        let classes = [];
        if (res.endpoint === 'v3') {
            const payload = JSON.parse(res.payloadText);
            classes = extractHiveClassScores(payload);
        }
        else {
            const payload = JSON.parse(res.payloadText);
            classes = (_c = (_b = (_a = payload.output) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.classes) !== null && _c !== void 0 ? _c : [];
        }
        const result = evaluateHive(classes);
        await snap.ref.set({
            moderation: {
                provider: 'hive',
                status: result.status,
                score: result.score,
                reasons: result.reasons,
                mediaUrl,
                checkedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        }, { merge: true });
        firebase_functions_1.logger.info(`[moderateReelOnCreate] final_status reelId=${reelId} status=${result.status} score=${result.score} reasons=${result.reasons.join('|')}`);
    }
    catch (e) {
        firebase_functions_1.logger.error(`[moderateReelOnCreate] exception reelId=${reelId} error=${String(e)}`);
        await snap.ref.set({
            moderation: {
                provider: 'hive',
                status: 'error',
                score: 0,
                reasons: [String(e)],
                checkedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        }, { merge: true });
    }
});
// Re-run moderation when media URL changes or moderation is reset to pending.
exports.moderateReelOnWrite = (0, firestore_1.onDocumentWritten)({
    document: 'reels/{reelId}',
    timeoutSeconds: 25,
    memory: '256MiB',
}, async (event) => {
    var _a, _b, _c, _d, _e, _f, _g;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    const ref = (_c = event.data) === null || _c === void 0 ? void 0 : _c.after.ref;
    if (!after || !ref)
        return;
    const reelId = event.params.reelId;
    firebase_functions_1.logger.info(`[moderateReelOnWrite] start reelId=${reelId}`);
    const beforeVideo = typeof (before === null || before === void 0 ? void 0 : before.videoUrl) === 'string' ? before.videoUrl.trim() : '';
    const beforeImage = typeof (before === null || before === void 0 ? void 0 : before.imageUrl) === 'string' ? before.imageUrl.trim() : '';
    const beforeThumb = typeof (before === null || before === void 0 ? void 0 : before.thumbnailUrl) === 'string' ? before.thumbnailUrl.trim() : '';
    const afterVideo = typeof after.videoUrl === 'string' ? after.videoUrl.trim() : '';
    const afterImage = typeof after.imageUrl === 'string' ? after.imageUrl.trim() : '';
    const afterThumb = typeof after.thumbnailUrl === 'string' ? after.thumbnailUrl.trim() : '';
    const afterStatus = typeof ((_d = after.moderation) === null || _d === void 0 ? void 0 : _d.status) === 'string'
        ? String(after.moderation.status).toLowerCase()
        : '';
    const mediaChanged = beforeVideo !== afterVideo || beforeImage !== afterImage || beforeThumb !== afterThumb;
    const needsModeration = afterStatus === 'pending' || afterStatus === 'review' || afterStatus === '';
    if (!mediaChanged && !needsModeration) {
        firebase_functions_1.logger.info(`[moderateReelOnWrite] skip_no_change reelId=${reelId} afterStatus=${afterStatus}`);
        return;
    }
    if (!HIVE_V3_BEARER && !HIVE_V2_TOKEN) {
        firebase_functions_1.logger.warn(`[moderateReelOnWrite] skipped_missing_key reelId=${reelId}`);
        await ref.set({
            moderation: {
                provider: 'hive',
                status: 'skipped',
                score: 0,
                reasons: ['missing_hive_api_key'],
                checkedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        }, { merge: true });
        return;
    }
    const mediaUrl = afterImage || afterThumb || (afterVideo ? toHiveImageUrl(afterVideo) : '');
    if (!mediaUrl) {
        firebase_functions_1.logger.warn(`[moderateReelOnWrite] no_media_url reelId=${reelId}`);
        return;
    }
    try {
        const res = await callHiveModeration(mediaUrl);
        firebase_functions_1.logger.info(`[moderateReelOnWrite] hive_http_status reelId=${reelId} endpoint=${res.endpoint} status=${res.status} ok=${res.ok}`);
        if (!res.ok) {
            const errSummary = summarizeErrorBody(res.payloadText);
            firebase_functions_1.logger.error(`[moderateReelOnWrite] hive_http_error reelId=${reelId} endpoint=${res.endpoint} status=${res.status} body=${errSummary}`);
            await ref.set({
                moderation: {
                    provider: 'hive',
                    status: 'error',
                    score: 0,
                    reasons: [`http_${res.status}`, `hive_endpoint:${res.endpoint}`, `hive:${errSummary}`],
                    checkedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
            }, { merge: true });
            return;
        }
        let classes = [];
        if (res.endpoint === 'v3') {
            const payload = JSON.parse(res.payloadText);
            classes = extractHiveClassScores(payload);
        }
        else {
            const payload = JSON.parse(res.payloadText);
            classes = (_g = (_f = (_e = payload.output) === null || _e === void 0 ? void 0 : _e[0]) === null || _f === void 0 ? void 0 : _f.classes) !== null && _g !== void 0 ? _g : [];
        }
        const result = evaluateHive(classes);
        await ref.set({
            moderation: {
                provider: 'hive',
                status: result.status,
                score: result.score,
                reasons: result.reasons,
                mediaUrl,
                checkedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        }, { merge: true });
        firebase_functions_1.logger.info(`[moderateReelOnWrite] final_status reelId=${reelId} status=${result.status} score=${result.score} reasons=${result.reasons.join('|')}`);
    }
    catch (e) {
        firebase_functions_1.logger.error(`[moderateReelOnWrite] exception reelId=${reelId} error=${String(e)}`);
        await ref.set({
            moderation: {
                provider: 'hive',
                status: 'error',
                score: 0,
                reasons: [String(e)],
                checkedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        }, { merge: true });
    }
});
// ── Email signup OTP (Resend) — Firestore-triggered (no Cloud Run `allUsers` invoker) ──
// Same pattern as generateAgoraTokenOnRequest: org policy blocks public IAM on HTTP callables.
/**
 * Client creates: email_otp_send_requests/{id}  { userId, status: 'pending', createdAt }
 * Function writes:   { status: 'done' }  or  { status: 'error', error }
 */
exports.processEmailOtpSendRequest = (0, firestore_1.onDocumentCreated)({
    document: 'email_otp_send_requests/{requestId}',
    timeoutSeconds: 30,
    memory: '256MiB',
}, async (event) => {
    var _a, _b;
    const snap = event.data;
    if (!snap)
        return;
    const markError = async (msg) => {
        await snap.ref.update({ status: 'error', error: msg });
    };
    if (!RESEND_API_KEY) {
        await markError('Email delivery is not configured.');
        return;
    }
    const raw = snap.data();
    const uid = typeof raw.userId === 'string'
        ? raw.userId.trim()
        : typeof raw.userId === 'number'
            ? String(raw.userId)
            : '';
    const requestedEmail = typeof raw.email === 'string' ? raw.email.trim().toLowerCase() : '';
    if (!uid) {
        await markError('Invalid request.');
        return;
    }
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(uid).get();
    const profile = userDoc.data();
    // Resolve email + password provider via Auth; fall back to Firestore profile when
    // getUser fails (e.g. transient API errors). Client rules ensure userId matches signer;
    // emailOtpVerified === false means email/password signup path.
    let email = requestedEmail;
    let isPasswordSignup = false;
    let isAnonymous = false;
    try {
        const userRecord = await (0, auth_1.getAuth)().getUser(uid);
        if (!email) {
            email = ((_a = userRecord.email) !== null && _a !== void 0 ? _a : '').trim();
        }
        isPasswordSignup = userRecord.providerData.some((p) => p.providerId === 'password');
        isAnonymous = userRecord.providerData.some((p) => p.providerId === 'anonymous');
    }
    catch (e) {
        console.error('processEmailOtpSendRequest getUser failed', uid, e);
        const emailFromDoc = typeof (profile === null || profile === void 0 ? void 0 : profile.email) === 'string' ? profile.email.trim() : '';
        if ((emailFromDoc.includes('@') || email.includes('@')) && userDoc.exists) {
            email = emailFromDoc;
            // Fallback path for transient Auth Admin lookup failures:
            // this request can only be created by the signed-in user for their own uid.
            isPasswordSignup = true;
        }
        else {
            const code = e && typeof e === 'object' && 'code' in e
                ? String(e.code)
                : '';
            if (code === 'auth/user-not-found') {
                await markError('Account not found.');
            }
            else {
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
        const last = (_b = challengeSnap.data()) === null || _b === void 0 ? void 0 : _b.lastSentAt;
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
});
/**
 * Client creates: email_otp_verify_requests/{id}  { userId, code, status: 'pending', createdAt }
 * Function writes:   { status: 'done' }  or  { status: 'error', error }
 */
exports.processEmailOtpVerifyRequest = (0, firestore_1.onDocumentCreated)({
    document: 'email_otp_verify_requests/{requestId}',
    timeoutSeconds: 30,
    memory: '256MiB',
}, async (event) => {
    var _a, _b;
    const snap = event.data;
    if (!snap)
        return;
    const markError = async (msg) => {
        await snap.ref.update({ status: 'error', error: msg });
    };
    if (!RESEND_API_KEY) {
        await markError('Email delivery is not configured.');
        return;
    }
    const raw = snap.data();
    const uid = typeof raw.userId === 'string' ? raw.userId : '';
    const code = typeof raw.code === 'string' ? raw.code.replace(/\D/g, '').slice(0, 4) : '';
    const requestedEmail = typeof raw.email === 'string' ? raw.email.trim().toLowerCase() : '';
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
    const data = challengeSnap.data();
    const expiresAt = data.expiresAt;
    if (expiresAt.toMillis() < Date.now()) {
        await challengeRef.delete();
        await markError('Code expired. Request a new one.');
        return;
    }
    let attempts = (_a = data.attempts) !== null && _a !== void 0 ? _a : 0;
    if (attempts >= EMAIL_OTP_MAX_ATTEMPTS) {
        await challengeRef.delete();
        await markError('Too many attempts. Request a new code.');
        return;
    }
    const expectedHash = data.codeHash;
    if (hashEmailOtp(uid, code) !== expectedHash) {
        attempts += 1;
        await challengeRef.update({ attempts });
        await markError('Invalid code.');
        return;
    }
    let shouldUpdateUserDoc = true;
    try {
        const userRecord = await (0, auth_1.getAuth)().getUser(uid);
        const isAnonymous = userRecord.providerData.some((p) => p.providerId === 'anonymous');
        const normalizedAuthEmail = ((_b = userRecord.email) !== null && _b !== void 0 ? _b : '').trim().toLowerCase();
        if (isAnonymous) {
            shouldUpdateUserDoc = false;
        }
        if (requestedEmail.length > 0 && normalizedAuthEmail.length > 0 && requestedEmail != normalizedAuthEmail) {
            shouldUpdateUserDoc = false;
        }
    }
    catch (_c) {
        shouldUpdateUserDoc = false;
    }
    if (shouldUpdateUserDoc) {
        await userRef.set({ emailOtpVerified: true }, { merge: true });
    }
    await challengeRef.delete();
    await snap.ref.update({ status: 'done' });
});
/**
 * Client creates: whatsapp_otp_send_requests/{id}
 * { userId, phoneNumber, status: 'pending', createdAt }
 */
exports.processWhatsAppOtpSendRequest = (0, firestore_1.onDocumentCreated)({
    document: 'whatsapp_otp_send_requests/{requestId}',
    timeoutSeconds: 30,
    memory: '256MiB',
}, async (event) => {
    var _a;
    const snap = event.data;
    if (!snap)
        return;
    const markError = async (msg) => {
        await snap.ref.update({ status: 'error', error: msg });
    };
    const twilioSender = normalizeWhatsAppSender(TWILIO_WHATSAPP_FROM);
    if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !twilioSender) {
        await markError('WhatsApp delivery is not configured.');
        return;
    }
    const raw = snap.data();
    const uid = typeof raw.userId === 'string'
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
        const last = (_a = challengeSnap.data()) === null || _a === void 0 ? void 0 : _a.lastSentAt;
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
    const twilioRes = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`, {
        method: 'POST',
        headers: {
            authorization: `Basic ${Buffer.from(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`).toString('base64')}`,
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body,
    });
    if (!twilioRes.ok) {
        const errBody = await twilioRes.text();
        firebase_functions_1.logger.error('Twilio WhatsApp send failed', { status: twilioRes.status, body: errBody.slice(0, 500) });
        await challengeRef.delete();
        await markError(parseTwilioWhatsAppFailureMessage(twilioRes.status, errBody));
        return;
    }
    await snap.ref.update({ status: 'done' });
});
/**
 * Client creates: whatsapp_otp_verify_requests/{id}
 * { userId, phoneNumber, code, status: 'pending', createdAt }
 */
exports.processWhatsAppOtpVerifyRequest = (0, firestore_1.onDocumentCreated)({
    document: 'whatsapp_otp_verify_requests/{requestId}',
    timeoutSeconds: 30,
    memory: '256MiB',
}, async (event) => {
    var _a;
    const snap = event.data;
    if (!snap)
        return;
    const markError = async (msg) => {
        await snap.ref.update({ status: 'error', error: msg });
    };
    const raw = snap.data();
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
    const data = challengeSnap.data();
    const expectedPhone = normalizePhone(data.phoneNumber);
    if (!expectedPhone || expectedPhone !== phoneNumber) {
        await markError('This code does not match the selected phone number.');
        return;
    }
    const expiresAt = data.expiresAt;
    if (expiresAt.toMillis() < Date.now()) {
        await challengeRef.delete();
        await markError('Code expired. Request a new one.');
        return;
    }
    let attempts = (_a = data.attempts) !== null && _a !== void 0 ? _a : 0;
    if (attempts >= WHATSAPP_OTP_MAX_ATTEMPTS) {
        await challengeRef.delete();
        await markError('Too many attempts. Request a new code.');
        return;
    }
    const expectedHash = data.codeHash;
    if (hashWhatsAppOtp(uid, phoneNumber, code) !== expectedHash) {
        attempts += 1;
        await challengeRef.update({ attempts });
        await markError('Invalid code.');
        return;
    }
    await userRef.set({ emailOtpVerified: true }, { merge: true });
    await challengeRef.delete();
    await snap.ref.update({ status: 'done' });
});
// ── sendPushOnNotificationCreate ───────────────────────────────────────────────
exports.sendPushOnNotificationCreate = (0, firestore_1.onDocumentCreated)({
    document: 'notifications/{notificationId}',
    timeoutSeconds: 20,
    memory: '256MiB',
}, async (event) => {
    var _a, _b;
    const snap = event.data;
    if (!snap)
        return;
    const data = snap.data();
    const recipientId = typeof data.recipientId === 'string' ? data.recipientId.trim() : '';
    if (!recipientId)
        return;
    const actor = typeof data.actorUsername === 'string' && data.actorUsername.trim().length > 0
        ? data.actorUsername.trim()
        : 'Someone';
    const body = typeof data.message === 'string' && data.message.trim().length > 0
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
        await snap.ref.set({
            pushDelivery: {
                status: 'no_tokens',
                tokenCount: 0,
                attemptedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        }, { merge: true });
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
        const errorCodes = new Set();
        for (const r of response.responses) {
            const code = (_b = (_a = r.error) === null || _a === void 0 ? void 0 : _a.code) === null || _b === void 0 ? void 0 : _b.trim();
            if (code)
                errorCodes.add(code);
        }
        await snap.ref.set({
            pushDelivery: {
                status: response.failureCount == 0 ? 'sent' : 'partial_failure',
                tokenCount: tokens.length,
                successCount: response.successCount,
                failureCount: response.failureCount,
                errorCodes: Array.from(errorCodes),
                attemptedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        }, { merge: true });
        if (response.failureCount > 0) {
            firebase_functions_1.logger.warn('sendPushOnNotificationCreate partial failure', {
                notificationId: snap.id,
                successCount: response.successCount,
                failureCount: response.failureCount,
            });
        }
    }
    catch (e) {
        await snap.ref.set({
            pushDelivery: {
                status: 'error',
                tokenCount: tokens.length,
                attemptedAt: admin.firestore.FieldValue.serverTimestamp(),
                error: String(e),
            },
        }, { merge: true });
        throw e;
    }
});
//# sourceMappingURL=index.js.map