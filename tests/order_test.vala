/* Cek prefix code_name tray di antara "monitor indicator" dan "nightlight". Jalankan: meson test -C build */

public int main (string[] args) {
    var monitor = "monitor indicator";
    var nightlight = "nightlight";
    var tray = "monitor-ayatana-" + "/org/kde/StatusNotifierItem";

    if (!(strcmp (tray, monitor) > 0) || !(strcmp (tray, nightlight) < 0)) {
        stderr.printf ("prefix code_name salah: %s harus di antara %s dan %s\n", tray, monitor, nightlight);

        return 1;
    }

    stdout.printf ("ok: %s < %s < %s\n", monitor, tray, nightlight);

    return 0;
}
