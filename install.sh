#!/bin/sh
#
# wingpanel-indicator-sys-tray installer: build plugin lalu pasang ke direktori indikator Wingpanel.
#
# Wingpanel meng-hardcode INDICATORS_DIR saat build dan hanya memindai folder
# itu sekali saat start, jadi file harus ada di sana sebelum Wingpanel dijalankan.
#
# Uji coba tanpa menyentuh /usr:  DESTDIR=/tmp/st ./install.sh
#
set -eu

SO_NAME="libsys-tray.so"
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
BUILD="$HERE/build"
DESTDIR="${DESTDIR:-}"
missing=

for tool in meson ninja valac; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
command -v pkg-config >/dev/null 2>&1 || missing="$missing pkg-config"
# nama paket apt beda dari nama command
case " $missing " in *" ninja "*) missing="$missing ninja-build" ;; esac

# keperluan meson.build: nama .pc -> paket apt (Ubuntu noble / elementary OS 8)
DEPS="glib-2.0:libglib2.0-dev gio-2.0:libglib2.0-dev gmodule-2.0:libglib2.0-dev
      gee-0.8:libgee-0.8-dev gtk+-3.0:libgtk-3-dev gdk-pixbuf-2.0:libgdk-pixbuf-2.0-dev
      granite:libgranite-dev"

if command -v pkg-config >/dev/null 2>&1; then
    for pair in $DEPS; do
        pkg-config --exists "${pair%%:*}" || missing="$missing ${pair#*:}"
    done
else
    # pkg-config belum ada, jadi keperluan .pc belum bisa dipastikan.
    for pair in $DEPS; do
        missing="$missing ${pair#*:}"
    done
fi

# buang duplikat, jaga urutan
unique=
for word in $missing; do
    case " $unique " in *" $word "*) ;; *) unique="$unique $word" ;; esac
done
missing=${unique# }

if [ -n "$missing" ]; then
    if [ -n "$DESTDIR" ]; then
        echo "sys-tray: dependensi belum ada:$missing" >&2
        echo "sys-tray: mode uji coba tidak memasang dependensi; pasang dulu." >&2

        exit 1
    fi

    if ! command -v apt-get >/dev/null 2>&1; then
        echo "sys-tray: dependensi belum ada:$missing" >&2
        echo "sys-tray: pasang lewat manajer paket distro Anda, lalu jalankan lagi." >&2

        exit 1
    fi

    echo "==> pasang dependensi:$missing"
    # shellcheck disable=SC2086 # $missing sengaja dipecah: daftar nama paket.
    sudo apt-get install -y $missing || {
        echo "sys-tray: pemasangan gagal; coba 'sudo apt-get update' lalu ulangi." >&2

        exit 1
    }
fi

for tool in meson ninja valac; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "sys-tray: '$tool' masih belum tersedia." >&2

        exit 1
    }
done

# Direktori tujuan sebenarnya; hanya untuk laporan (ninja yang menulis berkas).
INDICATORS_DIR=
for dir in /usr/lib/*/wingpanel; do
    if [ -d "$dir" ]; then
        INDICATORS_DIR=$dir
        break
    fi
done
[ -n "$INDICATORS_DIR" ] || INDICATORS_DIR=/usr/lib/x86_64-linux-gnu/wingpanel

echo "==> build"
# Build dir eksplisit + source dir eksplisit: "meson setup <dir>" dengan satu
# argumen diperlakukan sebagai source dir kalau cwd bukan root repo.
if [ -f "$BUILD/meson-private/coredata.dat" ]; then
    meson setup "$BUILD" "$HERE" --prefix=/usr --reconfigure >/dev/null
else
    meson setup "$BUILD" "$HERE" --prefix=/usr >/dev/null
fi

# Sebagian berkas build (mis. .ninja_log) bisa jadi milik root kalau sebelumnya
# ada `sudo ninja -C build install`. Kalau begitu ninja sebagai user gagal;
# build dir aman dibuang lalu dibuat ulang.
if ! ninja -C "$BUILD"; then
    echo "==> build gagal (berkas build milik root?), build dir dibuat ulang"
    rm -rf "$BUILD"
    meson setup "$BUILD" "$HERE" --prefix=/usr >/dev/null
    ninja -C "$BUILD"
fi

echo "==> install ke $INDICATORS_DIR"
if [ -n "$DESTDIR" ]; then
    DESTDIR="$DESTDIR" ninja -C "$BUILD" install
    echo "==> uji coba selesai (DESTDIR=$DESTDIR), Wingpanel tidak disentuh"

    exit 0
fi

sudo ninja -C "$BUILD" install

echo "==> restart Wingpanel"
# Nama proses di Linux dipotong 15 karakter, jadi pola dicocokkan ke cmdline.
pkill -f io.elementary.wingpanel || true
sleep 2

# Gala tidak me-respawn Wingpanel (sudah dicek), jadi dijalankan ulang sendiri.
# setsid melepaskannya dari shell supaya tetap hidup setelah script keluar.
if ! pgrep -f io.elementary.wingpanel >/dev/null; then
    setsid io.elementary.wingpanel >/dev/null 2>&1 &
fi

echo "==> terpasang:"
ls -l "$INDICATORS_DIR/$SO_NAME"
