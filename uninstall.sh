#!/bin/sh
#
# wingpanel-indicator-baki uninstaller: mengembalikan sesi ke kondisi asli Wingpanel.
#
# Yang dilakukan: buang berkas plugin, restart Wingpanel. Tidak ada perubahan
# lain di sistem (tidak ada autostart, konfigurasi, atau service D-Bus baru),
# jadi kondisi setelah ini sama dengan sebelum plugin dipasang: tidak ada yang
# memiliki nama bus org.kde.StatusNotifierWatcher.
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
