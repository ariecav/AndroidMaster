# Master_Android

Skeleton proyek Android minimal yang **sudah terbukti build**, dipakai sebagai
titik mula aplikasi baru. Aplikasinya sendiri hanya menampilkan **"Hello Apps"**.

Tujuannya satu: repo ini bisa di-`git clone` lalu langsung dibangun, baik di
PC/WSL maupun di **Debian proot di Termux** pada HP Android.

| | |
|---|---|
| Package / applicationId | `id.sepultura.masterandroid` |
| minSdk / targetSdk / compileSdk | 26 / 37 / 37.2 |
| Gradle | 9.6.0 (wrapper) |
| AGP / Kotlin | 9.4.1 / 2.2.10 |
| JDK minimal | 17 |
| UI | Jetpack Compose + Material 3 |

## Isi

```
Master_Android/
├── CLAUDE.md                     <- BACA DULU kalau kamu AI/agent
├── AGENTS.md                     penunjuk ke CLAUDE.md untuk AI non-Claude
├── README.md
├── docs/
│   ├── TERMUX_DEBIAN_SETUP.md    <- cara menjalankan di HP (Termux + Debian proot)
│   └── TROUBLESHOOTING.md        <- kumpulan error + solusinya
├── build.gradle.kts              pendaftaran plugin tingkat atas
├── settings.gradle.kts           nama project + daftar modul + repository
├── gradle.properties             setelan yang ikut git (bukan setelan mesin)
├── gradlew / gradlew.bat         wrapper, jangan pakai `gradle` sistem
├── gradle/
│   ├── libs.versions.toml        version catalog: SEMUA nomor versi di sini
│   └── wrapper/                  gradle-wrapper.jar + properties
├── local.properties.example      template; local.properties asli tidak ikut git
└── app/
    ├── build.gradle.kts
    ├── proguard-rules.pro
    └── src/
        ├── main/
        │   ├── AndroidManifest.xml
        │   ├── java/id/sepultura/masterandroid/
        │   │   ├── MainActivity.kt        layar Hello Apps (Compose)
        │   │   ├── Greeting.kt            Kotlin murni, bisa diuji unit test
        │   │   └── ui/theme/              Color.kt, Theme.kt, Type.kt
        │   └── res/                       icon launcher, strings, themes, aturan backup
        └── test/java/.../GreetingTest.kt  3 unit test JVM
```

## Mulai dipakai: dua langkah

### 1. Buat `local.properties`

File ini **tidak ikut git** karena path SDK berbeda di tiap mesin.

```bash
cp local.properties.example local.properties
# lalu edit isinya jadi path SDK kamu, contoh:
#   sdk.dir=/home/namauser/android-sdk
```

Alternatif tanpa file: set variabel lingkungan `ANDROID_HOME`.

### 2. Build

```bash
./gradlew assembleDebug        # bikin APK debug
./gradlew testDebugUnitTest    # 3 unit test JVM, tanpa HP
./gradlew tasks                # daftar task yang tersedia
```

APK keluar di `app/build/outputs/apk/debug/app-debug.apk`.

> **Catatan WSL.** Kalau proyek ini ditaruh di `/mnt/c`, `/mnt/d`, dan
> seterusnya, folder `build/` bisa dipindahkan ke filesystem Linux lewat init
> script Gradle di `~/.gradle/init.d/`, karena drvfs menolak copy-dengan-atribut
> dari AGP (`Operation not permitted`). Init script itu **setelan mesin, bukan
> bagian repo** — lihat `docs/TROUBLESHOOTING.md`.

## Menjalankan di HP

Lihat **[docs/TERMUX_DEBIAN_SETUP.md](docs/TERMUX_DEBIAN_SETUP.md)**. Ada satu
hal yang wajib dibaca di sana: binary `aapt2` dari Google itu **x86_64**,
sedangkan HP Android `aarch64`, jadi butuh penanganan khusus.

## Menambah dependency

Tidak ada yang perlu dipasang manual. Tambah dua baris, Gradle mengunduh sendiri
dari Maven saat build berikutnya.

1. Di `gradle/libs.versions.toml`:

```toml
[versions]
retrofit = "2.11.0"

[libraries]
retrofit = { group = "com.squareup.retrofit2", name = "retrofit", version.ref = "retrofit" }
```

2. Di `app/build.gradle.kts`:

```kotlin
dependencies {
  implementation(libs.retrofit)
}
```

Untuk library yang butuh **annotation processing** (Hilt, Room), tambahkan juga
plugin KSP di `[plugins]` dan terapkan di `app/build.gradle.kts`. KSP berjalan di
atas JVM, jadi tetap aman di HP aarch64.

## Kirim ke GitHub

Repo ini sengaja dibiarkan **tanpa** `git init`. Jalankan sendiri:

```bash
cd Master_Android
git init
git add -A
git commit -m "Initial commit: Master_Android skeleton"
git branch -M main
git remote add origin git@github.com:NAMA_KAMU/Master_Android.git
git push -u origin main
```

Sebelum commit pertama, pastikan `git status` **tidak** menampilkan
`local.properties`, `.gradle/`, `.kotlin/`, atau `build/`. Semuanya sudah ada di
`.gitignore`; kalau muncul, berarti ada yang salah.
