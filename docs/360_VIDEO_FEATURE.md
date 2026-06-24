# 360° Video Feature — Developer Guide

This document describes how immersive 360° video is integrated in Vyooo: upload, metadata, Firestore storage, playback, and where it surfaces in the app.

**Branch:** `feature/360-video-integration`  
**Primary commit on `main`:** `2bdddad` — *Fix 360/VR playback and route immersive uploads to the VR tab.*

---

## Overview

Vyooo supports **equirectangular 360° video** with optional stereoscopic layouts (mono, top-bottom, side-by-side). The feature spans:

| Layer | Responsibility |
|-------|----------------|
| **Upload** | Auto-detect 360 from file metadata; user can toggle and configure stereo mode |
| **Storage** | Firestore reel fields + `isVR` flag for tab routing |
| **Playback** | Native spherical player (`video_360` package) with flat `VideoPlayer` fallback |
| **Discovery** | VR tab, profile VR grid, home/post feeds, full-screen VR detail |

360 posts are **not** shown on the profile **Posts** tab — they appear on the **VR** tab only (same as legacy `isVR` content).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Upload flow                               │
│  upload_details_screen → Video360Detector (FFprobe)              │
│       → Video360Metadata.sanitize() → Firestore reel doc         │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Firestore `reels` collection                 │
│  is360Video, projectionType, stereoMode, isVR                    │
└───────────────────────────────┬─────────────────────────────────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          ▼                     ▼                     ▼
   Home / Post feed      Profile VR grid         VR tab (vr_screen)
   (ReelItemWidget)      (VRDetailScreen)        (getReelsVR)
          │                     │                     │
          └─────────────────────┴─────────────────────┘
                                │
                                ▼
                    Vyooo360VideoPlayer
                    ├─ Video360View (native, iOS/Android)
                    └─ VideoPlayer (flat fallback)
