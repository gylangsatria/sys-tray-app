#!/bin/sh
#
# wingpanel-indicator-baki uninstaller: mengembalikan sesi ke kondisi asli Wingpanel.
#
# uninstaller: buang plugin + override autostart nm-applet, restart Wingpanel.
#
# Uji coba tanpa menyentuh /usr:  DESTDIR=/tmp/st ./uninstall.sh
#
set -eu

SO_NAME="libbaki.so"
DESTDIR="${DESTDIR:-}"

if [ -n "$DESTDIR" ]; then
    AS_ROOT=""
else
    AS_ROOT="sudo"
fi

echo "==> hapus berkas plugin"
# Hapus langsung, bukan lewat "ninja uninstall": manifest meson menyimpan path
# absolut yang ikut ter-bake DESTDIR dan ikut basi kalau build dir dihapus,
# sementara daftar ini menutup semua jalan pemasangan (ninja install, DESTDIR,
# atau rm manual) dan tidak mengutak-atik direktori induknya.
removed=0
for file in "$DESTDIR"/usr/lib/*/wingpanel/"$SO_NAME" \
            "$DESTDIR"/usr/local/lib/*/wingpanel/"$SO_NAME"; do
    [ -f "$file" ] || continue
    echo "    hapus $file"
    $AS_ROOT rm -f "$file"
    removed=$((removed + 1))
done

[ "$removed" -gt 0 ] || echo "    tidak ada ($SO_NAME sudah tidak terpasang)"

# Hapus override install.sh; hanya kalau isinya masih persis (edit tangan dijaga).
AUTOSTART_HIDE="$HOME/.config/autostart/nm-applet.desktop"
SYSTEM_HIDE='[Desktop Entry]
Type=Application
Name=NetworkManager Applet
Hidden=true'

if [ -f "$AUTOSTART_HIDE" ] && [ "$(cat "$AUTOSTART_HIDE")" = "$SYSTEM_HIDE" ]; then
    echo "==> hapus override autostart nm-applet"
    rm -f "$AUTOSTART_HIDE"
    restored=1
else
    restored=0
fi

if [ -n "$DESTDIR" ]; then
    echo "==> uji coba selesai (DESTDIR=$DESTDIR), Wingpanel tidak disentuh"

    exit 0
fi

echo "==> restart Wingpanel"
pkill -f io.elementary.wingpanel || true
sleep 2

if ! pgrep -f io.elementary.wingpanel >/dev/null; then
    setsid io.elementary.wingpanel >/dev/null 2>&1 &
fi

echo "==> sisa berkas plugin (harus kosong):"
ls -d /usr/lib/*/wingpanel/"$SO_NAME" /usr/local/lib/*/wingpanel/"$SO_NAME" 2>/dev/null \
    || echo "    bersih: sistem kembali ke Wingpanel asli"

# Tanpa override, nm-applet baru muncul saat login berikutnya: jalankan sekarang.
if [ "$restored" -eq 0 ] && [ ! -f "$AUTOSTART_HIDE" ] && command -v nm-applet >/dev/null 2>&1; then
    echo "==> jalankan lagi nm-applet"
    setsid nm-applet >/dev/null 2>&1 &
fi
