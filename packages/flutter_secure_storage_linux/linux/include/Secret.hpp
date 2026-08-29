#include "FHashTable.hpp"
#include "json.hpp"
#include <libsecret/secret.h>
#include <memory>
#include <cstring>

#define secret_autofree _GLIB_CLEANUP(secret_cleanup_free)
static inline void secret_cleanup_free(gchar **p) { secret_password_free(*p); }

class SecretStorage {
  FHashTable m_attributes;
  std::string label;
  SecretSchema the_schema;

public:
  const char *getLabel() { return label.c_str(); }
  void setLabel(const char *label) { this->label = label; }

  SecretStorage(const char *_label = "default") : label(_label) {
    // The schema name MUST NOT be `label.c_str()`. The plugin's static
    // SecretStorage is constructed with the short default label, so
    // `label.c_str()` points into the std::string's SSO buffer; the later
    // `setLabel(<application id>)` call then moves the string to the heap,
    // and libstdc++ overwrites the old SSO bytes with the string's capacity.
    // `the_schema.name` is read at every store/lookup afterwards and sees
    // that capacity byte as a 1-char "schema name" (e.g. "1" for a 49-char
    // `ai.enjoy.player.enjoy_player/FlutterSecureStorage` label), so items
    // are stored with a garbage `xdg:schema` attribute while lookups match
    // the same garbage within one process — but nothing survives a restart
    // cleanly and concurrent writers collide on the unfindable item
    // (gnome-keyring: "asked to register item … but it's already registered").
    // A string literal has static storage, so the name stays valid forever.
    the_schema = {"default",
                  SECRET_SCHEMA_NONE,
                  {
                      {"account", SECRET_SCHEMA_ATTRIBUTE_STRING},
                  }};
  }

  void addAttribute(const char *key, const char *value) {
    m_attributes.insert(key, value);
  }

  bool addItem(const char *key, const char *value) {
    nlohmann::json root;
    try {
      root = readFromKeyring();
    } catch (const gchar *e) {
      // A persistently poisoned item (exists, empty secret) must not block
      // writes: its contents are unrecoverable either way, so rebuild the
      // blob from scratch — the store below heals the item.
      if (strcmp(e, "KeyringSecretEmpty") != 0) {
        throw;
      }
    }
    root[key] = value;
    return storeToKeyring(root);
  }

  std::string getItem(const char *key) {
    std::string result;
    nlohmann::json root = readFromKeyring();
    nlohmann::json value = root[key];
    if(value.is_string()){
      result = value.get<std::string>();
      return result;
    }
    return "";
  }

  void deleteItem(const char *key) {
    try {
      nlohmann::json root = readFromKeyring();
      if (root.is_null()) {
          return;
      }
      root.erase(key);
      storeToKeyring(root);
    } catch (const gchar *e) {
      // Deleted-but-unreadable items leave nothing to preserve; swallowing
      // here matches the original std::exception handling below.
      return;
    } catch (const std::exception& e) {
        return;
    }
  }

  bool deleteKeyring() {
    warmupKeyring();
    return this->storeToKeyring(nlohmann::json::object());
  }

  bool storeToKeyring(nlohmann::json value) {
    const std::string output = value.dump();
    for (int attempt = 0;; attempt++) {
      g_autoptr(GError) err = nullptr;
      bool result = secret_password_storev_sync(
          &the_schema, m_attributes.getGHashTable(), nullptr, label.c_str(),
          output.c_str(), nullptr, &err);

      if (err) {
        gchar *msg = g_strdup(err->message);
        throw msg;
      }

      // gnome-keyring can report a successful store while leaving the item's
      // secret EMPTY (observed together with daemon logs "asked to register
      // item … but it's already registered"): the next lookup returns a
      // non-NULL empty string. Verify the secret landed and retry a couple
      // of times before giving up.
      gchar *check = secret_password_lookupv_sync(
          &the_schema, m_attributes.getGHashTable(), nullptr, nullptr);
      const bool landed = check != NULL && strcmp(check, "") != 0;
      secret_password_free(check);
      if (landed) {
        return result;
      }
      if (attempt >= 2) {
        throw g_strdup("KeyringSecretEmpty");
      }
      g_usleep(30000); // 30ms
    }
  }

  nlohmann::json readFromKeyring() {
    nlohmann::json value;
    GError *err = nullptr;

    warmupKeyring();

    // A non-NULL but EMPTY lookup result means the item exists with an empty
    // secret — a failed secret transfer, never a legitimate state for this
    // plugin (the blob is always a JSON object, at minimum "{}"). Retrying a
    // few times rides out the transient window; if it persists, throw rather
    // than hand callers a phantom-empty blob whose read-modify-write would
    // wipe the keys that are actually stored.
    for (int attempt = 0;; attempt++) {
      gchar *result = secret_password_lookupv_sync(
          &the_schema, m_attributes.getGHashTable(), nullptr, &err);

      if (err) {
        gchar *msg = g_strdup(err->message);
        g_error_free(err);
        secret_password_free(result);
        throw msg;
      }

      if (result == NULL) {
        break; // no item at all: legitimate cold state
      }
      const bool empty = strcmp(result, "") == 0;
      if (!empty) {
        value = nlohmann::json::parse(result);
      }
      secret_password_free(result);
      if (!empty) {
        break;
      }
      if (attempt >= 8) {
        throw g_strdup("KeyringSecretEmpty");
      }
      g_usleep(25000); // 25ms
    }
    return value;
  }

private:
  // Ensures the default keyring is accessible. Uses the libsecret service API
  // to detect a locked keyring and throw a distinct "KeyringLocked" sentinel so
  // callers can surface the right error code to Dart.
  // Loading all collections also resolves cold-keyring lookup failures:
  // https://gitlab.gnome.org/GNOME/gnome-keyring/-/issues/89
  void warmupKeyring() {
    g_autoptr(GError) err = nullptr;

    SecretService *service = secret_service_get_sync(
        static_cast<SecretServiceFlags>(SECRET_SERVICE_OPEN_SESSION | SECRET_SERVICE_LOAD_COLLECTIONS),
        nullptr, &err);

    if (!service) {
      throw g_strdup("KeyringLocked");
    }

    SecretCollection *collection = secret_collection_for_alias_sync(
        service, SECRET_COLLECTION_DEFAULT, SECRET_COLLECTION_NONE, nullptr, &err);

    if (!collection) {
      g_object_unref(service);
      throw g_strdup("KeyringLocked");
    }

    if (!secret_collection_get_locked(collection)) {
      g_object_unref(collection);
      g_object_unref(service);
      return;
    }

    GList *to_unlock = g_list_append(nullptr, collection);
    GList *unlocked_out = nullptr;
    gint n = secret_service_unlock_sync(service, to_unlock, nullptr, &unlocked_out, nullptr);
    g_list_free(to_unlock);
    if (unlocked_out) {
      g_list_free_full(unlocked_out, g_object_unref);
    }
    g_object_unref(collection);
    g_object_unref(service);

    if (n == 0) {
      throw g_strdup("KeyringLocked");
    }
  }
};
