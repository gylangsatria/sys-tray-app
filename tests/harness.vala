/*
 * Harness uji: memuat libbaki.so seperti Wingpanel, memanggil
 * get_indicator(), lalu memeriksa indikator apa saja yang terdaftar dan
 * widget apa yang dihasilkan. Bukan bagian dari aplikasi.
 */

[CCode (has_target = false)]
private delegate Wingpanel.Indicator? RegisterPluginFunction (
    GLib.Module module,
    Wingpanel.IndicatorManager.ServerType server_type
);

private int report () {
    var manager = Wingpanel.IndicatorManager.get_default ();
    var indicators = manager.get_indicators ();
    stdout.printf ("jumlah indikator: %u\n", indicators.size);

    foreach (var indicator in indicators) {
        // Popover dibuka lebih dulu: refresh_menu() membaca layout dbusmenu dan
        // mengganti isi popover. Kalau penggantian isi salah, GTK mencetak
        // Gtk-CRITICAL di sini.
        indicator.opened ();

        var display = indicator.get_display_widget ();
        var popover = indicator.get_widget ();
        stdout.printf (
            "  code_name=%s visible=%s display=%s popover=%s\n",
            indicator.code_name,
            indicator.visible.to_string (),
            display.get_type ().name (),
            popover != null ? "ada" : "null"
        );

        if (display is Gtk.Container) {
            var children = ((Gtk.Container) display).get_children ();
            stdout.printf ("    elemen panel: %u\n", children.length ());

            foreach (var child in children) {
                if (child is Gtk.Image) {
                    var image = (Gtk.Image) child;
                    var storage = image.get_storage_type ();

                    // storage ICON_NAME berarti ikon datang dari tema (mis.
                    // Discord: status_icon_1 + IconThemePath), bukan pixmap.
                    if (storage == Gtk.ImageType.ICON_NAME) {
                        unowned string nama = null;
                        Gtk.IconSize ukuran = Gtk.IconSize.MENU;
                        image.get_icon_name (out nama, out ukuran);
                        var info = Gtk.IconTheme.get_default ().lookup_icon (nama, 16, 0);
                        stdout.printf (
                            "      gambar: storage=%d nama=%s berkas=%s\n",
                            (int) storage,
                            nama ?? "-",
                            info != null ? info.get_filename () : "(tak ada)"
                        );
                    } else {
                        stdout.printf ("      gambar: storage=%d\n", (int) storage);
                    }
                } else if (child is Gtk.Label) {
                    stdout.printf ("      label: %s\n", ((Gtk.Label) child).get_label ());
                }
            }
        }

        if (popover is Gtk.Container) {
            var children = ((Gtk.Container) popover).get_children ();
            stdout.printf ("    elemen popover: %u\n", children.length ());

            foreach (var child in children) {
                if (child is Gtk.Container) {
                    foreach (var row in ((Gtk.Container) child).get_children ()) {
                        if (row is Gtk.ModelButton) {
                            var button = (Gtk.ModelButton) row;
                            stdout.printf ("      item menu: %s\n", button.text);

                            if (button.text != null && button.text.contains ("Uji Klik")) {
                                stdout.printf ("      -> klik %s\n", button.text);
                                GLib.Signal.emit_by_name (button, "clicked");
                            }
                        } else if (row is Gtk.Separator) {
                            stdout.printf ("      pemisah\n");
                        } else if (row is Gtk.MenuButton) {
                            stdout.printf ("      submenu: %s\n", ((Gtk.MenuButton) row).label);
                        } else {
                            stdout.printf ("      lain: %s\n", row.get_type ().name ());
                        }
                    }
                }
            }
        }
    }

    return 0;
}

public int main (string[] args) {
    Gtk.init (ref args);

    var path = args.length > 1 ? args[1] : "build/libbaki.so";
    var module = GLib.Module.open (path, GLib.ModuleFlags.LAZY);

    if (module == null) {
        stderr.printf ("gagal memuat %s: %s\n", path, GLib.Module.error ());

        return 1;
    }

    void* symbol;

    if (!module.symbol ("get_indicator", out symbol) || symbol == null) {
        stderr.printf ("get_indicator tidak ditemukan\n");

        return 1;
    }

    var register_plugin = (RegisterPluginFunction) symbol;
    var indicator = register_plugin (module, Wingpanel.IndicatorManager.ServerType.SESSION);
    stdout.printf ("get_indicator() mengembalikan: %s\n", indicator == null ? "null" : indicator.code_name);

    var loop = new GLib.MainLoop ();
    // Laporan berkala supaya item yang mendaftar/keluar di tengah tidak terlewat.
    GLib.Timeout.add_seconds (4, () => { report (); return true; });
    GLib.Timeout.add_seconds (20, () => { loop.quit (); return false; });
    loop.run ();

    return 0;
}
