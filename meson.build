project(
    'sys-tray',
    'vala', 'c',
    version: '0.1.0',
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

config = configuration_data()
config.set_quoted('GETTEXT_PACKAGE', meson.project_name())
configure_file(output: 'config.h', configuration: config)

shared_module(
    meson.project_name(),
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
    c_args: [
        '-include' + join_paths(meson.current_build_dir(), 'config.h'),
        '-I' + join_paths(meson.current_source_dir(), 'vapi')
    ],
    install: true,
    install_dir: indicators_dir
)

# Harness uji: memuat plugin seperti Wingpanel lalu melaporkan indikator aktif.
# Jalankan: ./build/sys-tray-harness build/libsys-tray.so
executable(
    'sys-tray-harness',
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
# Jalankan: meson test -C build  (atau ./build/sys-tray-icon-test)
icon_test = executable(
    'sys-tray-icon-test',
    'tests/icon_test.vala',
    'src/IconData.vala',
    dependencies: [glib_dep, gio_dep, gtk_dep, gdk_pixbuf_dep],
    vala_args: ['--vapidir=' + join_paths(meson.current_source_dir(), 'vapi')],
    c_args: ['-I' + join_paths(meson.current_source_dir(), 'vapi')],
    install: false
)
test('icon-data', icon_test)
