"use strict";
var _a;
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateAgoraTokenOnRequest = void 0;
const admin = require("firebase-admin");
const firestore_1 = require("firebase-functions/v2/firestore");
const agora_access_token_1 = require("agora-access-token");
admin.initializeApp();
// ── Constants ──────────────────────────────────────────────────────────────────
const APP_ID = '443105d5684f492088bb004196b3fee8';
const TOKEN_TTL_SECONDS = 3600; // 1 hour
// App Certificate is injected at deploy time via .env.vyooov1
const APP_CERTIFICATE = (_a = process.env.AGORA_APP_CERTIFICATE) !== null && _a !== void 0 ? _a : '';
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
//# sourceMappingURL=index.js.map