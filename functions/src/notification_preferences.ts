import * as admin from 'firebase-admin';

export const NOTIFICATION_PREFS_DOC_ID = 'notifications';
export const NOTIFICATION_PREFS_COLLECTION = 'settings';

export type NotificationPrefs = {
  pushEnabled: boolean;
  activity: boolean;
  postsFromFollowing: boolean;
  live: boolean;
  subscriptions: boolean;
  recommended: boolean;
};

const DEFAULT_PREFS: NotificationPrefs = {
  pushEnabled: true,
  activity: true,
  postsFromFollowing: true,
  live: true,
  subscriptions: false,
  recommended: false,
};

function readBool(value: unknown, fallback: boolean): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const t = value.trim().toLowerCase();
    if (t === 'true' || t === '1') return true;
    if (t === 'false' || t === '0') return false;
  }
  return fallback;
}

export function parseNotificationPrefs(
  data: admin.firestore.DocumentData | undefined,
): NotificationPrefs {
  if (!data) return { ...DEFAULT_PREFS };
  return {
    pushEnabled: readBool(data.pushEnabled, DEFAULT_PREFS.pushEnabled),
    activity: readBool(data.activity, DEFAULT_PREFS.activity),
    postsFromFollowing: readBool(
      data.postsFromFollowing,
      DEFAULT_PREFS.postsFromFollowing,
    ),
    live: readBool(data.live, DEFAULT_PREFS.live),
    subscriptions: readBool(data.subscriptions, DEFAULT_PREFS.subscriptions),
    recommended: readBool(data.recommended, DEFAULT_PREFS.recommended),
  };
}

export async function loadNotificationPrefs(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<NotificationPrefs> {
  if (!uid.trim()) return { ...DEFAULT_PREFS };
  const snap = await db
    .collection('users')
    .doc(uid.trim())
    .collection(NOTIFICATION_PREFS_COLLECTION)
    .doc(NOTIFICATION_PREFS_DOC_ID)
    .get();
  return parseNotificationPrefs(snap.data());
}

/** Returns false when push should be suppressed for this notification type. */
export function shouldSendPushForType(
  prefs: NotificationPrefs,
  rawType: string,
): boolean {
  if (!prefs.pushEnabled) return false;
  const type = rawType.trim().toLowerCase();
  if (!type) return prefs.activity;

  const activityTypes = new Set([
    'like',
    'comment',
    'share',
    'follow',
    'followrequest',
    'follow_request',
    'followrequestaccepted',
    'follow_request_accepted',
  ]);
  if (activityTypes.has(type)) return prefs.activity;

  if (type === 'subscribe' || type === 'subscription') {
    return prefs.subscriptions;
  }

  const postTypes = new Set(['post', 'new_post', 'newpost']);
  if (postTypes.has(type)) return prefs.postsFromFollowing;

  const liveTypes = new Set(['live', 'live_start', 'livestream', 'live_stream']);
  if (liveTypes.has(type)) return prefs.live;

  const recommendedTypes = new Set([
    'recommended',
    'recommended_content',
    'marketing',
  ]);
  if (recommendedTypes.has(type)) return prefs.recommended;

  return prefs.activity;
}
