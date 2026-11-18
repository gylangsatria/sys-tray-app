/*
 * Klien minimal com.canonical.dbusmenu.
 *
 * Tidak ada vapi/typelib dbusmenu di elementary OS 8, jadi protokolnya diakses
 * langsung:
 *   GetLayout(0, -1, []) -> (u (ia{sv}av))
 *   Event(id, "clicked", v, u)
 *   AboutToShow(id) -> (b)
 *   sinyal LayoutUpdated(u revision, i parent)
 *
 * Properti item yang didukung: label, enabled, visible, type
 * (standard/separator), toggle-type + toggle-state (checkbox), icon-name,
 * children-display ("submenu").
 *
 * Isi popover dibangun sebagai Gtk.Box, bukan Gtk.Menu, supaya konsisten
 * dengan indikator Wingpanel lain (Gtk.Menu diperuntukkan sebagai menu popup).
 */

namespace Baki {
    public class DbusMenu : Object {
        public signal void layout_changed ();

        private class Node : Object {
            public int32 id = 0;
            public string label = "";
            public string icon_name = "";
            public string toggle_type = "";
            public string children_display = "";
            public string type = "standard";
            public int32 toggle_state = -1;
            public bool enabled = true;
            public bool visible = true;
            public Gee.ArrayList<Node> children = new Gee.ArrayList<Node> ();
        }

        private GLib.DBusConnection connection;
        private string bus_name;
        private string object_path;
        private Node? root = null;
        private uint8 refreshing = 0;
        private uint8 refresh_again = 0;
        private uint subscription = 0;

        public DbusMenu (GLib.DBusConnection connection, string bus_name, string object_path) {
            this.connection = connection;
            this.bus_name = bus_name;
            this.object_path = object_path;

            subscription = connection.signal_subscribe (
                bus_name,
                "com.canonical.dbusmenu",
                "LayoutUpdated",
                object_path,
                null,
                GLib.DBusSignalFlags.NONE,
                member_changed
            );

            refresh ();
        }

        /** Dipanggil saat item pemilik menu berhenti. */
        public void stop () {
            connection.signal_unsubscribe (subscription);
        }

        private void member_changed (
            GLib.DBusConnection conn,
            string? sender,
            string path,
            string iface,
            string member,
            GLib.Variant params
        ) {
            refresh ();
        }

        public void refresh () {
            if (refreshing != 0) {
                refresh_again = 1;

                return;
            }

            refreshing = 1;
            read_layout.begin ();
        }

        /** Dipanggil sebelum popover terbuka supaya submenu ikut terisi. */
        public void about_to_show () {
            try {
                connection.call_sync (
                    bus_name,
                    object_path,
                    "com.canonical.dbusmenu",
                    "AboutToShow",
                    new GLib.Variant ("(i)", (int32) 0),
                    new GLib.VariantType ("(b)"),
                    GLib.DBusCallFlags.NONE,
                    2000
                );
            } catch (Error e) {
                debug ("baki: AboutToShow gagal: %s", e.message);
            }

            refresh ();
        }

        public Gtk.Widget? build () {
            if (root == null) {
                return null;
            }

            var box = build_children (root);

            if (box.get_children ().length () == 0) {
                return null;
            }

            return box;
        }

        private void send_event (int32 id) {
            try {
                connection.call_sync (
                    bus_name,
                    object_path,
                    "com.canonical.dbusmenu",
                    "Event",
                    new GLib.Variant ("(isvu)", id, "clicked", new GLib.Variant ("i", 0), (uint32) 0),
                    null,
                    GLib.DBusCallFlags.NONE,
                    2000
                );
            } catch (Error e) {
                warning ("baki: Event(%d) gagal: %s", id, e.message);
            }

            refresh ();
        }

