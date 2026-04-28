#!/usr/bin/env node
/* eslint-disable no-console */
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const shouldCommit = args.includes('--commit');
const pageSizeArg = args.find((arg) => arg.startsWith('--page-size='));
const pageSize = pageSizeArg ? Number(pageSizeArg.split('=')[1]) : 400;
const projectArg = args.find((arg) => arg.startsWith('--project='));
const cliProjectId = projectArg ? projectArg.split('=')[1].trim() : '';

if (!Number.isFinite(pageSize) || pageSize <= 0 || pageSize > 500) {
  console.error('Invalid --page-size value. Use a number between 1 and 500.');
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

function inferMediaType(data) {
  const rawType = String(data.mediaType || '').trim().toLowerCase();
  if (rawType === 'image' || rawType === 'video') return rawType;

  const imageUrl = String(data.imageUrl || '').trim();
  const videoUrl = String(data.videoUrl || '').trim();
  if (imageUrl && !videoUrl) return 'image';
  return 'video';
}

function buildPatch(data) {
  const patch = {};
  const mediaType = inferMediaType(data);
  const imageUrl = String(data.imageUrl || '').trim();
  const thumbnailUrl = String(data.thumbnailUrl || '').trim();

  if ((String(data.mediaType || '').trim().toLowerCase()) !== mediaType) {
    patch.mediaType = mediaType;
  }

  if (mediaType === 'image' && !thumbnailUrl && imageUrl) {
    patch.thumbnailUrl = imageUrl;
  }

  return patch;
}

async function run() {
  console.log(`Using project: ${projectId}`);
  console.log(
    shouldCommit
      ? 'Running in COMMIT mode. Firestore will be updated.'
      : 'Running in DRY-RUN mode. No documents will be changed.',
  );

  let lastDoc = null;
  let scanned = 0;
  let toUpdate = 0;
  let updated = 0;
  let batch = db.batch();
  let batchOps = 0;

  while (true) {
    let query = db.collection('reels').orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data() || {};
      const patch = buildPatch(data);
      const keys = Object.keys(patch);
      if (keys.length === 0) continue;
      toUpdate += 1;

      if (shouldCommit) {
        batch.update(doc.ref, patch);
        batchOps += 1;
        if (batchOps >= 450) {
          await batch.commit();
          updated += batchOps;
          batch = db.batch();
          batchOps = 0;
        }
      } else {
        console.log(`[dry-run] ${doc.id}`, patch);
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
  }

  if (shouldCommit && batchOps > 0) {
    await batch.commit();
    updated += batchOps;
  }

  console.log('---');
  console.log(`Scanned reels: ${scanned}`);
  console.log(`Needs update: ${toUpdate}`);
  console.log(`Updated docs: ${shouldCommit ? updated : 0}`);
  console.log('Done.');
}

run().catch((err) => {
  console.error('Cleanup failed:', err);
  process.exit(1);
});
