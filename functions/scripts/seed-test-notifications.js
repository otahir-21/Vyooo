#!/usr/bin/env node
/* eslint-disable no-console */
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const shouldCommit = args.includes('--commit');
const targetUserArg = args.find((arg) => arg.startsWith('--target-user='));
const senderUserArg = args.find((arg) => arg.startsWith('--sender-user='));
const countArg = args.find((arg) => arg.startsWith('--count='));
const projectArg = args.find((arg) => arg.startsWith('--project='));

const targetUserId = targetUserArg ? targetUserArg.split('=')[1].trim() : '';
const senderUserId = senderUserArg ? senderUserArg.split('=')[1].trim() : 'test_sender';
const requestedCount = countArg ? Number(countArg.split('=')[1]) : 5;
const sampleCount = Number.isFinite(requestedCount)
  ? Math.max(1, Math.min(50, Math.floor(requestedCount)))
  : 5;
const cliProjectId = projectArg ? projectArg.split('=')[1].trim() : '';

if (!targetUserId) {
  console.error('Missing --target-user=<uid>');
  process.exit(1);
}

function projectFromFirebaserc() {
  try {
    const rcPath = path.resolve(__dirname, '../../.firebaserc');
    if (!fs.existsSync(rcPath)) return '';
    const raw = fs.readFileSync(rcPath, 'utf8');
    const parsed = JSON.parse(raw);
    return String(parsed?.projects?.default || '').trim();
  } catch (_) {
    return '';
  }
}

const projectId =
  cliProjectId ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  process.env.FIREBASE_CONFIG_PROJECT ||
  projectFromFirebaserc();

if (!projectId) {
  console.error(
    'Project ID not found. Pass --project=<id> or set GOOGLE_CLOUD_PROJECT.',
  );
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

const templates = [
  { type: 'like', message: 'liked your post.' },
  { type: 'comment', message: 'commented on your post.' },
  { type: 'follow', message: 'started following you.' },
  { type: 'share', message: 'shared your post.' },
  { type: 'subscribe', message: 'subscribed to your content.' },
];

function notificationPayload(index) {
  const t = templates[index % templates.length];
  const minsAgo = index * 7;
  return {
    recipientId: targetUserId,
    senderId: senderUserId,
    type: t.type,
    message: t.message,
    actorUsername: `tester_${senderUserId}`,
    actorAvatarUrl: '',
    isRead: false,
    createdAt: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - minsAgo * 60 * 1000),
    ),
    reelId: `test_reel_${index + 1}`,
    commentId: t.type === 'comment' ? `test_comment_${index + 1}` : '',
    source: 'seed-test-notifications',
  };
}

async function run() {
  console.log(`Using project: ${projectId}`);
  console.log(
    shouldCommit
      ? 'Running in COMMIT mode. Test notifications will be written.'
      : 'Running in DRY-RUN mode. No documents will be written.',
  );
  console.log(`Target user: ${targetUserId}`);
  console.log(`Sender user: ${senderUserId}`);
  console.log(`Count: ${sampleCount}`);

  const payloads = Array.from(
    { length: sampleCount },
    (_, i) => notificationPayload(i),
  );

  if (!shouldCommit) {
    for (const [i, p] of payloads.entries()) {
      console.log(`[dry-run ${i + 1}]`, p);
    }
    console.log('Done.');
    return;
  }

  const batch = db.batch();
  for (const payload of payloads) {
    const ref = db.collection('notifications').doc();
    batch.set(ref, payload);
  }
  await batch.commit();
  console.log(`Created notifications: ${payloads.length}`);
  console.log('Done.');
}

run().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
