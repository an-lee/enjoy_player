# flutter_secure_storage_linux

This is the platform-specific implementation of `flutter_secure_storage` for Linux.

## Features

- Secure storage using `libsecret` library.
- Compatible with various Linux keyring services like GNOME Keyring and KDE KWallet.

## Installation

Install [libsecret](https://github.com/GNOME/libsecret) — both the development package (to build) and the runtime package (to run). The runtime package (`libsecret-1-0`) is typically pre-installed on most Linux desktops.

<details>
<summary>apt / dnf / pacman</summary>

Ubuntu / Debian-based (Linux Mint, Pop!_OS, …):

```shell
sudo apt install libsecret-1-0 libsecret-1-dev
```

Fedora / RHEL / CentOS:

```shell
sudo dnf install libsecret libsecret-devel
```

Arch-based (single package contains both):

```shell
sudo pacman -S libsecret
```

</details>

<details>
<summary>Flatpak / Flathub</summary>

libsecret is included in Freedesktop runtime 25.08+ (also GNOME runtime 49, KDE runtime 6.10 and 5.15-25.08), so no extra manifest entry is needed:

```yaml
runtime: org.freedesktop.Platform
runtime-version: '25.08' # must be 25.08 or newer
```

For older runtimes, use [Flathub Shared Modules](https://docs.flathub.org/docs/for-app-authors/shared-modules) (`shared-modules/libsecret/libsecret.json`), though this is no longer recommended.

</details>

<details>
<summary>Snapcraft</summary>

```yaml
parts:
  your-app:
    plugin: flutter
    flutter-target: lib/main.dart
    build-packages:
      - libsecret-1-dev
    stage-packages:
      - libsecret-1-0
```

</details>

> **Note:** `libjsoncpp-dev` is no longer required. The plugin uses a bundled header-only JSON library.

## Configuration

Apart from libsecret, a running keyring service is required at runtime. This is typically already provided by the desktop environment:

- **GNOME / Ubuntu:** [`gnome-keyring`](https://wiki.gnome.org/Projects/GnomeKeyring) — usually active by default in a GNOME session.
- **KDE:** [`kwallet`](https://wiki.archlinux.org/title/KDE_Wallet) — enabled via KDE Wallet Manager.
- **Other / lightweight:** [`secret-service`](https://github.com/yousefvand/secret-service)
- **Headless / CI:** start `gnome-keyring-daemon` with an unlocked keyring:
  ```bash
  eval $(dbus-launch --sh-syntax)
  echo "" | gnome-keyring-daemon --unlock --daemonize --components=secrets
  ```

## Known issues

### Flutter installed via snap on Ubuntu 22.04+

Building with the Flutter snap may produce linker errors like:

```
undefined reference to `g_task_set_static_name'
undefined reference to `g_once_init_enter_pointer'
```

This is caused by a version mismatch between the GLib bundled in the Flutter snap and the system `libsecret`, which is compiled against a newer GLib. The plugin shared library links fine, but executables (including native test binaries) may fail to link.

**Workaround:** install Flutter via the [official tar archive](https://docs.flutter.dev/get-started/install/linux) instead of snap, so the toolchain uses the system linker and libraries consistently.

## Running the tests

### Native tests (C++ / GoogleTest)

The native tests exercise the `SecretStorage` layer directly against a real keyring. Build the example app first to compile the test binary, then run via CTest:

```bash
# 1. Start a keyring daemon (skip if already running in a desktop session)
eval $(dbus-launch --sh-syntax)
echo "" | gnome-keyring-daemon --unlock --daemonize --components=secrets

# 2. Build (compiles the test binary alongside the app)
cd flutter_secure_storage/example
flutter build linux --debug

# 3. Run
cd build/linux/x64/debug/plugins/flutter_secure_storage_linux
ctest --output-on-failure
```

### Integration tests

```bash
cd flutter_secure_storage/example
xvfb-run flutter test integration_test/linux_test.dart -d linux
```

## Usage

Refer to the main [flutter_secure_storage README](../README.md) for common usage instructions.

## License

This project is licensed under the BSD 3 License. See the [LICENSE](../LICENSE) file for details.
