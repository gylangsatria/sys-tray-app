/*
 * Ikon mentah StatusNotifierItem.
 *
 * Properti IconPixmap / AttentionIconPixmap bertipe a(iiay): array struct
 * (width, height, bytes). Bytes-nya ARGB big-endian (urutan byte di memory:
 * R, G, B, A) dengan alpha sudah di-premultiply.
 *
 * Banyak aplikasi (Electron/Flutter, mis. ZapFast) mengosongkan IconName dan
 * hanya mengirim pixmap, jadi properti ini harus digambar sendiri.
 */

namespace Baki {
    public class IconData : Object {
        // Ukuran ikon panel: 16px = Gtk.IconSize.MENU, ukuran yang dipakai
        // indikator native Wingpanel, jadi tinggi ikon semua item rata.
        public const int SIZE = 16;

        /** Entri terbesar yang valid dimenangkan. */
        public static Gdk.Pixbuf? parse (GLib.Variant? value) {
            if (value == null || !value.is_of_type (new GLib.VariantType ("a(iiay)"))) {
                return null;
            }

            Gdk.Pixbuf? best = null;
            var best_area = 0;

            for (var i = 0; i < value.n_children (); i++) {
                var pixbuf = parse_entry (value.get_child_value (i));

                if (pixbuf == null) {
                    continue;
                }

                var area = pixbuf.get_width () * pixbuf.get_height ();

                if (area > best_area) {
                    best = pixbuf;
                    best_area = area;
                }
            }

            return best;
        }

        public static Gdk.Pixbuf? parse_entry (GLib.Variant entry) {
            var width = entry.get_child_value (0).get_int32 ();
            var height = entry.get_child_value (1).get_int32 ();
            var bytes = entry.get_child_value (2).get_data_as_bytes ();

            if (width <= 0 || height <= 0 || bytes.get_size () < (size_t) (width * height * 4)) {
                return null;
            }

            // ARGB big-endian = byte order R, G, B, A di memory.
            // from_bytes tidak melempar, hanya bisa mengembalikan null.
            var pixbuf = new Gdk.Pixbuf.from_bytes (bytes, Gdk.Colorspace.RGB, true, 8, width, height, width * 4);

            if (pixbuf == null) {
                warning ("baki: pixmap %dx%d ditolak", width, height);
            }

            return pixbuf;
        }

        /** Perkecil ke sisi terpanjang `size`, jaga rasio; yang kecil dibiarkan. */
        public static Gdk.Pixbuf scale (Gdk.Pixbuf pixbuf, int size) {
            var w = pixbuf.get_width ();
            var h = pixbuf.get_height ();

            if (w <= 0 || h <= 0 || (w <= size && h <= size)) {
                return pixbuf;
            }

            var dest_w = w >= h ? size : (int) ((double) w * size / h);
            var dest_h = h > w ? size : (int) ((double) h * size / w);

            // HYPER: perbesaran-kualitas-terbaik gdk-pixbuf, penting karena
            // banyak aplikasi mengirim ikon 64x64 atau lebih besar.
            return pixbuf.scale_simple (dest_w, dest_h, Gdk.InterpType.HYPER) ?? pixbuf;
        }
    }
}
