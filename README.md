# Vyooo

Flutter app (iOS + Android). Production bundle id: **`com.vyooo`**.

## Developer setup (required)

Every machine must use the **same Flutter SDK** via [FVM](https://fvm.app):

```bash
dart pub global activate fvm
git clone <repo-url> && cd Vyooo
./scripts/setup.sh
fvm flutter run
```

**Pinned:** Flutter **3.38.9** / Dart **3.10.8** (see `.fvmrc`).

Full toolchain (Java, Gradle, Android clean builds, iOS signing, Agora profile mode): **[docs/DEVELOPER_SETUP.md](docs/DEVELOPER_SETUP.md)**.

Store version bumps: **[docs/VERSIONING.md](docs/VERSIONING.md)**.
