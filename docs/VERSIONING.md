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
| Build number | **34** |
| `pubspec.yaml` | `1.2.0+34` |

## Release history

| Marketing | Build | Date | Channels | Notes |
|-----------|-------|------|----------|--------|
| 1.2.0 | 34 | 2026-05-20 | Play Store, TestFlight / Xcode | Version gate, profile grid, TestFlight update URL |
| 1.1.9 | 33 | — | — | Previous shipped build |

## Before each store upload

1. Bump **`pubspec.yaml`**: increase **build** every upload; increase **marketing** when users should see a new x.y.z.
2. Run `flutter pub get` (regenerates iOS `Generated.xcconfig`).
3. Add a row to **Release history** above.
4. **Android:** build app bundle (`flutter build appbundle`) — version comes from pubspec.
5. **iOS:** Archive in Xcode — version/build come from pubspec via Flutter; confirm **Runner → General** shows 1.2.0 (34).

## After the build is live (version gate)

Firestore document: **`app_config` / `version_policy`** (see `firestore/app_config_version_policy.example.json`).

| Goal | Firestore change |
|------|------------------|
| Soft nudge | `latestVersion` → new marketing version (e.g. `1.2.0`), keep `minVersion` lower |
| Force update | `minVersion` → new marketing version (and/or `minBuildNumber` → new build) |
| Turn off | `enabled: false` |

**iOS update link:** `https://testflight.apple.com/join/NjQVQ2nD` (or App Store URL when on production).  
**Android update link:** `https://play.google.com/store/apps/details?id=com.vyooo`

## Next release checklist

- [ ] `pubspec.yaml` → e.g. `1.2.1+35` or `1.3.0+35`
- [ ] `docs/VERSIONING.md` history row
- [ ] Upload to Play Console / App Store Connect
- [ ] Update Firestore `latestVersion` (and `minVersion` when forcing old clients)
