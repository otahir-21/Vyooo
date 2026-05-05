"use strict";
var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l;
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupExpiredViewOnceMessages = exports.onViewOnceMessageUpdate = exports.onChatUpdate = exports.onChatMessageCreate = exports.onChatCreate = exports.sendPushOnNotificationCreate = exports.processWhatsAppOtpVerifyRequest = exports.processWhatsAppOtpSendRequest = exports.processEmailOtpVerifyRequest = exports.processEmailOtpSendRequest = exports.moderateReelOnWrite = exports.moderateReelOnCreate = exports.syncFollowersCountOnFollowingChange = exports.getCloudflareUploadUrl = exports.generateAgoraTokenOnRequest = void 0;
const crypto = require("crypto");
const admin = require("firebase-admin");
const auth_1 = require("firebase-admin/auth");
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
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
        if (emailFromDoc.includes('@') || email.includes('@')) {
            email = emailFromDoc;
            if (!email && requestedEmail.includes('@')) {
                email = requestedEmail;
            }
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
// ── Chat: onChatCreate ────────────────────────────────────────────────────────
exports.onChatCreate = (0, firestore_1.onDocumentCreated)({
    document: 'chats/{chatId}',
    timeoutSeconds: 30,
    memory: '256MiB',
}, async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const db = admin.firestore();
    const chatId = event.params.chatId;
    const data = snap.data();
    const type = typeof data.type === 'string' ? data.type : '';
    const participantIds = Array.isArray(data.participantIds)
        ? data.participantIds.filter((v) => typeof v === 'string' && v.length > 0)
        : [];
    const createdBy = typeof data.createdBy === 'string' ? data.createdBy : '';
    if (!participantIds.includes(createdBy)) {
        firebase_functions_1.logger.error('onChatCreate: createdBy not in participantIds', { chatId, createdBy });
        await snap.ref.update({ _invalid: true, _invalidReason: 'creator_not_participant' });
        return;
    }
    const uniqueIds = [...new Set(participantIds)];
    if (type === 'direct') {
        if (uniqueIds.length !== 2) {
            firebase_functions_1.logger.error('onChatCreate: invalid direct chat', { chatId, type, participantIds });
            await snap.ref.update({ _invalid: true, _invalidReason: 'bad_shape' });
            return;
        }
        const [userASnap, userBSnap] = await Promise.all([
            db.collection('users').doc(uniqueIds[0]).get(),
            db.collection('users').doc(uniqueIds[1]).get(),
        ]);
        const userA = userASnap.data();
        const userB = userBSnap.data();
        const nameOf = (u) => {
            if (!u)
                return '';
            const dn = typeof u.displayName === 'string' ? u.displayName.trim() : '';
            if (dn)
                return dn;
            return typeof u.username === 'string' ? u.username.trim() : '';
        };
        const avatarOf = (u) => {
            if (!u)
                return '';
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
        batch.set(db.collection('users').doc(uniqueIds[0]).collection('chatSummaries').doc(chatId), Object.assign(Object.assign({}, baseSummary), { chatId, title: nameOf(userB), avatarUrl: avatarOf(userB) }), { merge: true });
        batch.set(db.collection('users').doc(uniqueIds[1]).collection('chatSummaries').doc(chatId), Object.assign(Object.assign({}, baseSummary), { chatId, title: nameOf(userA), avatarUrl: avatarOf(userA) }), { merge: true });
        await batch.commit();
        firebase_functions_1.logger.info('onChatCreate: direct summaries created', { chatId });
    }
    else if (type === 'group') {
        if (uniqueIds.length < 3 || uniqueIds.length > 256) {
            firebase_functions_1.logger.error('onChatCreate: invalid group size', { chatId, size: uniqueIds.length });
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
                batch.set(db.collection('users').doc(uid).collection('chatSummaries').doc(chatId), Object.assign(Object.assign({}, baseSummary), { chatId }), { merge: true });
            }
            await batch.commit();
        }
        firebase_functions_1.logger.info('onChatCreate: group summaries created', { chatId, members: uniqueIds.length });
    }
    else {
        firebase_functions_1.logger.error('onChatCreate: unknown chat type', { chatId, type });
        await snap.ref.update({ _invalid: true, _invalidReason: 'unknown_type' });
    }
});
// ── Chat: onChatMessageCreate ─────────────────────────────────────────────────
exports.onChatMessageCreate = (0, firestore_1.onDocumentCreated)({
    document: 'chats/{chatId}/messages/{messageId}',
    timeoutSeconds: 30,
    memory: '256MiB',
}, async (event) => {
    var _a;
    const snap = event.data;
    if (!snap)
        return;
    const db = admin.firestore();
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const msg = snap.data();
    const senderId = typeof msg.senderId === 'string' ? msg.senderId : '';
    const msgType = typeof msg.type === 'string' ? msg.type : '';
    const text = typeof msg.text === 'string' ? msg.text : '';
    const trimmedText = text.trim();
    const mediaUrl = typeof msg.mediaUrl === 'string' ? msg.mediaUrl : '';
    const storagePath = typeof msg.storagePath === 'string' ? msg.storagePath : '';
    const chatSnap = await db.collection('chats').doc(chatId).get();
    if (!chatSnap.exists) {
        firebase_functions_1.logger.error('onChatMessageCreate: parent chat missing', { chatId, messageId });
        await snap.ref.update({ _rejected: true, _rejectedReason: 'no_parent_chat' });
        return;
    }
    const chatData = chatSnap.data();
    const chatType = typeof chatData.type === 'string' ? chatData.type : 'direct';
    const participantIds = Array.isArray(chatData.participantIds)
        ? chatData.participantIds.filter((v) => typeof v === 'string' && v.length > 0)
        : [];
    if (!senderId || !participantIds.includes(senderId)) {
        firebase_functions_1.logger.error('onChatMessageCreate: invalid senderId', { chatId, messageId, senderId });
        await snap.ref.update({ _rejected: true, _rejectedReason: 'invalid_sender' });
        return;
    }
    const allowedTypes = ['text', 'image', 'video'];
    if (!allowedTypes.includes(msgType)) {
        firebase_functions_1.logger.error('onChatMessageCreate: unsupported type', { chatId, messageId, msgType });
        await snap.ref.update({ _rejected: true, _rejectedReason: 'unsupported_type' });
        return;
    }
    if (msgType === 'text' && !trimmedText) {
        firebase_functions_1.logger.error('onChatMessageCreate: empty text', { chatId, messageId });
        await snap.ref.update({ _rejected: true, _rejectedReason: 'empty_text' });
        return;
    }
    if ((msgType === 'image' || msgType === 'video') && (!mediaUrl || !storagePath)) {
        firebase_functions_1.logger.error('onChatMessageCreate: missing media fields', { chatId, messageId, msgType });
        await snap.ref.update({ _rejected: true, _rejectedReason: 'missing_media_fields' });
        return;
    }
    const isViewOnce = msg.isViewOnce === true;
    if (isViewOnce && msgType === 'text') {
        firebase_functions_1.logger.error('onChatMessageCreate: view-once text not allowed', { chatId, messageId });
        await snap.ref.update({ _rejected: true, _rejectedReason: 'view_once_text_not_allowed' });
        return;
    }
    if (isViewOnce) {
        const expiresAt = msg.expiresAt;
        if (!expiresAt) {
            const createdAt = msg.createdAt;
            const baseMs = createdAt ? createdAt.toMillis() : Date.now();
            const expiry = admin.firestore.Timestamp.fromMillis(baseMs + 14 * 24 * 60 * 60 * 1000);
            await snap.ref.update({ expiresAt: expiry });
        }
    }
    let preview;
    if (isViewOnce) {
        preview = msgType === 'video' ? '🔒 View-once video' : '🔒 View-once photo';
    }
    else if (msgType === 'image') {
        preview = '📷 Photo';
    }
    else if (msgType === 'video') {
        preview = '🎥 Video';
    }
    else {
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
            if (!uid)
                continue;
            const isSender = uid === senderId;
            const summaryRef = db.collection('users').doc(uid).collection('chatSummaries').doc(chatId);
            batch.set(summaryRef, Object.assign({ lastMessage: preview, lastMessageAt: now, lastMessageSenderId: senderId, participantIds, type: chatType }, (isSender ? { unreadCount: 0 } : { unreadCount: admin.firestore.FieldValue.increment(1) })), { merge: true });
        }
        await batch.commit();
    }
    firebase_functions_1.logger.info('onChatMessageCreate: metadata fanout done', { chatId, messageId });
    // ── FCM push notifications ────────────────────────────────────────────────
    try {
        const mutedBy = Array.isArray(chatData.mutedBy)
            ? chatData.mutedBy.filter((v) => typeof v === 'string')
            : [];
        const recipientIds = participantIds.filter((uid) => uid !== senderId && !mutedBy.includes(uid));
        if (recipientIds.length === 0) {
            firebase_functions_1.logger.info('onChatMessageCreate: no push recipients', { chatId, messageId });
        }
        else {
            const tokenSnaps = await Promise.all(recipientIds.map((uid) => db.collection('users').doc(uid).collection('push_tokens').get()));
            const tokens = [];
            for (const snap of tokenSnaps) {
                for (const doc of snap.docs) {
                    const t = (_a = doc.data()) === null || _a === void 0 ? void 0 : _a.token;
                    if (typeof t === 'string' && t.length > 0)
                        tokens.push(t);
                }
            }
            if (tokens.length > 0) {
                const senderMap = chatData.participantMap;
                const senderInfo = senderMap === null || senderMap === void 0 ? void 0 : senderMap[senderId];
                const senderDisplayName = (typeof (senderInfo === null || senderInfo === void 0 ? void 0 : senderInfo.displayName) === 'string' && senderInfo.displayName.trim())
                    ? senderInfo.displayName.trim()
                    : (typeof (senderInfo === null || senderInfo === void 0 ? void 0 : senderInfo.username) === 'string' && senderInfo.username.trim())
                        ? senderInfo.username.trim()
                        : 'Someone';
                const groupName = typeof chatData.groupName === 'string' ? chatData.groupName.trim() : '';
                let notifTitle;
                if (chatType === 'group' && groupName) {
                    notifTitle = groupName;
                }
                else {
                    notifTitle = senderDisplayName;
                }
                let notifBody;
                if (msgType === 'image') {
                    notifBody = chatType === 'group' ? `${senderDisplayName}: Sent a photo` : 'Sent a photo';
                }
                else if (msgType === 'video') {
                    notifBody = chatType === 'group' ? `${senderDisplayName}: Sent a video` : 'Sent a video';
                }
                else {
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
                            var _a, _b;
                            if (!r.success) {
                                firebase_functions_1.logger.warn('onChatMessageCreate: FCM send failed', {
                                    token: (_a = batch[idx]) === null || _a === void 0 ? void 0 : _a.substring(0, 10),
                                    error: (_b = r.error) === null || _b === void 0 ? void 0 : _b.message,
                                });
                            }
                        });
                    }
                }
                firebase_functions_1.logger.info('onChatMessageCreate: push sent', { chatId, messageId, tokenCount: tokens.length });
            }
        }
    }
    catch (pushErr) {
        firebase_functions_1.logger.error('onChatMessageCreate: push notification failed (non-fatal)', { chatId, messageId, error: String(pushErr) });
    }
});
// ── Chat: onChatUpdate (sync group metadata to summaries) ─────────────────────
exports.onChatUpdate = (0, firestore_1.onDocumentWritten)({
    document: 'chats/{chatId}',
    timeoutSeconds: 30,
    memory: '256MiB',
}, async (event) => {
    var _a, _b, _c, _d;
    const before = (_b = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before) === null || _b === void 0 ? void 0 : _b.data();
    const after = (_d = (_c = event.data) === null || _c === void 0 ? void 0 : _c.after) === null || _d === void 0 ? void 0 : _d.data();
    if (!before || !after)
        return;
    const chatId = event.params.chatId;
    const chatType = typeof after.type === 'string' ? after.type : '';
    if (chatType !== 'group')
        return;
    const oldName = typeof before.groupName === 'string' ? before.groupName : '';
    const newName = typeof after.groupName === 'string' ? after.groupName : '';
    const oldImage = typeof before.groupImageUrl === 'string' ? before.groupImageUrl : '';
    const newImage = typeof after.groupImageUrl === 'string' ? after.groupImageUrl : '';
    const oldParticipants = Array.isArray(before.participantIds) ? before.participantIds : [];
    const newParticipants = Array.isArray(after.participantIds)
        ? after.participantIds.filter((v) => typeof v === 'string')
        : [];
    if (oldName === newName && oldImage === newImage && JSON.stringify(oldParticipants) === JSON.stringify(newParticipants)) {
        return;
    }
    const db = admin.firestore();
    const updates = {};
    if (oldName !== newName)
        updates.title = newName;
    if (oldImage !== newImage)
        updates.avatarUrl = newImage;
    if (JSON.stringify(oldParticipants) !== JSON.stringify(newParticipants)) {
        updates.participantIds = newParticipants;
    }
    if (Object.keys(updates).length === 0)
        return;
    const batchSize = 500;
    for (let i = 0; i < newParticipants.length; i += batchSize) {
        const chunk = newParticipants.slice(i, i + batchSize);
        const batch = db.batch();
        for (const uid of chunk) {
            if (typeof uid !== 'string' || !uid)
                continue;
            batch.set(db.collection('users').doc(uid).collection('chatSummaries').doc(chatId), updates, { merge: true });
        }
        await batch.commit();
    }
    firebase_functions_1.logger.info('onChatUpdate: synced group metadata', { chatId, fields: Object.keys(updates) });
});
// ── Chat: onViewOnceMessageUpdate ─────────────────────────────────────────────
exports.onViewOnceMessageUpdate = (0, firestore_1.onDocumentUpdated)({
    document: 'chats/{chatId}/messages/{messageId}',
    timeoutSeconds: 30,
    memory: '256MiB',
}, async (event) => {
    var _a, _b, _c, _d;
    const before = (_b = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before) === null || _b === void 0 ? void 0 : _b.data();
    const after = (_d = (_c = event.data) === null || _c === void 0 ? void 0 : _c.after) === null || _d === void 0 ? void 0 : _d.data();
    if (!before || !after)
        return;
    if (after.isViewOnce !== true)
        return;
    const beforeViewedBy = Array.isArray(before.viewedBy) ? before.viewedBy : [];
    const afterViewedBy = Array.isArray(after.viewedBy) ? after.viewedBy : [];
    if (afterViewedBy.length <= beforeViewedBy.length)
        return;
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const senderId = typeof after.senderId === 'string' ? after.senderId : '';
    const storagePath = typeof after.storagePath === 'string' ? after.storagePath : '';
    const db = admin.firestore();
    const chatSnap = await db.collection('chats').doc(chatId).get();
    if (!chatSnap.exists)
        return;
    const chatData = chatSnap.data();
    const participantIds = Array.isArray(chatData.participantIds)
        ? chatData.participantIds.filter((v) => typeof v === 'string' && v.length > 0)
        : [];
    const eligibleRecipients = participantIds.filter((uid) => uid !== senderId);
    const allViewed = eligibleRecipients.length > 0 &&
        eligibleRecipients.every((uid) => afterViewedBy.includes(uid));
    if (!allViewed) {
        firebase_functions_1.logger.info('onViewOnceMessageUpdate: not all recipients viewed yet', {
            chatId, messageId, viewed: afterViewedBy.length, eligible: eligibleRecipients.length,
        });
        return;
    }
    firebase_functions_1.logger.info('onViewOnceMessageUpdate: all recipients viewed, cleaning up', { chatId, messageId });
    if (storagePath) {
        try {
            await admin.storage().bucket().file(storagePath).delete();
            firebase_functions_1.logger.info('onViewOnceMessageUpdate: deleted storage file', { storagePath });
        }
        catch (err) {
            firebase_functions_1.logger.warn('onViewOnceMessageUpdate: storage delete failed (non-fatal)', { storagePath, error: String(err) });
        }
    }
    try {
        await event.data.after.ref.update({
            mediaUrl: '',
            thumbnailUrl: '',
            storagePath: '',
            'metadata.cleanedUpAt': admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (err) {
        firebase_functions_1.logger.error('onViewOnceMessageUpdate: doc cleanup update failed', { chatId, messageId, error: String(err) });
    }
});
// ── Chat: cleanupExpiredViewOnceMessages (scheduled) ──────────────────────────
exports.cleanupExpiredViewOnceMessages = (0, scheduler_1.onSchedule)({
    schedule: 'every 6 hours',
    timeoutSeconds: 120,
    memory: '256MiB',
}, async () => {
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
        firebase_functions_1.logger.info('cleanupExpiredViewOnceMessages: no expired view-once messages');
        return;
    }
    firebase_functions_1.logger.info('cleanupExpiredViewOnceMessages: found expired messages', { count: expiredSnap.size });
    for (const doc of expiredSnap.docs) {
        const data = doc.data();
        const storagePath = typeof data.storagePath === 'string' ? data.storagePath : '';
        if (storagePath) {
            try {
                await admin.storage().bucket().file(storagePath).delete();
            }
            catch (err) {
                firebase_functions_1.logger.warn('cleanupExpiredViewOnceMessages: storage delete failed', { docPath: doc.ref.path, error: String(err) });
            }
        }
        try {
            await doc.ref.update({
                mediaUrl: '',
                thumbnailUrl: '',
                storagePath: '',
                'metadata.cleanedUpAt': admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        catch (err) {
            firebase_functions_1.logger.error('cleanupExpiredViewOnceMessages: doc update failed', { docPath: doc.ref.path, error: String(err) });
        }
    }
    firebase_functions_1.logger.info('cleanupExpiredViewOnceMessages: cleanup done', { processed: expiredSnap.size });
});
//# sourceMappingURL=index.js.map