/*
 * Uji IconData: konversi IconPixmap SNI jadi Gdk.Pixbuf, plus penskalaan.
 * Jalankan: ./build/baki-icon-test
 * Tidak butuh D-Bus maupun display (Gdk.Pixbuf berdiri sendiri).
 *
 * Variant dibangun lewat GLib.Variant.parse (teks), bukan helper floating-ref
 * (new GLib.Variant/"builder.add_value"), supaya semirip mungkin dengan
 * Variant yang datang dari D-Bus.
 */

private static int gagal = 0;

private static void cek (string nama, bool hasil) {
    stdout.printf ("%s %s\n", hasil ? "ok  " : "GAGAL", nama);

    if (!hasil) {
        gagal++;
    }
}

/** Satu entri IconPixmap: (width, height, byte A, R, G, B). */
private static string entry_text (int lebar, int tinggi, uint8 a, uint8 r, uint8 g, uint8 b) {
    var sb = new GLib.StringBuilder ("(");

    sb.append_printf ("%d, %d, [", lebar, tinggi);

    for (var i = 0; i < lebar * tinggi; i++) {
        if (i > 0) {
            sb.append (", ");
        }

        sb.append_printf ("byte 0x%02x, byte 0x%02x, byte 0x%02x, byte 0x%02x", a, r, g, b);
    }

    sb.append ("])");

    return sb.str;
}

/** Satu entri dengan panjang byte seadanya (bisa sengaja tidak cocok). */
private static string entry_text_bytes (int lebar, int tinggi, int jumlah_byte) {
    var sb = new GLib.StringBuilder ();

    sb.append_printf ("(%d, %d, [", lebar, tinggi);

    for (var i = 0; i < jumlah_byte; i++) {
        if (i > 0) {
            sb.append (", ");
        }

        sb.append ("byte 0x01");
    }

    sb.append ("])");

    return sb.str;
}

private static GLib.Variant? parse (string tipe, string teks) {
    try {
        return GLib.Variant.parse (new GLib.VariantType (tipe), teks, null, null);
    } catch (Error e) {
        stdout.printf ("GAGAL menyiapkan uji: %s\n", e.message);
        gagal++;

        return null;
    }
}

private static GLib.Variant? pixmaps (string[] entries) {
    var sb = new GLib.StringBuilder ("[");

    for (var i = 0; i < entries.length; i++) {
        if (i > 0) {
            sb.append (", ");
        }

        sb.append (entries[i]);
    }

    sb.append ("]");

    return parse ("a(iiay)", sb.str);
}

public static int main (string[] args) {
    // 1. Satu entri: terbaca, ukuran dan alpha benar.
    var satu = pixmaps ({ entry_text (4, 4, 255, 10, 20, 30) });
    var pixbuf = satu != null ? Baki.IconData.parse (satu) : null;

    cek ("pixmap tunggal terbaca", pixbuf != null);
    cek ("ukuran 4x4", pixbuf != null && pixbuf.get_width () == 4 && pixbuf.get_height () == 4);
    cek ("alpha terbaca", pixbuf != null && pixbuf.get_has_alpha ());

    // 2. Urutan byte SNI (A, R, G, B) dikonversi ke RGBA milik GdkPixbuf.
    cek ("byte 0 = R", pixbuf != null && pixbuf.get_pixels ()[0] == 10);
    cek ("byte 1 = G", pixbuf != null && pixbuf.get_pixels ()[1] == 20);
    cek ("byte 2 = B", pixbuf != null && pixbuf.get_pixels ()[2] == 30);
    cek ("byte 3 = A", pixbuf != null && pixbuf.get_pixels ()[3] == 255);

    // 2b. Pixel transparan tetap transparan, warnanya tidak bocor ke alpha.
    var bening = pixmaps ({ entry_text (2, 2, 0, 255, 255, 255) });
    var kosong = bening != null ? Baki.IconData.parse (bening) : null;

    cek ("alpha 0 tetap 0", kosong != null && kosong.get_pixels ()[3] == 0);
    cek ("warna putih tidak jadi alpha", kosong != null && kosong.get_pixels ()[0] == 255);

    // 3. Dua entri: yang terbesar yang dipakai.
    var dua = pixmaps ({ entry_text (4, 4, 255, 1, 1, 1), entry_text (16, 16, 255, 2, 2, 2) });
    var besar = dua != null ? Baki.IconData.parse (dua) : null;

    cek ("entri terbesar dipakai", besar != null && besar.get_width () == 16);

    // 4. Entri pertama byte-nya kurang: dilewati, yang valid tetap dapat.
    var rusak = pixmaps ({ entry_text_bytes (8, 8, 4), entry_text (6, 6, 255, 3, 3, 3) });
    var tetap = rusak != null ? Baki.IconData.parse (rusak) : null;

    cek ("entri rusak dilewati", tetap != null && tetap.get_width () == 6);

    // 5. Semua entri tidak valid / properti bertipe lain -> null, bukan crash.
    var semua_rusak = pixmaps ({ entry_text_bytes (8, 8, 0) });
    var bukan_array = parse ("(iiay)", entry_text (4, 4, 255, 1, 1, 1));
    var bukan_pixmap = parse ("s", "\"bukan pixmap\"");

    cek ("gambar tidak valid -> null", semua_rusak != null && Baki.IconData.parse (semua_rusak) == null);
    cek ("properti kosong -> null", Baki.IconData.parse (null) == null);
    cek ("tipe salah -> null", bukan_pixmap != null && Baki.IconData.parse (bukan_pixmap) == null);
    cek ("bukan array -> null", bukan_array != null && Baki.IconData.parse (bukan_array) == null);

    // 6. Penskalaan: besar dikecilkan (rasio terjaga), kecil dibiarkan.
    var persegi = new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8, 64, 64);
    var kecil = Baki.IconData.scale (persegi, Baki.IconData.SIZE);

    cek ("64x64 -> 16x16", kecil.get_width () == 16 && kecil.get_height () == 16);

    var lonjong = new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8, 64, 32);
    var skala = Baki.IconData.scale (lonjong, Baki.IconData.SIZE);

    cek ("64x32 -> 16x8 (rasio terjaga)", skala.get_width () == 16 && skala.get_height () == 8);

    var mungil = new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8, 16, 16);
    var sama = Baki.IconData.scale (mungil, Baki.IconData.SIZE);

    cek ("16x16 dibiarkan", sama.get_width () == 16);

    stdout.printf ("\n%s (%d gagal)\n", gagal == 0 ? "SEMUA LULUS" : "ADA YANG GAGAL", gagal);

    return gagal == 0 ? 0 : 1;
}
