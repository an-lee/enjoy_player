#include "FHashTable.hpp"
#include "json.hpp"
#include <libsecret/secret.h>
#include <memory>
#include <stdexcept>
#include <string>

#define secret_autofree _GLIB_CLEANUP(secret_cleanup_free)
static inline void secret_cleanup_free(gchar **p) { secret_password_free(*p); }

class LibsecretError : public std::runtime_error {
  std::string error_code;

  static const char *codeFromGError(const GError *error) {
    if (error == nullptr) {
      return "Libsecret error";
    }

    if (g_error_matches(error, SECRET_ERROR, SECRET_ERROR_IS_LOCKED)) {
      return "KeyringLocked";
    }

    if (g_error_matches(error, SECRET_ERROR, SECRET_ERROR_NO_SUCH_OBJECT)) {
      return "SecretNotFound";
    }

    return "Libsecret error";
  }

  static std::string messageWithContext(const char *context,
                                        const char *message) {
    if (message == nullptr) {
      return context == nullptr ? "Libsecret error" : context;
    }

    if (context == nullptr || context[0] == '\0') {
      return message;
    }

    std::string result(context);
    result += ": ";
    result += message;
    return result;
  }

public:
  explicit LibsecretError(const char *message)
      : LibsecretError("Libsecret error", message) {}

  LibsecretError(const char *code, const char *message)
      : std::runtime_error(
            message == nullptr
                ? (code == nullptr ? "Libsecret error" : code)
                : message),
        error_code(code == nullptr ? "Libsecret error" : code) {}

  LibsecretError(const char *context, const GError *error)
      : std::runtime_error(messageWithContext(
            context, error == nullptr ? nullptr : error->message)),
        error_code(codeFromGError(error)) {}

  const char *code() const { return error_code.c_str(); }
};

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
    // Still present in upstream 3.0.2.
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
    nlohmann::json root = nlohmann::json::object();
    try {
      root = readFromKeyring();
    } catch (const LibsecretError &e) {
      // A persistently poisoned item (exists, empty secret) must not block
      // writes: its contents are unrecoverable either way, so rebuild the
      // blob from scratch — the verified store below heals the item.
      // Note this only triggers after readFromKeyring has already retried
      // through the transient window, and Dart-side serialization guarantees
      // no other operation is touching the blob meanwhile.
      if (strcmp(e.code(), "KeyringSecretEmpty") != 0) {
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
    nlohmann::json root = readFromKeyring();
    if (!root.is_object() || !root.contains(key)) {
      return;
    }
    root.erase(key);
    storeToKeyring(root);
  }

  bool deleteKeyring() {
    if (!warmupKeyring()) {
      return true;
    }
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
        throw LibsecretError("secret_password_storev_sync", err);
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
        throw LibsecretError(
            "KeyringSecretEmpty",
            "secret_password_storev_sync left the item's secret empty");
      }
      g_usleep(30000); // 30ms
    }
  }

  nlohmann::json readFromKeyring() {
    nlohmann::json value = nlohmann::json::object();
    g_autoptr(GError) err = nullptr;

    if (!warmupKeyring()) {
      return value;
    }

    // A non-NULL but EMPTY lookup result means the item exists with an empty
    // secret — a failed secret transfer, never a legitimate state for this
    // plugin (the blob is always a JSON object, at minimum "{}"). Retrying a
    // few times rides out the transient window; if it persists, throw rather
    // than hand callers a phantom-empty blob whose read-modify-write would
    // wipe the keys that are actually stored.
    for (int attempt = 0;; attempt++) {
      secret_autofree gchar *result = secret_password_lookupv_sync(
          &the_schema, m_attributes.getGHashTable(), nullptr, &err);

      if (err) {
        throw LibsecretError("secret_password_lookupv_sync", err);
      }
      if (result != NULL && strcmp(result, "") != 0) {
        value = nlohmann::json::parse(result);
        return value;
      }
      if (attempt >= 8) {
        throw LibsecretError(
            "KeyringSecretEmpty",
            "secret_password_lookupv_sync keeps returning an empty secret");
      }
      g_usleep(25000); // 25ms
    }
  }

private:
  // Ensures the default keyring is accessible and distinguishes a locked
  // collection from other storage errors. A missing default collection is
  // the normal state of a fresh profile, not a locked keyring. Do not load
  // all collections here: some Secret Service backends fail when an
  // unrelated stale item exists in another collection.
  bool warmupKeyring() {
    g_autoptr(GError) err = nullptr;

    SecretService *service = secret_service_get_sync(
        SECRET_SERVICE_OPEN_SESSION, nullptr, &err);

    if (!service) {
      throw LibsecretError("secret_service_get_sync", err);
    }

    SecretCollection *collection = secret_collection_for_alias_sync(
        service, SECRET_COLLECTION_DEFAULT, SECRET_COLLECTION_NONE, nullptr, &err);

    if (!collection) {
      const bool missingDefaultCollection = err == nullptr;
      if (missingDefaultCollection) {
        g_autoptr(GError) searchError = nullptr;
        GList *matchingItems = secret_service_search_sync(
            service, &the_schema, m_attributes.getGHashTable(),
            SECRET_SEARCH_NONE, nullptr, &searchError);
        const bool hasMatchingItems = matchingItems != nullptr;
        if (matchingItems) {
          g_list_free_full(matchingItems, g_object_unref);
        }
        g_object_unref(service);

        // With no alias and no matching item this is a fresh profile. If data
        // exists elsewhere, fail closed before a write can create a second
        // default collection and orphan the original item.
        if (searchError) {
          throw LibsecretError("secret_service_search_sync", searchError);
        }
        if (hasMatchingItems) {
          throw LibsecretError("KeyringLocked", "KeyringLocked");
        }
        return false;
      }
      g_object_unref(service);
      throw LibsecretError("secret_collection_for_alias_sync", err);
    }

    if (!secret_collection_get_locked(collection)) {
      g_object_unref(collection);
      g_object_unref(service);
      return true;
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
      throw LibsecretError("KeyringLocked", "KeyringLocked");
    }

    return true;
  }
};
