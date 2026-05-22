# Vyooo release versioning

## Source of truth

Edit **`pubspec.yaml`** only for store builds:

```yaml
version: <marketing>+<build>
# Example: 1.2.0+34
```

| Part | Android | iOS | Force-update policy |
|------|---------|-----|---------------------|
| `1.2.0` | `versionName` | `CFBundleShortVersionString` | `minVersion` / `latestVersion` in Firestore |
| `34` | `versionCode` | `CFBundleVersion` | optional `minBuildNumber` in Firestore |

Flutter injects these into Android Gradle and iOS `Info.plist` (`FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`).  
`ios/Runner.xcodeproj` `MARKETING_VERSION` should stay aligned with the marketing version for Xcode UI.

## Current release (uploading now)

| Field | Value |
|-------|--------|
| Marketing version | **1.2.0** |
| Build number | **41** |
| `pubspec.yaml` | `1.2.0+41` |

## Release history

| Marketing | Build | Date | Channels | Notes |
|-----------|-------|------|----------|--------|
| 1.2.0 | 41 | 2026-05-22 | Play Store, TestFlight | Build-only bump (40 used on Play); profile grid + coming soon |
| 1.2.0 | 40 | 2026-05-22 | Play Store | (versionCode 40 already uploaded — use 41 for next AAB) |
| 1.2.0 | 39 | 2026-05-21 | Play Store | AD_ID permission for RevenueCat; Play Advertising ID declaration Yes |
| 1.2.0 | 38 | 2026-05-21 | Play Store | Android 15 edge-to-edge + large-screen/orientation Play Console fixes |
| 1.2.0 | 37 | 2026-05-21 | Play Store | (uploaded to Console — superseded by 38) |
| 1.2.0 | 36 | 2026-05-20 | Play Store | Repost to profile, post counter privacy, feed repost button |
| 1.2.0 | 35 | 2026-05-20 | Play Store | (rejected — versionCode 35 already used) |
| 1.2.0 | 34 | 2026-05-20 | Play Store, TestFlight / Xcode | Version gate, profile grid, TestFlight update URL |
| 1.1.9 | 33 | — | — | Previous shipped build |

## Before each store upload

1. Bump **`pubspec.yaml`**: increase **build only** (`+N`) every Play/App Store upload. **Do not** change marketing (`1.2.0`) unless the user explicitly asks for a new x.y.z.
2. Run `flutter pub get` (regenerates iOS `Generated.xcconfig`).
3. Add a row to **Release history** above.
4. **Android:** build app bundle (`flutter build appbundle`) — version comes from pubspec.
5. **iOS:** Archive in Xcode — version/build come from pubspec via Flutter; confirm **Runner → General** shows **1.2.0** and build **41** (or current `+N`). Upload new TestFlight builds under **Version 1.2.0** with a higher build number only. If **App Store production** rejects *train 1.2.0 is closed* or *CFBundleShortVersionString must be higher than 1.2.0*, bump marketing to `1.2.1` for that store submission only.

### iOS: Agora / FFmpeg “Upload Symbols Failed” (dSYM)

Third-party binaries (Agora RTC extensions, ffmpegkit) often ship **without** dSYM files. After a successful version bump, Organizer may list many *Upload Symbols Failed* lines for those frameworks. That is **usually a warning**, not a rejection — Vyooo and Flutter still symbolicate your app code via Firebase/Crashlytics. If upload is blocked, archive again with **1.2.1+41**; do not lower `DEBUG_INFORMATION_FORMAT` on the Runner target.

## After the build is live (version gate)

Firestore document: **`app_config` / `version_policy`** (see `firestore/app_config_version_policy.example.json`).

| Goal | Firestore change |
|------|------------------|
| Soft nudge | `latestVersion` → new marketing version (e.g. `1.2.0`), keep `minVersion` lower |
| Force update | `minVersion` → new marketing version (and/or `minBuildNumber` → new build) |
| Turn off | `enabled: false` |

**iOS update link:** `https://testflight.apple.com/join/NjQVQ2nD` (or App Store URL when on production).  
**Android update link:** `https://play.google.com/store/apps/details?id=com.vyooo`

## Team Flutter version (every machine)

Vyooo pins **Flutter 3.38.9** with FVM — not the same as store `1.2.0+36`, but both must match across developers.

| Check | Command |
|-------|---------|
| Install SDK | `fvm install` (from repo root) |
| Verify pin | `./scripts/verify_toolchain.sh` |
| Daily CLI | `fvm flutter run` / `fvm flutter build appbundle` |

Details: **[docs/DEVELOPER_SETUP.md](DEVELOPER_SETUP.md)**.

## Bump build number (script)

For the next Play / TestFlight upload without changing marketing version:

```bash
./scripts/bump_build.sh          # 1.2.0+36 → 1.2.0+37
./scripts/bump_build.sh --dry-run
fvm flutter pub get
```

Then update **Release history** below and upload.

## Play Console: production vs internal

| Track | Typical state | Action |
|-------|----------------|--------|
| **Production** | May lag (e.g. old `0.0.1` / build 11) | Promote tested build from internal/closed → production when ready |
| **Internal testing** | Newest (`1.2.0+36`) | QA here first |

Version codes must **always increase**; if Play rejects “version code already used”, run `./scripts/bump_build.sh` and upload again.

## Next release checklist

- [ ] `./scripts/bump_build.sh` or edit `pubspec.yaml` build (`+N` only unless marketing bump requested)
- [ ] `fvm flutter pub get`
- [ ] `docs/VERSIONING.md` history row
- [ ] Upload to Play Console / App Store Connect
- [ ] Update Firestore `latestVersion` / `minBuildNumber` (copy from `firestore/app_config_version_policy.example.json`)
