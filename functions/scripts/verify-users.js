#!/usr/bin/env node
/* eslint-disable no-console */
// One-off admin tool: grant the verification badge to specific usernames.
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=<key.json> node scripts/verify-users.js --usernames=a,b,c [--commit]
// Dry-run by default; pass --commit to write.
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const shouldCommit = args.includes('--commit');
const projectArg = args.find((arg) => arg.startsWith('--project='));
const usernamesArg = args.find((arg) => arg.startsWith('--usernames='));
const cliProjectId = projectArg ? projectArg.split('=')[1].trim() : '';

const targets = usernamesArg
  ? usernamesArg
      .slice('--usernames='.length)
      .split(',')
      .map((v) => v.trim())
      .filter(Boolean)
  : [];

if (targets.length === 0) {
  console.error('No usernames provided. Use --usernames=a,b,c');
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
  projectFromFirebaserc();

if (!projectId) {
  console.error('Project ID not found. Pass --project=<id>.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

async function run() {
  console.log(`Using project: ${projectId}`);
  console.log(`Mode: ${shouldCommit ? 'COMMIT' : 'dry-run'}`);

  // Build a case-insensitive index of target usernames.
  const wanted = new Map(); // lowercase -> original input
  for (const t of targets) wanted.set(t.toLowerCase(), t);

  // Exact-match queries first (cheap), then one full scan fallback for
  // any usernames not found due to case differences.
  const found = new Map(); // lowercase -> array of {id, data}

  for (const t of targets) {
    const snap = await db.collection('users').where('username', '==', t).get();
    if (!snap.empty) {
      found.set(
        t.toLowerCase(),
        snap.docs.map((d) => ({ id: d.id, data: d.data() })),
      );
    }
  }

  const missing = [...wanted.keys()].filter((k) => !found.has(k));
  if (missing.length > 0) {
    console.log(
      `Exact match missed: ${missing.join(', ')} — scanning users for case-insensitive matches...`,
    );
    let lastDoc = null;
    let scanned = 0;
    while (true) {
      let query = db
        .collection('users')
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(500);
      if (lastDoc) query = query.startAfter(lastDoc);
      const snap = await query.get();
      if (snap.empty) break;
      scanned += snap.docs.length;
      for (const doc of snap.docs) {
        const uname = String(doc.data().username || '').toLowerCase();
        if (wanted.has(uname) && !found.has(uname)) {
          found.set(uname, []);
        }
        if (wanted.has(uname)) {
          const arr = found.get(uname);
          if (!arr.some((e) => e.id === doc.id)) {
            arr.push({ id: doc.id, data: doc.data() });
          }
        }
      }
      lastDoc = snap.docs[snap.docs.length - 1];
    }
    console.log(`Scanned ${scanned} user docs.`);
  }

  let updates = 0;
  for (const [key, original] of wanted.entries()) {
    const matches = found.get(key) || [];
    if (matches.length === 0) {
      console.log(`NOT FOUND: ${original}`);
      continue;
    }
    if (matches.length > 1) {
      console.log(
        `WARNING: ${original} matched ${matches.length} docs: ${matches
          .map((m) => `${m.id} (${m.data.username})`)
          .join(', ')} — updating all.`,
      );
    }
    for (const m of matches) {
      const already = m.data.isVerified === true;
      console.log(
        `${shouldCommit ? '[commit]' : '[dry-run]'} ${m.data.username} (uid=${m.id}) ` +
          `isVerified ${m.data.isVerified ?? 'missing'} -> true, ` +
          `verificationStatus ${m.data.verificationStatus ?? 'missing'} -> verified` +
          (already ? ' (already verified)' : ''),
      );
      if (shouldCommit) {
        await db.collection('users').doc(m.id).update({
          isVerified: true,
          verificationStatus: 'verified',
        });
        // Close out any open verification requests so the UI shows "Verified".
        const reqs = await db
          .collection('verification_requests')
          .where('uid', '==', m.id)
          .get();
        for (const r of reqs.docs) {
          const st = String(r.data().status || '').toLowerCase();
          if (st === 'pending' || st === 'submitted' || st === 'in_review') {
            await r.ref.update({
              status: 'verified',
              reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
              reviewedBy: 'admin-script',
            });
            console.log(`  closed open verification request ${r.id}`);
          }
        }
        updates += 1;
      }
    }
  }

  console.log(
    shouldCommit
      ? `Done. Updated ${updates} user doc(s).`
      : 'Dry-run complete. Re-run with --commit to apply.',
  );
}

run().catch((err) => {
  console.error('Failed:', err.message || err);
  process.exit(1);
});
