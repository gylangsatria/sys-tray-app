#!/usr/bin/env python3
"""Item SNI palsu untuk menguji jalur item-keluar.

Mendaftar ke org.kde.StatusNotifierWatcher sebagai /StatusNotifierItem dengan
IconName kosong dan hanya IconPixmap, lalu keluar saat di-SIGTERM. Kepergiannya
memicu on_owner_vanished -> Plugin.remove -> ItemIndicator.destroy.

Pemakaian:
  python3 fake_item.py /Item/A /Item/B   # dua item, satu proses
  python3 fake_item.py --husk /Item/X    # daftar tanpa mengekspor object-nya
"""
import signal
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

XML = """
<node>
  <interface name="org.kde.StatusNotifierItem">
    <property name="Category" type="s" access="read"/>
    <property name="Id" type="s" access="read"/>
    <property name="Title" type="s" access="read"/>
    <property name="Status" type="s" access="read"/>
    <property name="IconName" type="s" access="read"/>
    <property name="IconPixmap" type="a(iiay)" access="read"/>
    <property name="Menu" type="o" access="read"/>
  </interface>
</node>
"""

SIZE = 16
# ARGB big-endian: byte di memory R, G, B, A. Warna merah penuh.
PIXELS = bytes([200, 30, 30, 255] * (SIZE * SIZE))
PIXMAP = [(SIZE, SIZE, PIXELS)]

PROPS = {
    "Category": GLib.Variant("s", "ApplicationStatus"),
    "Id": GLib.Variant("s", "UjiSnI"),
    "Title": GLib.Variant("s", "Item Uji"),
    "Status": GLib.Variant("s", "Active"),
    "IconName": GLib.Variant("s", ""),
    "IconPixmap": GLib.Variant("a(iiay)", PIXMAP),
    "Menu": GLib.Variant("o", "/MenuBar"),
}


def on_method_call(_conn, _sender, _path, _iface, method, _params, invocation):
    invocation.return_error_literal(Gio.io_error_quark(), Gio.IOErrorEnum.FAILED, method)


def main():
    argumen = [a for a in sys.argv[1:] if not a.startswith("--")]
    husk = "--husk" in sys.argv[1:]
    paths = argumen or ["/StatusNotifierItem"]

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    node = Gio.DBusNodeInfo.new_for_xml(XML)

    for path in paths:
        props = dict(PROPS)
        props["Title"] = GLib.Variant("s", "Item %s" % path)

        # --husk: daftar item tanpa mengekspor object-nya, meniru path mati
        # (mis. item lewat xdg-dbus-proxy). Propertinya tidak bisa dibaca.
        if not husk:
            bus.register_object(
                path,
                node.interfaces[0],
                on_method_call,
                lambda _c, _s, _p, _i, name, props=props: props[name],
                None,
            )

        bus.call_sync(
            "org.kde.StatusNotifierWatcher",
            "/StatusNotifierWatcher",
            "org.kde.StatusNotifierWatcher",
            "RegisterStatusNotifierItem",
            GLib.Variant("(s)", (path,)),
            None,
            Gio.DBusCallFlags.NONE,
            3000,
            None,
        )
        print("item uji terdaftar: %s" % path, flush=True)

    loop = GLib.MainLoop()
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, lambda: (loop.quit(), False)[1])

    return loop.run()


if __name__ == "__main__":
    sys.exit(main())
