/*
 * Satu StatusNotifierItem = satu indikator Wingpanel.
 *
 * Properti SNI yang dipakai:
 *  - IconName (nama ikon tema, atau path absolut ke PNG)
 *  - IconThemePath (direktori ikon tambahan)
 *  - Title / IconAccessibleDesc (tooltip kalau XAyatanaLabel kosong)
 *  - XAyatanaLabel / XAyatanaLabelGuide (label teks di sebelah ikon)
 *  - Status (Active/Passive -> tampil atau sembunyi)
 *  - Menu (object path com.canonical.dbusmenu)
 *  - AttentionIconName (ikon saat minta perhatian)
 */

namespace SysTray {
    public class ItemIndicator : Wingpanel.Indicator {
        private GLib.DBusConnection connection;
        private string bus_name;
        private string object_path;
        public string register_identifier { get; private set; }

        private Gtk.Image? image = null;
        private Gtk.Label? label = null;
        private Gtk.Box box;
        private Gtk.Box? popover_box = null;
        private DbusMenu? menu = null;

        private string icon_name = "";
        private string attention_icon_name = "";
        private string icon_theme_path = "";
        private string title = "";
        private string accessible_desc = "";
        private string x_label = "";
        private string status = "Active";

        public ItemIndicator (
            GLib.DBusConnection connection,
            string bus_name,
            string object_path,
            string key
        ) {
            Object (
                code_name: "ayatana-" + key,
                visible: true
            );

            this.connection = connection;
            this.bus_name = bus_name;
            this.object_path = object_path;
            this.register_identifier = "ayatana/" + bus_name + object_path;

            box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);

            watch_item_signals ();
            read_properties.begin ();
        }

        public override Gtk.Widget get_display_widget () {
            return box;
        }

        public override Gtk.Widget? get_widget () {
            if (popover_box == null) {
                popover_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                popover_box.width_request = 240;
                refresh_menu ();
            }

            return popover_box;
        }

        public override void opened () {
            if (menu != null) {
                menu.about_to_show ();
            }
        }

        public override void closed () {
        }

        public void destroy () {
            Wingpanel.IndicatorManager.get_default ().deregister_indicator (register_identifier, this);
        }

        private void watch_item_signals () {
            connection.signal_subscribe (
                bus_name,
                "org.kde.StatusNotifierItem",
                null,
                object_path,
                null,
                GLib.DBusSignalFlags.NONE,
                on_item_signal
            );
        }

        private void on_item_signal (
            GLib.DBusConnection conn,
            string? sender,
            string path,
            string iface,
            string member,
            GLib.Variant params
        ) {
            switch (member) {
                case "NewIcon":
                case "NewIconThemePath":
                case "NewAttentionIcon":
                case "NewStatus":
                case "NewTitle":
                case "XAyatanaNewLabel":
                    read_properties.begin ();
                    break;
            }
        }

        private async void read_properties () {
            var props = yield read_item_properties ();

            if (props == null) {
                return;
            }

            icon_name = get_string (props, "IconName");
            attention_icon_name = get_string (props, "AttentionIconName");
            icon_theme_path = get_string (props, "IconThemePath");
            title = get_string (props, "Title");
            accessible_desc = get_string (props, "IconAccessibleDesc");
            x_label = get_string (props, "XAyatanaLabel");
            status = get_string (props, "Status");

            update_display_widget ();

            var menu_path = get_string (props, "Menu");
            if (menu_path != "") {
                // Menu yang baru menggantikan yang lama.
                if (menu != null) {
                    menu.layout_changed.disconnect (refresh_menu);
                }

                menu = new DbusMenu (connection, bus_name, menu_path);
                menu.layout_changed.connect (refresh_menu);

                if (popover_box != null) {
                    refresh_menu ();
                }
            }
        }

