import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

const WEB_HOST = 'www.vyooo.com';
const DEFAULT_OG_IMAGE = `https://${WEB_HOST}/og-image.png`;
const ANDROID_STORE =
  'https://play.google.com/store/apps/details?id=com.vyooo';
const IOS_STORE = ANDROID_STORE;

type LinkKind = 'profile' | 'reel';

interface LinkRef {
  kind: LinkKind;
  ref: string;
}

interface OgPayload {
  title: string;
  description: string;
  image: string;
  canonicalUrl: string;
  pageHeading: string;
  pageSubheading: string;
  ogType: 'profile' | 'article' | 'website';
  appUrl: string | null;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function trimText(value: unknown, maxLen: number): string {
  const text = typeof value === 'string' ? value.trim() : '';
  if (text.length <= maxLen) return text;
  return `${text.slice(0, Math.max(0, maxLen - 1)).trimEnd()}…`;
}

function normalizeUsername(raw: string): string {
  let value = raw.trim();
  if (value.startsWith('@')) value = value.slice(1);
  return value.replace(/\s/g, '');
}

function formatCount(n: number): string {
  if (!Number.isFinite(n) || n < 0) return '0';
  return n.toLocaleString('en-US');
}

function absoluteHttpsUrl(raw: unknown): string {
  const value = typeof raw === 'string' ? raw.trim() : '';
  if (!value) return '';
  try {
    const uri = new URL(value);
    if (uri.protocol !== 'http:' && uri.protocol !== 'https:') return '';
    if (!uri.host) return '';
    if (uri.protocol === 'http:') uri.protocol = 'https:';
    return uri.toString();
  } catch {
    return '';
  }
}

function streamThumbnailFromVideoUrl(videoUrl: string): string {
  try {
    const uri = new URL(videoUrl);
    const videoId = uri.pathname.split('/').filter(Boolean)[0] ?? '';
    if (!videoId) return '';
    return `https://videodelivery.net/${videoId}/thumbnails/thumbnail.jpg`;
  } catch {
    return '';
  }
}

function reelPreviewImage(data: FirebaseFirestore.DocumentData): string {
  const thumb = absoluteHttpsUrl(data.thumbnailUrl);
  if (thumb) return thumb;

  const mediaItems = Array.isArray(data.mediaItems) ? data.mediaItems : [];
  for (const item of mediaItems) {
    if (!item || typeof item !== 'object') continue;
    const itemThumb = absoluteHttpsUrl((item as { thumbnailUrl?: string }).thumbnailUrl);
    if (itemThumb) return itemThumb;
    const type = String((item as { type?: string }).type ?? '').toLowerCase();
    const url = absoluteHttpsUrl((item as { url?: string }).url);
    if (type === 'image' && url) return url;
  }

  const imageUrl = absoluteHttpsUrl(data.imageUrl);
  if (imageUrl) return imageUrl;

  const videoUrl = typeof data.videoUrl === 'string' ? data.videoUrl.trim() : '';
  if (videoUrl) return streamThumbnailFromVideoUrl(videoUrl);

  const avatar = absoluteHttpsUrl(data.avatarUrl ?? data.profileImage);
  return avatar;
}

function parsePathRef(path: string, query: Record<string, string | string[] | undefined>): LinkRef | null {
  const queryProfile = trimText(query.profile, 128);
  const queryReel = trimText(query.reel, 128);
  if (queryProfile) return { kind: 'profile', ref: normalizeUsername(queryProfile) };
  if (queryReel) return { kind: 'reel', ref: queryReel };

  const segments = path.split('/').filter(Boolean);
  if (segments.length >= 2 && segments[0] === 'u') {
    return { kind: 'profile', ref: normalizeUsername(decodeURIComponent(segments[1])) };
  }
  if (segments.length >= 2 && segments[0] === 'r') {
    return { kind: 'reel', ref: decodeURIComponent(segments[1]).trim() };
  }
  if (segments.length >= 2 && segments[0] === 'profile') {
    return { kind: 'profile', ref: normalizeUsername(decodeURIComponent(segments[1])) };
  }
  if (segments.length >= 2 && segments[0] === 'reel') {
    return { kind: 'reel', ref: decodeURIComponent(segments[1]).trim() };
  }
  if (segments.length === 1 && segments[0].startsWith('@')) {
    return { kind: 'profile', ref: normalizeUsername(decodeURIComponent(segments[0])) };
  }
  return null;
}

async function loadUserByRef(
  db: FirebaseFirestore.Firestore,
  ref: string,
): Promise<FirebaseFirestore.DocumentData | null> {
  const key = ref.trim();
  if (!key) return null;

  const byUsername = await db
    .collection('users')
    .where('username', '==', key)
    .limit(1)
    .get();
  if (!byUsername.empty) return byUsername.docs[0].data();

  const byUid = await db.collection('users').doc(key).get();
  if (byUid.exists) return byUid.data() ?? null;

  return null;
}

function profileOgFromUser(ref: string, data: FirebaseFirestore.DocumentData): OgPayload {
  const username = trimText(data.username, 64) || ref;
  const displayName = trimText(data.displayName, 80);
  const bio = trimText(data.bio, 180);
  const followers = typeof data.followersCount === 'number' ? data.followersCount : 0;
  const following = Array.isArray(data.following) ? data.following.length : 0;
  const image = absoluteHttpsUrl(data.profileImage) || DEFAULT_OG_IMAGE;
  const canonicalUrl = `https://${WEB_HOST}/u/${encodeURIComponent(username)}`;

  const title = displayName
    ? `${displayName} (@${username}) on Vyooo`
    : `@${username} on Vyooo`;

  const stats: string[] = [];
  stats.push(`${formatCount(followers)} Followers`);
  if (following > 0) stats.push(`${formatCount(following)} Following`);

  const description = bio || stats.join(' · ') || 'See photos and videos on Vyooo.';

  return {
    title,
    description,
    image,
    canonicalUrl,
    pageHeading: displayName ? displayName : `@${username}`,
    pageSubheading: displayName ? `@${username}` : stats.join(' · '),
    ogType: 'profile',
    appUrl: `vyooo://profile/${encodeURIComponent(username)}`,
  };
}

function reelOgFromDoc(reelId: string, data: FirebaseFirestore.DocumentData): OgPayload {
  const username = trimText(data.username, 64) || 'creator';
  const handle = trimText(data.handle, 64).replace(/^@/, '');
  const caption = trimText(data.caption ?? data.title ?? data.description, 220);
  const image = reelPreviewImage(data) || DEFAULT_OG_IMAGE;
  const canonicalUrl = `https://${WEB_HOST}/r/${encodeURIComponent(reelId)}`;

  const quotedCaption = caption ? `“${caption}”` : 'Watch this post on Vyooo';
  const title = `@${handle || username} on Vyooo: ${quotedCaption}`;
  const description = caption || `A post by @${handle || username} on Vyooo`;

  return {
    title,
    description,
    image,
    canonicalUrl,
    pageHeading: `@${handle || username}`,
    pageSubheading: caption || 'Watch on Vyooo',
    ogType: 'article',
    appUrl: `vyooo://reel/${encodeURIComponent(reelId)}`,
  };
}

function defaultOg(kind: LinkKind | null, ref: string): OgPayload {
  const isProfile = kind === 'profile';
  const canonicalUrl = isProfile && ref
    ? `https://${WEB_HOST}/u/${encodeURIComponent(ref)}`
    : !isProfile && ref
      ? `https://${WEB_HOST}/r/${encodeURIComponent(ref)}`
      : `https://${WEB_HOST}/`;

  return {
    title: isProfile ? 'Vyooo profile' : 'Vyooo post',
    description: isProfile
      ? 'See this profile on Vyooo.'
      : 'Watch this post on Vyooo.',
    image: DEFAULT_OG_IMAGE,
    canonicalUrl,
    pageHeading: 'Vyooo',
    pageSubheading: isProfile ? 'Open this profile in Vyooo' : 'Open this post in Vyooo',
    ogType: 'website',
    appUrl: isProfile && ref
      ? `vyooo://profile/${encodeURIComponent(ref)}`
      : !isProfile && ref
        ? `vyooo://reel/${encodeURIComponent(ref)}`
        : null,
  };
}

function renderHtml(payload: OgPayload): string {
  const title = escapeHtml(payload.title);
  const description = escapeHtml(payload.description);
  const image = escapeHtml(payload.image);
  const canonicalUrl = escapeHtml(payload.canonicalUrl);
  const pageHeading = escapeHtml(payload.pageHeading);
  const pageSubheading = escapeHtml(payload.pageSubheading);
  const ogType = escapeHtml(payload.ogType);
  const appUrl = payload.appUrl ? escapeHtml(payload.appUrl) : '';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${title}</title>
  <link rel="canonical" href="${canonicalUrl}" />
  <meta property="og:site_name" content="Vyooo" />
  <meta property="og:title" content="${title}" />
  <meta property="og:description" content="${description}" />
  <meta property="og:type" content="${ogType}" />
  <meta property="og:url" content="${canonicalUrl}" />
  <meta property="og:image" content="${image}" />
  <meta property="og:image:secure_url" content="${image}" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${title}" />
  <meta name="twitter:description" content="${description}" />
  <meta name="twitter:image" content="${image}" />
  <style>
    :root { color-scheme: dark; }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: "DM Sans", system-ui, -apple-system, sans-serif;
      background: radial-gradient(circle at top, #2a1038 0%, #120018 55%);
      color: #fff;
      padding: 24px;
    }
    .card {
      width: min(100%, 420px);
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 24px;
      padding: 24px;
      text-align: center;
      backdrop-filter: blur(12px);
    }
    .preview {
      width: 100%;
      aspect-ratio: 1;
      border-radius: 16px;
      object-fit: cover;
      background: rgba(255, 255, 255, 0.08);
      margin-bottom: 16px;
    }
    .avatar {
      width: 96px;
      height: 96px;
      border-radius: 50%;
      object-fit: cover;
      margin: 0 auto 16px;
      display: block;
      background: rgba(255, 255, 255, 0.08);
    }
    h1 {
      font-size: 22px;
      font-weight: 600;
      margin: 0 0 6px;
      line-height: 1.2;
    }
    .sub {
      opacity: 0.82;
      margin: 0 0 18px;
      font-size: 15px;
      line-height: 1.45;
      white-space: pre-wrap;
    }
    .status {
      opacity: 0.72;
      margin: 0 0 16px;
      font-size: 14px;
    }
    .btn {
      display: inline-block;
      background: #f81945;
      color: #fff;
      text-decoration: none;
      font-weight: 600;
      padding: 14px 28px;
      border-radius: 999px;
    }
    .muted {
      font-size: 13px;
      opacity: 0.6;
      margin-top: 16px;
      line-height: 1.4;
    }
    a { color: #f81945; }
  </style>
  <script>
    (function () {
      var ANDROID_STORE = ${JSON.stringify(ANDROID_STORE)};
      var IOS_STORE = ${JSON.stringify(IOS_STORE)};
      var appUrl = ${appUrl ? JSON.stringify(appUrl) : 'null'};
      var isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);
      var storeUrl = isIOS ? IOS_STORE : ANDROID_STORE;

      function ready() {
        var statusEl = document.getElementById("status");
        var btnEl = document.getElementById("store");
        btnEl.href = storeUrl;

        if (!appUrl) {
          statusEl.textContent = "Invalid link.";
          btnEl.textContent = "Get Vyooo";
          btnEl.style.display = "inline-block";
          return;
        }

        var now = Date.now();
        window.location.href = appUrl;
        setTimeout(function () {
          if (Date.now() - now < 2200) return;
          statusEl.textContent = "Don't have Vyooo yet?";
          btnEl.style.display = "inline-block";
        }, 1500);
      }

      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", ready);
      } else {
        ready();
      }
    })();
  </script>
</head>
<body>
  <div class="card">
    ${payload.ogType === 'profile'
      ? `<img class="avatar" src="${image}" alt="" />`
      : `<img class="preview" src="${image}" alt="" />`}
    <h1>${pageHeading}</h1>
    <p class="sub">${pageSubheading}</p>
    <p class="status" id="status">Opening Vyooo…</p>
    <a id="store" class="btn" href="#" style="display: none">Get Vyooo</a>
    <p class="muted">If the app didn't open, install Vyooo and tap the link again.</p>
  </div>
</body>
</html>`;
}

export const shareLink = onRequest(
  {
    region: 'us-central1',
    invoker: 'public',
    memory: '256MiB',
    timeoutSeconds: 15,
  },
  async (req, res) => {
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const path = (req.path || req.url || '/').split('?')[0];
    const parsed = parsePathRef(path, req.query as Record<string, string | string[] | undefined>);

    let payload = defaultOg(parsed?.kind ?? null, parsed?.ref ?? '');

    try {
      const db = admin.firestore();
      if (parsed?.kind === 'profile' && parsed.ref) {
        const user = await loadUserByRef(db, parsed.ref);
        if (user) payload = profileOgFromUser(parsed.ref, user);
      } else if (parsed?.kind === 'reel' && parsed.ref) {
        const reelDoc = await db.collection('reels').doc(parsed.ref).get();
        if (reelDoc.exists) payload = reelOgFromDoc(parsed.ref, reelDoc.data() ?? {});
      }
    } catch (err) {
      logger.warn('shareLink: preview lookup failed', {
        path,
        error: String(err),
      });
    }

    res.set('Content-Type', 'text/html; charset=utf-8');
    res.set('Cache-Control', 'public, max-age=300, s-maxage=600');
    if (req.method === 'HEAD') {
      res.status(200).end();
      return;
    }
    res.status(200).send(renderHtml(payload));
  },
);
