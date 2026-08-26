#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlView* view;
  FlMethodChannel* gtk_application_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  // Single instance: a secondary launch only raises the existing window
  // instead of building a second one.
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows) {
    gtk_window_present(GTK_WINDOW(windows->data));
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "enjoy_player");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "enjoy_player");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Channel used by the `gtk` / `app_links` Dart packages: remote
  // command-line arguments (e.g. `enjoyplayer://auth/callback?...` from the
  // browser) are forwarded here so OAuth PKCE callbacks reach the running
  // instance.
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->view = view;
  self->gtk_application_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "gtk/application", FL_METHOD_CODEC(codec));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::command-line. Runs on the primary instance for
// every launch of the application (local or forwarded over D-Bus from a
// secondary instance). arguments[0] is the binary name, so skip it before
// forwarding — app_links treats the first entry as the deep-link URI.
static gint my_application_command_line(GApplication* application,
                                        GApplicationCommandLine* command_line) {
  MyApplication* self = MY_APPLICATION(application);
  gchar** arguments =
      g_application_command_line_get_arguments(command_line, nullptr);
  if (self->gtk_application_channel != nullptr && arguments != nullptr &&
      g_strv_length(arguments) > 1) {
    g_autoptr(FlValue) args = fl_value_new_list();
    for (gint i = 1; arguments[i] != nullptr; i++) {
      fl_value_append_take(args, fl_value_new_string(arguments[i]));
    }
    fl_method_channel_invoke_method(self->gtk_application_channel,
                                    "command-line", args, nullptr, nullptr,
                                    nullptr);
  }
  g_strfreev(arguments);
  return 0;
}

// Implements GApplication::open (D-Bus Open requests, e.g. from portals).
static void my_application_open(GApplication* application,
                                GFile** files,
                                gint n_files,
                                const gchar* hint) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->gtk_application_channel == nullptr || n_files <= 0 ||
      files == nullptr) {
    return;
  }
  FlValue* uris = fl_value_new_list();
  for (gint i = 0; i < n_files; i++) {
    g_autofree gchar* uri = g_file_get_uri(files[i]);
    fl_value_append_take(uris, fl_value_new_string(uri));
  }
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_take(args, fl_value_new_string("files"), uris);
  fl_value_set_take(args, fl_value_new_string("hint"),
                    fl_value_new_string(hint != nullptr ? hint : ""));
  fl_method_channel_invoke_method(self->gtk_application_channel, "open", args,
                                  nullptr, nullptr, nullptr);
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  // Let GApplication route the command line / open request: on the primary
  // instance it emits ::command-line (handled above), and a secondary
  // instance forwards its arguments to the primary over D-Bus and exits.
  return FALSE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->gtk_application_channel);
  self->view = nullptr;
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->open = my_application_open;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_HANDLES_COMMAND_LINE |
                                         G_APPLICATION_HANDLES_OPEN, nullptr));
}
