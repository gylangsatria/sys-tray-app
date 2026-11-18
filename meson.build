project(
    'wingpanel-indicator-baki',
    'vala', 'c',
    version: '0.1.0',
    license: 'GPL-3.0-or-later',
    meson_version: '>= 0.49.0'
)

glib_dep = dependency('glib-2.0', version: '>= 2.32')
gio_dep = dependency('gio-2.0')
gmodule_dep = dependency('gmodule-2.0')
gee_dep = dependency('gee-0.8')
gtk_dep = dependency('gtk+-3.0', version: '>= 3.10')
gdk_pixbuf_dep = dependency('gdk-pixbuf-2.0')
granite_dep = dependency('granite')
wingpanel_dep = declare_dependency(
    # libwingpanel-dev tidak dipasang; pakai soname langsung agar tidak
    # bergantung pada arsitektur (x86_64/aarch64) maupun lokasi libdir.
    link_args: ['-l:libwingpanel.so.8'],
    dependencies: [glib_dep, gio_dep, gmodule_dep, gee_dep, gtk_dep, gdk_pixbuf_dep, granite_dep]
)

indicators_dir = join_paths(get_option('prefix'), get_option('libdir'), 'wingpanel')

shared_module(
    'baki',
    'src/PluginEntry.vala',
    'src/Plugin.vala',
    'src/Watcher.vala',
    'src/ItemIndicator.vala',
    'src/DbusMenu.vala',
    'src/IconData.vala',
    dependencies: wingpanel_dep,
    vala_args: [
        '--vapidir=' + join_paths(meson.current_source_dir(), 'vapi'),
        '--pkg=wingpanel-8.0'
    ],
    c_args: ['-I' + join_paths(meson.current_source_dir(), 'vapi')],
    install: true,
    install_dir: indicators_dir
)

# Harness uji: memuat plugin seperti Wingpanel lalu melaporkan indikator aktif.
# Jalankan: ./build/baki-harness build/libbaki.so
executable(
    'baki-harness',
    'tests/harness.vala',
    dependencies: wingpanel_dep,
    vala_args: [
        '--vapidir=' + join_paths(meson.current_source_dir(), 'vapi'),
        '--pkg=wingpanel-8.0'
    ],
    c_args: ['-I' + join_paths(meson.current_source_dir(), 'vapi')],
    install: false
)

# Uji konversi IconPixmap -> Gdk.Pixbuf (tanpa D-Bus/display).
# Jalankan: meson test -C build  (atau ./build/baki-icon-test)
icon_test = executable(
    'baki-icon-test',
    'tests/icon_test.vala',
    'src/IconData.vala',
    dependencies: [glib_dep, gio_dep, gtk_dep, gdk_pixbuf_dep],
    vala_args: ['--vapidir=' + join_paths(meson.current_source_dir(), 'vapi')],
    c_args: ['-I' + join_paths(meson.current_source_dir(), 'vapi')],
    install: false
)
test('icon-data', icon_test)

# Uji posisi tray relatif terhadap Monitor & nightlight. Jalankan: meson test -C build
order_test = executable(
    'baki-order-test',
    'tests/order_test.vala',
    dependencies: [glib_dep],
    install: false
)
test('order', order_test)