        private void update_display_widget () {
            // Hanya item aktif yang ditampilkan, sama seperti perilaku Ubuntu.
            visible = status != "Passive";

            var current_icon = status == "NeedsAttention" && attention_icon_name != ""
                ? attention_icon_name
                : icon_name;

            if (current_icon != "") {
                if (image == null) {
                    image = new Gtk.Image ();
                    box.pack_start (image, false, false, 0);
                }

                set_icon (current_icon);
            } else if (image != null) {
                image.set_from_icon_name ("image-missing", Gtk.IconSize.MENU);
            }

            // Label teks (mis. "42" pada XAyatanaLabel) jadi elemen tersendiri.
            var show_label = x_label != "";

            if (show_label) {
                if (label == null) {
                    label = new Gtk.Label ("");
                    box.pack_start (label, false, false, 0);
                }

                label.set_text (x_label);
            }

            var tooltip = x_label != ""
                ? x_label
                : (title != "" ? title : accessible_desc);

            if (tooltip != "") {
                box.tooltip_text = tooltip;
            }

            box.show_all ();

            if (label != null) {
                label.visible = show_label;
            }
        }

        private void set_icon (string name) {
            if (image == null) {
                return;
            }

            // Beberapa aplikasi (mis. Electron/Flutter) mengirim path absolut.
            if (GLib.Path.is_absolute (name)) {
                try {
                    image.set_from_pixbuf (new Gdk.Pixbuf.from_file_at_scale (name, 22, 22, true));
                } catch (Error e) {
                    image.set_from_icon_name ("image-missing", Gtk.IconSize.MENU);
                }

                return;
            }

            if (icon_theme_path != "") {
                // Ikon aplikasi biasanya tidak ada di tema sistem.
                Gtk.IconTheme.get_default ().append_search_path (icon_theme_path);
                Gtk.IconTheme.get_default ().rescan_if_needed ();
            }

            image.set_from_icon_name (name, Gtk.IconSize.MENU);
        }

        private void refresh_menu () {
            if (popover_box == null || menu == null) {
                return;
            }

            // Isi popover diganti tiap kali layout dbusmenu berubah.
            // get_children() mengembalikan referensi lemah, jadi referensinya
            // ditahan dulu sebelum dihancurkan.
            var stale = new Gee.ArrayList<Gtk.Widget> ();

            foreach (var child in popover_box.get_children ()) {
                stale.add (child);
            }

            foreach (var child in stale) {
                child.destroy ();
            }

            var menu_widget = menu.build ();

            if (menu_widget == null) {
                return;
            }

            popover_box.add (menu_widget);
            popover_box.show_all ();

            // Popover Wingpanel bisa sudah terbuka sebelum menu selesai dibaca.
            var parent = popover_box.get_parent ();

            if (parent != null) {
                parent.show_all ();
            }
        }

        private async Gee.HashMap<string, GLib.Variant>? read_item_properties () {
            GLib.Variant reply = null;

            try {
                reply = yield connection.call (
                    bus_name,
                    object_path,
                    "org.freedesktop.DBus.Properties",
                    "GetAll",
                    new GLib.Variant ("(s)", "org.kde.StatusNotifierItem"),
                    new GLib.VariantType ("(a{sv})"),
                    GLib.DBusCallFlags.NONE,
                    3000
                );
            } catch (Error e) {
                warning ("sys-tray: gagal membaca properti %s: %s", object_path, e.message);

                return null;
            }

            if (reply == null) {
                return null;
            }

            var result = new Gee.HashMap<string, GLib.Variant> ();
            var dict = reply.get_child_value (0);

            for (var i = 0; i < dict.n_children (); i++) {
                var entry = dict.get_child_value (i);
                var value = entry.get_child_value (1);
                result[entry.get_child_value (0).get_string ()] = value.is_of_type (GLib.VariantType.VARIANT)
                    ? value.get_variant ()
                    : value;
            }

            return result;
        }

        private static string get_string (Gee.HashMap<string, GLib.Variant> props, string key) {
            var value = props[key];

            if (value == null) {
                return "";
            }

            // Menu bertipe object path ('o'), sisanya string.
            if (value.is_of_type (GLib.VariantType.STRING) || value.is_of_type (GLib.VariantType.OBJECT_PATH)) {
                return value.get_string ();
            }

            return "";
        }
    }
}