```

---

## Key files

| File | Purpose |
|------|---------|
| `lib/core/models/video_360_metadata.dart` | Domain model, Firestore serialization, VR legacy compat |
| `lib/core/utils/video_360_detector.dart` | FFprobe-based auto-detection on local files |
| `lib/core/widgets/vyooo_360_video_player.dart` | Native 360 player + fallback + controls |
| `lib/core/utils/stream_playback_urls.dart` | MP4-first URL candidates for native players |
| `lib/screens/upload/upload_details_screen.dart` | Upload UI toggle + detection + persist |
| `lib/widgets/reel_item_widget.dart` | Routes 360 reels to `Vyooo360VideoPlayer` in feed |
| `lib/core/widgets/post_media_carousel.dart` | Passes `video360` into carousel video items |
| `lib/screens/content/vr_detail_screen.dart` | Full-screen immersive VR viewer |
| `lib/features/vr/vr_screen.dart` | VR tab feed (`getReelsVR`) |
| `lib/core/services/reels_service.dart` | VR reel queries + field mapping |
| `lib/core/widgets/profile/profile_grid_posts.dart` | Excludes 360/VR from Posts tab |
| `lib/core/widgets/profile/profile_reel_grid_navigation.dart` | Opens `VRDetailScreen` with metadata |
| `test/core/widgets/profile/profile_grid_posts_test.dart` | Unit test for Posts vs VR filtering |

**Removed (do not reintroduce):** `lib/core/widgets/sphere_360_panorama.dart` — old texture-capture approach replaced by native `video_360`.

---

## Firestore schema

Each reel document in the `reels` collection may include:

| Field | Type | Description |
|-------|------|-------------|
| `is360Video` | `bool` | `true` when uploaded as 360° content |
| `projectionType` | `string` | `"flat"` or `"equirectangular"` (only equirectangular enables 360 player) |
| `stereoMode` | `string` | `"mono"`, `"top_bottom"`, or `"side_by_side"` |
| `isVR` | `bool` | Set to `true` when `is360Video` is true at upload time; used for VR tab queries |

### Playback gate

360 native player is used only when:

```dart
is360Video == true && projectionType == 'equirectangular'
```

See `Video360Metadata.use360Player`.

### Legacy VR posts

Older documents may have `isVR: true` without `is360Video`. `Video360Metadata.forVrPlayback()` treats those as equirectangular 360 for playback in VR detail / VR tab.

### Sanitization on upload

`Video360Metadata.sanitize()` enforces:

- If `is360Video` is false → stores flat defaults (`is360Video: false`, `projectionType: flat`, `stereoMode: mono`).
- If `is360Video` is true but projection is not equirectangular → downgrades to flat.
- Valid 360 uploads always persist `projectionType: equirectangular`.

On upload, `isVR` is set equal to `is360Video` so new 360 content appears in the VR tab.

---

## Upload flow

**Screen:** `lib/screens/upload/upload_details_screen.dart`

1. User picks a **single video** asset (`_canConfigure360` requires one video, not multi-asset).
2. On init, `Video360Detector.detect()` runs against the local file.
3. UI shows a **“360 video”** switch plus optional projection/stereo chips when enabled.
4. On publish, metadata is sanitized and spread into the Firestore reel document:

```dart
final video360Meta = Video360Metadata.sanitize(
  is360Video: _canConfigure360 && _is360Video,
  projectionType: _projectionType.firestoreValue,
  stereoMode: _stereoMode.firestoreValue,
);
// ...
...video360Meta.toFirestore(),
'isVR': video360Meta.is360Video,
```

Video is uploaded to **Cloudflare Stream** via the existing direct-upload Cloud Function; playback URL is stored as `videoUrl` (HLS manifest). The 360 player resolves MP4 fallbacks from that URL (see below).

---

## Auto-detection (`Video360Detector`)

**Dependency:** `ffmpeg_kit_flutter_new` (FFprobe)

Detection order:

1. **High confidence** — Spherical tags in container metadata (`spherical`, `equirectangular`, `gspherical`, stereo hints).
2. **Medium confidence** — Aspect ratio heuristics:
   - ~2:1 → mono equirectangular
   - ~1:1 → top-bottom stereo
   - ~4:1 → side-by-side stereo
3. **None** — User can still manually enable 360.

Detection runs only for single-video uploads. Multi-asset or image uploads hide the 360 section.

---

## Playback (`Vyooo360VideoPlayer`)

**Dependency:** `video_360: ^0.0.11` (native `Video360View` on iOS/Android)

### URL resolution

`StreamPlaybackUrls.candidatesPreferMp4()` builds a candidate list from the stored `videoUrl`:

- Original URL (often HLS `.m3u8`)
- Derived MP4 from same host (`/downloads/default.mp4`)
- `videodelivery.net` HLS/MP4 fallbacks

MP4 is preferred because ExoPlayer / AVPlayer handle progressive download more reliably for the native 360 view than HLS.

Offline cache: `FeedOfflineVideoCache` may serve a local file path when available.

### Native path

- Uses `Video360View` with gyro + touch (when `enableGyro` / `enableTouch` are true).
- 12s startup watchdog; retries alternate URLs.
- On Android, retries with `useAndroidViewSurface: false` if surface mode fails.
- Integrates with `FeedVideoAudioController` for global mute (flat fallback only shows mute in controls pill; native path follows feed mute for volume where applicable).

### Fallback path

If native 360 is unsupported (web), metadata is flat, or all native attempts fail:

- Falls back to standard `VideoPlayer` with a banner: *“360 playback unavailable — showing flat view”*.
- User still gets play/pause and mute controls.

### Lifecycle

- Pauses when reel is not visible (`isVisible: false`) or app is backgrounded.
- Supports double-tap like overlay via `DoubleTapLikeOverlay`.
- Fires `onVideoPlaybackStarted` / `onVideoCompleted` for feed analytics hooks.

### Where the player is used

| Surface | Entry | Metadata source |
|---------|-------|-----------------|
| Home reels / post feed | `ReelItemWidget` | `Video360Metadata.fromPost(reel)` |
| Post carousel | `PostMediaCarousel` | Passed from parent post |
| VR detail (full screen) | `VRDetailScreen` | `Video360Metadata.forVrPlayback(item)` |
| Profile VR grid tap | `profile_reel_grid_navigation.dart` | Same as VR detail |

`ReelItemWidget` checks `widget.video360.use360Player` and delegates to `Vyooo360VideoPlayer` instead of initializing a flat `VideoPlayerController`.

---

## App surfaces & routing

### VR tab (`lib/features/vr/vr_screen.dart`)

- Loads reels via `ReelsService.getReelsVR()`.
- Query merges:
  - `isVR == true`
  - `is360Video == true` (catches docs that only have the new flag)
- Tapping opens `VRDetailScreen` with `Video360Metadata.forVrPlayback(reel)`.

### Profile grids

| Tab | Filter |
|-----|--------|
| **Posts** | `ProfileGridPosts.filterForPostsTab()` — excludes `isVR` and `is360Video` |
| **VR** | Reels where `belongsInVrTab()` is true |

Cache key for Posts grid includes `:posts-no-vr360` suffix to avoid stale mixed caches.

### Main feed

360 reels **can** appear in the home/post feed if they are in the feed query results. Playback uses the immersive player inline. Profile organization is what separates Posts vs VR tabs.

---

## Dependencies

```yaml
# pubspec.yaml
video_360: ^0.0.11
ffmpeg_kit_flutter_new: ^4.1.0   # upload-time detection only
video_player: ^2.8.2             # flat fallback
```

After `fvm flutter pub get`, run **`pod install`** in `ios/` when pulling this branch on a Mac.

**Platforms:** Native 360 works on **iOS and Android only**. Web and desktop use flat fallback or error state.

---

## Testing

### Unit tests

```bash
fvm flutter test test/core/widgets/profile/profile_grid_posts_test.dart
```

Verifies VR and 360 reels are excluded from the Posts tab filter.

### Manual QA checklist

- [ ] Upload a known 360 MP4 (equirectangular metadata) — detector auto-enables toggle.
- [ ] Upload with manual 360 toggle off/on; confirm Firestore fields.
- [ ] Confirm upload appears under profile **VR** tab, not **Posts**.
- [ ] Play in VR tab → full-screen detail; drag/gyro works.
- [ ] Play same reel in home feed if applicable — inline 360 player.
- [ ] Toggle global feed mute — audio behavior on flat fallback.
- [ ] Background app — playback pauses.
- [ ] Airplane mode with cached video — offline path if cache exists.
- [ ] Legacy `isVR`-only document still plays in VR detail.

### Sample Firestore document

```json
{
  "videoUrl": "https://customer-xxx.cloudflarestream.com/<id>/manifest/video.m3u8",
  "thumbnailUrl": "https://...",
  "is360Video": true,
  "projectionType": "equirectangular",
  "stereoMode": "mono",
  "isVR": true,
  "mediaType": "video"
}
```

---

## Known limitations & future work

| Item | Notes |
|------|-------|
| Stereoscopic VR headset mode | `panoramaCrop` exists on model for UV crop; separate L/R eye rendering is **TODO** in `video_360_metadata.dart` |
| Web | No native 360; flat fallback only |
| Multi-asset uploads | 360 configuration disabled |
| Projection types | Only equirectangular is supported in UI and player |
| HLS on native 360 | May fail; MP4 fallback is intentional |
| `sphere_360_panorama.dart` | Deleted — do not restore without product approval |

---

## Troubleshooting

| Symptom | Likely cause | What to check |
|---------|--------------|---------------|
| Flat video in feed despite 360 upload | `projectionType` not equirectangular or `is360Video` false | Firestore doc fields |
| “360 playback unavailable” banner | Native player failed all URL/surface retries | MP4 URL reachable; Android surface mode |
| Not in VR tab | `isVR` / `is360Video` missing | Upload sanitize path; re-save doc |
| Still on Posts tab | Old cache | Profile grid cache key; `filterForPostsTab` |
| Detection wrong | Aspect ratio guess only | Manual toggle on upload screen |
| iOS build issues | Pod drift | `cd ios && pod install` |

---

## Quick reference for new work

**Read metadata from a post map:**

```dart
final meta = Video360Metadata.fromPost(reel);
if (meta.use360Player) {
  // use Vyooo360VideoPlayer
}
```

**VR-specific playback (includes legacy `isVR`):**

```dart
final meta = Video360Metadata.forVrPlayback(reel);
```

**Check profile tab routing:**

```dart
ProfileGridPosts.belongsInVrTab(reel); // true → VR tab, not Posts
```

---

## Contact / history

- Integrated native `video_360` player replacing custom panorama texture approach (Jun 2026).
- Immersive uploads set `isVR: true` and are excluded from profile Posts grid.
- For environment setup, see `docs/DEVELOPER_SETUP.md` (FVM, Flutter 3.38.9).
