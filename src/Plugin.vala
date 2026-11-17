/*
 * sys-tray: status notifier (SNI / AppIndicator) host untuk Wingpanel 8.
 *
 * Peran plugin:
 *  1. Memiliki nama bus org.kde.StatusNotifierWatcher (pengganti xapp-sn-watcher
 *     yang di elementary OS 8 tidak berjalan).
 *  2. Menerima registrasi StatusNotifierItem dari aplikasi (Chrome, Telegram,
 *     nm-applet, Warp, dll), lalu membuat satu indikator Wingpanel per item.
 *  3. Membaca menu via com.canonical.dbusmenu dan menampilkannya di popover.
 */

namespace SysTray {
    public class Plugin : Object {
        private static Plugin? plugin = null;

        private GLib.DBusConnection connection;
        private Gee.HashMap<string, ItemIndicator> indicators;
        private uint8 started = 0;

        private Plugin () {
            indicators = new Gee.HashMap<string, ItemIndicator> ();
        }

        public static Plugin get_default () {
            if (plugin == null) {
                plugin = new Plugin ();
            }

            return plugin;
        }

        public void setup (GLib.DBusConnection connection) {
            if (started != 0) {
                return;
            }

            started = 1;
            this.connection = connection;

            // Plugin ini sendiri yang menggambar item, jadi plugin ini host-nya.
            var watcher = new Watcher (connection);

            try {
                connection.register_object (Watcher.OBJECT_PATH, watcher);
            } catch (Error e) {
                critical ("sys-tray: gagal mendaftarkan watcher: %s", e.message);

                return;
            }

            GLib.Bus.own_name_on_connection (
                connection,
                Watcher.BUS_NAME,
                GLib.BusNameOwnerFlags.NONE,
                on_name_acquired,
                on_name_lost
            );

            watcher.item_registered.connect (on_item_registered);
            watcher.item_unregistered.connect (on_item_unregistered);
        }

        private void on_name_acquired (GLib.DBusConnection conn, string name) {
            debug ("sys-tray: watcher aktif sebagai %s", name);
        }

        private void on_name_lost (GLib.DBusConnection conn, string name) {
            // Nama bus dipegang proses lain (mis. xapp-sn-watcher): item SNI
            // akan mendaftar ke pemegang nama itu, bukan ke plugin ini.
            critical ("sys-tray: gagal mengambil nama %s, aplikasi SNI tidak akan tampil", name);
        }

        private void on_item_registered (string bus_name, string object_path, string key) {
            if (indicators.has_key (key)) {
                return;
            }

            var indicator = new ItemIndicator (connection, bus_name, object_path, key);
            indicators[key] = indicator;

            Wingpanel.IndicatorManager.get_default ().register_indicator (indicator.register_identifier, indicator);
        }

        private void remove (string key) {
            var indicator = indicators[key];

            if (indicator == null) {
                return;
            }

            indicators.unset (key);

            // Indikator tidak dideregister ke Wingpanel: panel Wingpanel abort
            // kalau daftar indikatornya diubah (bug IndicatorBar.remove_indicator).
            // destroy() menyembunyikan widget dan melepas langganan sinyalnya.
            indicator.destroy ();
        }

        private void on_item_unregistered (string key) {
            remove (key);
        }
    }
}
