# Vyooo — developer environment setup

Use the same **Flutter**, **Dart packages**, and **Android toolchain** on every machine so builds match CI and store releases.

## Required toolchain (source of truth)

| Tool | Version | Notes |
|------|---------|--------|
| **Flutter** | **3.38.9** (stable) | Pinned via [FVM](https://fvm.app) — see `.fvmrc` |
| **Dart** | **3.10.8** (bundled with Flutter) | Do not install Dart separately |
| **Java (Gradle)** | **17** recommended | Android Studio → Settings → Build → Gradle → Gradle JDK. JDK 21 often works with current AGP but 17 avoids “unsupported class file” mismatches |
| **Gradle** | **8.14** | Pinned in `android/gradle/wrapper/gradle-wrapper.properties` |
| **Android compileSdk** | **36** | `android/app/build.gradle.kts` |
| **iOS bundle id** | **`com.vyooo`** | Do not change — see `.cursor/rules/ios-bundle-id.mdc` |

After cloning, always use **`fvm flutter`** (or the VS Code/Cursor configs in `.vscode/`), not a random global `flutter` on PATH.

## First-time setup

### 1. Install FVM

```bash
dart pub global activate fvm
```

Ensure `~/.pub-cache/bin` is on your `PATH` (or use `fvm` from Homebrew).

### 2. Clone and install the project Flutter SDK

```bash
git clone <repo-url>
cd Vyooo
fvm install          # reads .fvmrc → installs 3.38.9 if missing
fvm flutter pub get
```

Or run the helper script:

```bash
./scripts/setup.sh
```

### 3. IDE (Cursor / VS Code)

Open the repo root. `.vscode/settings.json` points `dart.flutterSdkPath` at `.fvm/flutter_sdk`.

Reload the window after `fvm install` if analysis shows the wrong SDK.

### 4. Android

- Install Android SDK **36** and build-tools via Android Studio SDK Manager.
- Accept licenses: `fvm flutter doctor --android-licenses`
- Physical devices: project builds **ARM only** (`armeabi-v7a`, `arm64-v8a`). x86 emulators are not supported unless you change `abiFilters` in `android/app/build.gradle.kts`.
- If CMake/Gradle fails after an interrupted build:

```bash
fvm flutter clean
rm -rf build android/.gradle android/app/build
fvm flutter pub get
```

Run **only one** `fvm flutter run` / Gradle build at a time (avoids “startup lock” and corrupted `.cxx` caches).

### 5. iOS (Mac only)

```bash
cd ios && pod install && cd ..
```

- **Physical iPhone + Agora:** use **Profile** or **Release**, not Debug — see `.cursor/rules/ios-device-debug.mdc` and launch config **“Vyooo (profile — physical iPhone / Agora)”**.
- Signing: Apple ID must be on the team that owns **`com.vyooo`**.

## Daily commands

| Task | Command |
|------|---------|
| Dependencies | `fvm flutter pub get` |
| Run (phone) | `fvm flutter run` |
| Run (iPhone + live) | `fvm flutter run --profile` |
| Analyze | `fvm flutter analyze` |
| Doctor | `fvm flutter doctor -v` |

## Package versions

- **`pubspec.lock` is committed** — do not delete it. Everyone gets the same dependency tree after `fvm flutter pub get`.
- Do not run `flutter pub upgrade` unless intentionally bumping dependencies.

## Verify you match the team

```bash
fvm flutter --version   # must show Flutter 3.38.9, Dart 3.10.8
fvm flutter doctor -v
```

Compare output with a teammate if builds diverge.

## Changing the pinned Flutter version

1. Update `.fvmrc` (and run `fvm install` / `fvm use <version>`).
2. Run `fvm flutter pub get` and test Android + iOS.
3. Update this doc and commit `.fvmrc` + `.fvm/fvm_config.json` + `.fvm/version` + `.fvm/release`.

## App store version (1.2.0+36)

Separate from the Flutter SDK pin above:

| What | Where |
|------|--------|
| Marketing + build | `pubspec.yaml` → `version: 1.2.0+36` |
| Next upload bump | `./scripts/bump_build.sh` then `fvm flutter pub get` |
| Remote force/soft update | Firestore `app_config/version_policy` |
| Full process | **`docs/VERSIONING.md`** |

Verify toolchain before a release build:

```bash
./scripts/verify_toolchain.sh
```
