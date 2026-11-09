# Panduan untuk AI / agent yang bekerja di repo ini

File ini dibaca otomatis oleh Claude Code. Kalau kamu memakai AI lain, baca ini
lebih dulu sebelum menyentuh file apa pun.

Repo ini adalah **skeleton**: aplikasi Android minimal berisi satu layar
"Hello Apps". Fungsinya sebagai titik mula aplikasi baru, dan **kondisi
"bisa build" adalah properti paling berharga di sini**. Jangan merusaknya.

---

## 1. Hal pertama: kamu ada di mana?

Perlakuan berbeda antara PC dan HP. Cek dulu, jangan menebak:

```bash
uname -m                 # x86_64 = PC/WSL, aarch64 = HP
cat /etc/os-release      # Debian proot di Termux biasanya Debian
echo "$ANDROID_HOME"
java -version            # wajib 17 atau lebih baru
```

**Kalau hasilnya `aarch64`, kamu di HP.** Sebelum menjalankan build apa pun,
baca `docs/TERMUX_DEBIAN_SETUP.md` dari atas sampai bawah. Ada masalah
arsitektur yang membuat `./gradlew assembleDebug` gagal kalau belum disiapkan,
dan kegagalan itu **bukan** bug di kode repo ini. Jangan "memperbaiki" kode
untuk mengatasinya.

---

## 2. Aturan yang tidak boleh dilanggar

1. **Jangan commit `local.properties`.** Isinya path SDK yang beda tiap mesin.
   Sudah ada di `.gitignore`. Template-nya `local.properties.example`.
2. **Jangan masukkan setelan mesin ke `gradle.properties` di repo.** Yang
   termasuk setelan mesin: `org.gradle.java.home`, ukuran heap yang
   dioptimalkan untuk satu perangkat, `org.gradle.workers.max`,
   `android.aapt2FromMavenOverride`, dan **semua** `systemProp.*.proxy*`.
   Tempatnya di `~/.gradle/gradle.properties`.
3. **Jangan pernah menulis kredensial** (password proxy, token, keystore,
   `*.jks`) ke file mana pun di dalam repo.
4. **Nomor versi hanya ada di `gradle/libs.versions.toml`.** Jangan menulis
   versi literal di `build.gradle.kts`.
5. **Jangan menaikkan versi AGP/Gradle/Kotlin tanpa diminta.** Kombinasi
   AGP 9.4.1 + Gradle 9.6.0 + Kotlin 2.2.10 di repo ini sudah diuji build.
   Menaikkan salah satunya tanpa yang lain = build rusak.
6. **Pakai `./gradlew`, bukan `gradle`.** Wrapper menjamin versi Gradle yang
   sama di semua mesin.
7. **Jangan hapus atau regenerasi `gradle/wrapper/gradle-wrapper.jar`.**
8. **Plugin `org.jetbrains.kotlin.android` memang tidak ada** dan itu bukan
   kelupaan: AGP 9.x sudah punya dukungan Kotlin bawaan. Jangan ditambahkan.

---

## 3. Perintah verifikasi

Urut dari paling murah ke paling mahal. Pakai yang paling murah yang masih
membuktikan perubahanmu benar.

```bash
./gradlew testDebugUnitTest     # unit test JVM, tanpa HP/emulator
./gradlew assembleDebug         # bikin APK debug
./gradlew lintDebug             # analisis statis Android
./gradlew clean                 # kalau ada kecurigaan hasil build basi
```

Perlu diketahui: **di proyek Android, `testDebugUnitTest` tetap membutuhkan
`aapt2`**, karena kompilasi Kotlin butuh kelas `R` yang dihasilkan dari
resource. Jadi di HP, `aapt2` harus beres dulu sebelum test apa pun bisa jalan.

Yang butuh HP/emulator tersambung (tidak wajib untuk pekerjaan biasa):

```bash
./gradlew connectedDebugAndroidTest
```

---

## 4. Tempat menambahkan sesuatu

| Mau apa | Sentuh file ini |
|---|---|
| Tambah library | `gradle/libs.versions.toml` lalu `app/build.gradle.kts` |
| Tambah permission | `app/src/main/AndroidManifest.xml` |
| Tambah layar Compose | file baru di `app/src/main/java/id/sepultura/masterandroid/` |
| Ubah warna / font | `app/src/main/java/id/sepultura/masterandroid/ui/theme/` |
| Tambah teks UI | `app/src/main/res/values/strings.xml`, jangan hardcode di Kotlin |
| Ubah nama aplikasi | `app_name` di `strings.xml` |
| Ubah nama paket | `namespace` + `applicationId` di `app/build.gradle.kts`, **dan** struktur folder, **dan** `package` di tiap file `.kt` |

Logika yang ingin bisa diuji unit test JVM: tulis sebagai Kotlin murni tanpa
`import android.*`, seperti `Greeting.kt`. Begitu sebuah kelas menyentuh
`android.*`, dia hanya bisa diuji lewat instrumented test yang butuh HP.

---

## 5. Gaya kode

- Indentasi **2 spasi** (ikuti file yang sudah ada).
- Komentar ditulis **bahasa Indonesia**, dan menjelaskan **kenapa**, bukan
  mengulang apa yang sudah jelas dari kodenya.
- Nama `val`/`fun` bahasa Inggris, nama fungsi test boleh bahasa Indonesia
  seperti di `GreetingTest.kt`.

## 6. Kalau build gagal

1. Baca pesan error paling atas, bukan paling bawah.
2. Ulang dengan `--stacktrace` lalu, kalau perlu, `--info`.
3. Cocokkan dengan `docs/TROUBLESHOOTING.md` — kebanyakan kegagalan di HP sudah
   terdaftar di sana beserta solusinya.
4. **Laporkan apa adanya.** Jangan bilang "selesai" kalau build gagal, dan
   jangan menonaktifkan test atau menghapus kode supaya build hijau.
