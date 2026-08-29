# Changelog

## 3.0.2+enjoy.1

Vendored copy of upstream `flutter_secure_storage_linux` **3.0.2** with the
fixes below; drop this package and the `dependency_overrides` entry once an
upstream release ships both (upstream master still has them as of 3.0.2).
The only file modified versus upstream 3.0.2 is
`linux/include/Secret.hpp`; `resolution: workspace` was removed from
`pubspec.yaml` because it only applies inside upstream's melos workspace.

### Fixed: garbage `xdg:schema` attribute breaks session persistence

`SecretStorage`'s constructor built the libsecret schema from
`label.c_str()` while the label still held the short default (`"default"`),
so `the_schema.name` pointed into the `std::string`'s SSO buffer. The later
`setLabel(<application id>/FlutterSecureStorage)` call — issued from
`register_with_registrar` on every startup — moves the string to the heap
whenever the label exceeds 15 characters, and libstdc++ overwrites the old
SSO bytes with the string's capacity. Every subsequent store/lookup then
used that capacity byte as the schema name (e.g. `"1"` for a 49-char label),
so items were written with a garbage `xdg:schema` attribute:

- items could not be found again on the next cold start (sign-in silently
  lost on restart),
- re-stores never matched the existing item, so gnome-keyring received
  repeated colliding creates ("asked to register item … but it's already
  registered").

The schema name is now the static-storage string literal `"default"`, which
also matches what short-application-id installs were already storing, so no
migration is needed for them. Items previously written with a garbage schema
attribute are unreadable by any version and must be removed once (e.g. with
`secret-tool clear account <application id>.secureStorage`).

### Fixed: silently-empty item secret destroys the stored session

Under a burst of stores, gnome-keyring can report a successful
`SecretPasswordStore` while leaving the item's secret **empty** (daemon logs
"asked to register item … but it's already registered" at the same moment).
Every subsequent lookup then returns a non-NULL empty string, which the
plugin misread as "no data". Because all keys live in that single JSON blob,
the next read-modify-write rebuilt the blob from the phantom-empty state and
wiped the tokens that were actually written seconds earlier — observed as a
login that the server accepted, followed by an immediate silent sign-out.

The plugin now:

- treats a non-NULL **empty** lookup result as a failed secret transfer
  (never a legitimate state — the blob is always a JSON object, at minimum
  `{}`) and retries the lookup ~8×/25 ms before throwing
  `LibsecretError(code: "KeyringSecretEmpty")` instead of handing callers a
  phantom-empty blob;
- verifies every store by reading the secret back and retries the store
  (3 attempts) when it did not land;
- lets `addItem` rebuild from an empty base when the existing item is
  persistently poisoned, healing the item instead of blocking writes
  (app-level serialization in `enjoy_player` guarantees no concurrent
  operation is reading the blob meanwhile).
