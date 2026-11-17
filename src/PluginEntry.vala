/*
 * Titik masuk plugin Wingpanel.
 *
 * Wingpanel 8 memuat setiap berkas di /usr/lib/<arch>/wingpanel/ yang
 * bertipe application/x-sharedlib, lalu mencari simbol `get_indicator`.
 * Simbol itu dipanggil dengan (GModule, IndicatorManager.ServerType).
 *
 * Plugin ini mengembalikan null (tidak punya ikon panel sendiri): ikon panel
 * dibuat per StatusNotifierItem oleh Plugin.register_indicator ().
 */

public Wingpanel.Indicator? get_indicator (
    GLib.Module module,
    Wingpanel.IndicatorManager.ServerType server_type
) {
    // get_indicator mengembalikan null, jadi Wingpanel menutup modul ini dan
    // GType indikator yang dibuat di dalamnya jadi tidak valid.
    module.make_resident ();

    if (server_type != Wingpanel.IndicatorManager.ServerType.SESSION) {
        return null;
    }

    // instance_init berjalan saat wingpanel menginisialisasi semua plugin.
    GLib.DBusConnection connection = null;

    try {
        connection = GLib.Bus.get_sync (GLib.BusType.SESSION);
    } catch (Error e) {
        critical ("sys-tray: tidak bisa memakai session bus: %s", e.message);

        return null;
    }

    SysTray.Plugin.get_default ().setup (connection);

    return null;
}
