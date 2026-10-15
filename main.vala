/* Sumber utama lama berbasis AppIndicator tidak dipakai lagi.
 *
 * Sebab: Wingpanel 8 (elementary OS 8) tidak punya renderer StatusNotifier/
 * AppIndicator, jadi indikator AppIndicator tidak akan pernah tampil di panel.
 * Gantinya plugin ini (src/) mengambil peran SNI host + watcher.
 *
 * Cara pakai: lihat README.md (build dengan meson, pasang libsys-tray.so ke
 * /usr/lib/x86_64-linux-gnu/wingpanel/).
 */
int main (string[] args) {
    stderr.printf ("sys-tray adalah plugin Wingpanel, bukan aplikasi mandiri.\n");
    return 1;
}
