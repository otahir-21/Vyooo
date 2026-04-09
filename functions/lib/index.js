"use strict";
var _a, _b, _c, _d, _e, _f;
Object.defineProperty(exports, "__esModule", { value: true });
exports.processEmailOtpVerifyRequest = exports.processEmailOtpSendRequest = exports.moderateReelOnCreate = exports.syncFollowersCountOnFollowingChange = exports.getCloudflareUploadUrl = exports.generateAgoraTokenOnRequest = void 0;
const crypto = require("crypto");
const admin = require("firebase-admin");
const auth_1 = require("firebase-admin/auth");
const firestore_1 = require("firebase-functions/v2/firestore");
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
const HIVE_API_KEY = (_d = process.env.HIVE_API_KEY) !== null && _d !== void 0 ? _d : '';
const HIVE_SYNC_URL = 'https://api.thehive.ai/api/v2/task/sync';
const HIVE_BLOCK_THRESHOLD = 0.95;
const HIVE_REVIEW_THRESHOLD = 0.90;
// Resend (email OTP). Set RESEND_API_KEY in environment (e.g. functions/.env.vyooov1 — gitignored).
// Set RESEND_FROM_EMAIL to an address on your verified domain (e.g. noreply@vyooo.com). If you omit it,
// the default onboarding@resend.dev sender applies — Resend then only allows "test" recipients (account email).
const RESEND_API_KEY = ((_e = process.env.RESEND_API_KEY) !== null && _e !== void 0 ? _e : '').trim();
const RESEND_FROM_EMAIL = ((_f = process.env.RESEND_FROM_EMAIL) !== null && _f !== void 0 ? _f : 'Vyooo <onboarding@resend.dev>').trim();
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
function hashEmailOtp(uid, plain) {
    return crypto
        .createHash('sha256')
        .update(`vyooo-otp-v1:${RESEND_API_KEY}:${uid}:${plain}`, 'utf8')
        .digest('hex');
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
exports.moderateReelOnCreate = (0, firestore_1.onDocumentCreated)({
    document: 'reels/{reelId}',
    timeoutSeconds: 25,
    memory: '256MiB',
}, async (event) => {
    var _a, _b, _c;
    const snap = event.data;
    if (!snap)
        return;
    const data = snap.data();
    if (!HIVE_API_KEY) {
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
    if (!videoUrl)
        return;
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
            await snap.ref.set({
                moderation: {
                    provider: 'hive',
                    status: 'error',
                    score: 0,
                    reasons: [`http_${res.status}`],
                    checkedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
            }, { merge: true });
            return;
        }
        const payload = (await res.json());
        const classes = (_c = (_b = (_a = payload.output) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.classes) !== null && _c !== void 0 ? _c : [];
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
    }
    catch (e) {
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
    let email = '';
    let isPasswordSignup = false;
    try {
        const userRecord = await (0, auth_1.getAuth)().getUser(uid);
        email = ((_a = userRecord.email) !== null && _a !== void 0 ? _a : '').trim();
        isPasswordSignup = userRecord.providerData.some((p) => p.providerId === 'password');
    }
    catch (e) {
        console.error('processEmailOtpSendRequest getUser failed', uid, e);
        const emailFromDoc = typeof (profile === null || profile === void 0 ? void 0 : profile.email) === 'string' ? profile.email.trim() : '';
        if (emailFromDoc.includes('@') && userDoc.exists) {
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
    if (!isPasswordSignup) {
        await markError('Email verification not required.');
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
    var _a;
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
    await userRef.set({ emailOtpVerified: true }, { merge: true });
    await challengeRef.delete();
    await snap.ref.update({ status: 'done' });
});
//# sourceMappingURL=index.js.map