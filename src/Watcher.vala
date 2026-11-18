/*
 * SNI watcher: org.kde.StatusNotifierWatcher.
 *
 * Kontrak mengikuti implementasi asli (libayatana-appindicator3):
 *  - RegisterStatusNotifierItem(string service):
 *      service berupa object path -> bus name = pengirim pesan
 *      service berupa bus name    -> object path = /StatusNotifierItem
 *  - RegisterStatusNotifierHost(string service)
 *  - properti: ProtocolVersion (i), IsStatusNotifierHostRegistered (b),
 *    RegisteredStatusNotifierItems (as)
 *  - sinyal: StatusNotifierItemRegistered, StatusNotifierItemUnregistered,
 *    StatusNotifierHostRegistered
 *
 * Catatan: D-Bus Vala tidak membocorkan nama pengirim ke method, jadi filter
 * pesan dipakai untuk mencatat pengirim sebelum method dijalankan.
 */

namespace Baki {
    [DBus (name = "org.kde.StatusNotifierWatcher")]
    public class Watcher : Object {
        public const string BUS_NAME = "org.kde.StatusNotifierWatcher";
        public const string OBJECT_PATH = "/StatusNotifierWatcher";

        public signal void item_registered (string bus_name, string object_path, string key);
        public signal void item_unregistered (string key);

        public signal void status_notifier_item_registered (string service);
        public signal void status_notifier_item_unregistered (string service);
        public signal void status_notifier_host_registered ();

        private Gee.Map<string, uint> items = new Gee.HashMap<string, uint> ();
        private string pending_sender = "";
        private GLib.DBusConnection connection;

        public int protocol_version { get { return 0; } }

        public bool is_status_notifier_host_registered { get { return true; } }

        public string[] registered_status_notifier_items {
            owned get {
                var result = new string[items.size];
                var i = 0;

                foreach (var key in items.keys) {
                    result[i++] = key;
                }

                return result;
            }
        }

        public Watcher (GLib.DBusConnection connection) {
            this.connection = connection;

            connection.add_filter ((conn, message, incoming) => {
                if (incoming && message.get_member () == "RegisterStatusNotifierItem") {
                    pending_sender = message.get_sender () ?? "";
                }

                return message;
            });
        }

        public void register_status_notifier_item (string service) throws GLib.Error {
            // Bentuk path: bus name = pengirim. Bentuk bus name: path baku SNI.
            var is_path = service.has_prefix ("/");
            var bus_name = is_path ? pending_sender : service;
            var object_path = is_path ? service : "/StatusNotifierItem";
            var key = bus_name + object_path;

            if (items.has_key (key)) {
                return;
            }

            items[key] = GLib.Bus.watch_name_on_connection (
                connection,
                bus_name,
                GLib.BusNameWatcherFlags.NONE,
                null,
                on_owner_vanished
            );

            status_notifier_item_registered (key);
            item_registered (bus_name, object_path, key);

            debug ("baki: item terdaftar: %s", key);
        }

        public void register_status_notifier_host (string service) throws GLib.Error {
            status_notifier_host_registered ();
            debug ("baki: host terdaftar: %s", service);
        }

        // Aplikasi berhenti -> semua item dan indikatornya ikut dibuang.
        // Satu proses bisa punya lebih dari satu item (mis. nm-applet), jadi
        // semua key yang berawalan bus name itu dikumpulkan dulu; mengubah map
        // saat foreach bisa membuat iterasi baca indeks yang sudah hilang.
        private void on_owner_vanished (GLib.DBusConnection conn, string name) {
            var dead = new Gee.ArrayList<string> ();

            foreach (var key in items.keys) {
                if (key.has_prefix (name + "/")) {
                    dead.add (key);
                }
            }

            foreach (var key in dead) {
                GLib.Bus.unwatch_name (items[key]);
                items.unset (key);
                status_notifier_item_unregistered (key);
                item_unregistered (key);
            }
        }
    }
}
