# sys-tray

A StatusNotifierItem (SNI / AppIndicator) host for **Wingpanel 8** on
elementary OS 8. Written in Vala with GTK3.

## Why a Wingpanel plugin and not a regular AppIndicator app

Wingpanel 8 has no SNI/AppIndicator renderer, and the bundled
`xapp-sn-watcher` doesn't run on elementary OS 8. So AppIndicator apps never
turn up in the panel, whatever you install. An earlier version of this repo
was a standalone AppIndicator app, and it never drew a thing.

This plugin covers both halves of the job instead:

1. **SNI watcher**: it owns the `org.kde.StatusNotifierWatcher` bus name and
   answers `RegisterStatusNotifierItem` / `RegisterStatusNotifierHost`.
2. **SNI host**: it reads each item's properties
   (`org.kde.StatusNotifierItem`) and its menu (`com.canonical.dbusmenu`),
   then draws one panel icon per item plus a popover holding the menu.

Same arrangement Ubuntu uses with libayatana-appindicator3, except the
renderer lives inside Wingpanel.

## Build

You need `valac`, `meson`, `ninja`, `libgtk-3-dev`, `libgranite-dev`, and
`libwingpanel-3.0-dev` (or just the vapi/header files from
`libwingpanel-dev`).

The repo carries its own copies of `vapi/wingpanel.h` and
`vapi/wingpanel-8.0.vapi`, taken from Wingpanel 8.0.4, so you can build
without the `-dev` package installed.

```sh
meson setup build --prefix=/usr
ninja -C build
```

Everything lands in `build/`. Nothing outside that directory is touched.

## Trying it without installing

```sh
./build/sys-tray-harness build/libsys-tray.so
```

The harness loads the plugin the way Wingpanel does, prints the indicators
that got registered along with the contents of each item's menu, and clicks
the `Uji Klik` menu item if one exists. SNI apps running in your session show
up right away.

## Layout

| File | What's in it |
| --- | --- |
| `src/PluginEntry.vala` | the `get_indicator()` symbol Wingpanel looks for |
| `src/Plugin.vala` | maps SNI items to Wingpanel indicators, cleans them up on exit |
| `src/Watcher.vala` | `org.kde.StatusNotifierWatcher` |
| `src/ItemIndicator.vala` | panel icon plus SNI properties (IconName, Status, XAyatanaLabel, Menu) |
| `src/DbusMenu.vala` | minimal `com.canonical.dbusmenu` client that builds GTK widgets |
| `main.vala` | the old AppIndicator entry point, unused, kept as a note |

## Install

```sh
./install.sh                        # dependency, build, install, restart Wingpanel
```

Build dependencies are installed automatically with `apt-get` when missing
(`meson`, `ninja-build`, `valac`, `pkg-config`, `libglib2.0-dev`,
`libgee-0.8-dev`, `libgtk-3-dev`, `libgranite-dev`). `libwingpanel` needs no
`-dev` package: the repo carries the headers/vapi itself.

Or by hand, into `/usr/lib/x86_64-linux-gnu/wingpanel/`:

```sh
meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
pkill io.elementary.wingpanel      # reload the panel
```

This writes to `/usr` (sudo needed), so do it only on the machine you want it
on. Nothing else is needed; `xapp-sn-watcher` can stay off.

Dry run without touching `/usr` (Meson's `DESTDIR` convention):

```sh
DESTDIR=/tmp/st ./install.sh        # files land in /tmp/st/usr/...
DESTDIR=/tmp/st ./uninstall.sh
```

## Uninstall

```sh
./uninstall.sh                      # remove the plugin + restart Wingpanel
```

The install adds exactly one file and no autostart entries, D-Bus services or
config, so removing that file is a full revert: the session goes back to stock
Wingpanel 8, where nothing owns `org.kde.StatusNotifierWatcher`.

## Known limits

- Icons come from `IconName` (theme name or absolute path) and
  `IconThemePath`. The `IconPixmap`/`icon-data` property (raw image bytes)
  isn't drawn yet.
- Left-clicking the icon opens the popover. SNI `Activate` and
  `SecondaryActivate` are never called, because Wingpanel owns the popover
  gesture.
- The popover is built out of `Gtk.Box` instead of `Gtk.Menu`, since
  Wingpanel's popover is a plain container; submenus use `Gtk.MenuButton`.