        private async void read_layout () {
            GLib.Variant reply = null;

            try {
                reply = yield connection.call (
                    bus_name,
                    object_path,
                    "com.canonical.dbusmenu",
                    "GetLayout",
                    new GLib.Variant ("(ii@as)", (int32) 0, (int32) (-1), new GLib.Variant.strv (new string[0])),
                    new GLib.VariantType ("(u(ia{sv}av))"),
                    GLib.DBusCallFlags.NONE,
                    3000
                );
            } catch (Error e) {
                warning ("baki: GetLayout %s gagal: %s", object_path, e.message);
                refreshing = 0;

                return;
            }

            if (reply == null) {
                refreshing = 0;

                return;
            }

            root = parse_node (reply.get_child_value (1));
            refreshing = 0;
            layout_changed ();

            if (refresh_again != 0) {
                refresh_again = 0;
                refresh ();
            }
        }

        private static Node parse_node (GLib.Variant input) {
            // Elemen 'av' membungkus struct node, jadi dilepas dulu.
            var variant = input.is_of_type (GLib.VariantType.VARIANT) ? input.get_variant () : input;

            var node = new Node ();

            if (variant.n_children () < 3) {
                warning ("baki: node menu tidak lengkap, dilewati");

                return node;
            }

            node.id = variant.get_child_value (0).get_int32 ();

            var props = variant.get_child_value (1);
            node.label = prop_string (props, "label");
            node.icon_name = prop_string (props, "icon-name");
            node.toggle_type = prop_string (props, "toggle-type");
            node.children_display = prop_string (props, "children-display");
            node.enabled = prop_bool (props, "enabled", true);
            node.visible = prop_bool (props, "visible", true);

            var type = prop_string (props, "type");
            node.type = type != "" ? type : "standard";

            // Sebagian server mengirim toggle-state sebagai i, sebagian bool.
            if (props.lookup_value ("toggle-state", GLib.VariantType.INT32) != null) {
                node.toggle_state = props.lookup_value ("toggle-state", GLib.VariantType.INT32).get_int32 ();
            } else if (props.lookup_value ("toggle-state", GLib.VariantType.BOOLEAN) != null) {
                node.toggle_state = props.lookup_value ("toggle-state", GLib.VariantType.BOOLEAN).get_boolean () ? 1 : 0;
            }

            var children = variant.get_child_value (2);

            for (var i = 0; i < children.n_children (); i++) {
                node.children.add (parse_node (children.get_child_value (i)));
            }

            return node;
        }

        private static string prop_string (GLib.Variant dict, string key) {
            var value = dict.lookup_value (key, GLib.VariantType.STRING);

            if (value == null) {
                value = dict.lookup_value (key, GLib.VariantType.OBJECT_PATH);
            }

            return value != null ? value.get_string () : "";
        }

        private static bool prop_bool (GLib.Variant dict, string key, bool fallback) {
            var value = dict.lookup_value (key, GLib.VariantType.BOOLEAN);

            return value != null ? value.get_boolean () : fallback;
        }

        private Gtk.Box build_children (Node parent) {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            foreach (var node in parent.children) {
                if (!node.visible || node.type == "separator") {
                    if (node.visible && node.type == "separator") {
                        box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
                    }

                    continue;
                }

                box.add (build_item (node));
            }

            return box;
        }

        private Gtk.Widget build_item (Node node) {
            var has_submenu = node.children_display == "submenu";

            if (!has_submenu) {
                var button = new Gtk.ModelButton ();
                button.text = strip_mnemonics (node.label);
                button.sensitive = node.enabled;
                button.clicked.connect (() => { send_event (node.id); });

                if (node.toggle_state == 1 && (node.toggle_type == "checkbox" || node.toggle_type == "checkmark")) {
                    button.get_child ().get_style_context ().add_class ("checked");
                }

                return button;
            }

            // Gtk.ModelButton tidak bisa membuka submenu sendiri, jadi dipakai
            // Gtk.MenuButton + Gtk.Popover berisi kotak dari node anak.
            var menu_button = new Gtk.MenuButton ();
            menu_button.label = strip_mnemonics (node.label);
            menu_button.sensitive = node.enabled;
            menu_button.get_style_context ().add_class ("flat");

            var popover = new Gtk.Popover (null);
            popover.add (build_children (node));
            menu_button.popover = popover;

            menu_button.clicked.connect (() => { about_to_show (); });

            return menu_button;
        }

        private static string strip_mnemonics (string label) {
            return label.replace ("_", "").replace ("\\", "");
        }
    }
}
