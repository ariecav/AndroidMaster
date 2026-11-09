# Troubleshooting

Dikelompokkan per tempat. Cari pesan error-nya, bukan menebak.

---

## A. Khusus Termux / Debian proot (aarch64)

### `aapt2: No such file or directory` padahal `ls` menunjukkan file itu ada

Bukan file-nya yang hilang, tapi **dynamic loader**-nya. `aapt2` x86_64 minta
`/lib64/ld-linux-x86-64.so.2`, yang tidak ada di sistem aarch64. Kernel
melaporkannya sebagai "no such file".

Solusi: `TERMUX_DEBIAN_SETUP.md` Langkah 5.

### `cannot execute binary file: Exec format error`

Sama sebabnya, hanya pesan yang berbeda. Berlaku untuk `aapt2`, `aapt`,
`zipalign`, `aidl`, `split-select`, dan `adb` dari `platform-tools`.

Yang **tidak** terkena masalah ini karena sebenarnya skrip pemanggil `java`:
`d8`, `apksigner`, `lint`, `sdkmanager`, `avdmanager`, `retrace`.

### `RES_TABLE_TYPE_TYPE entry offsets overlap actual entry data` / `failed to load include path .../android.jar`

`aapt2` yang dipakai terlalu tua untuk `android.jar` API 37.x. Biasanya karena
override menunjuk ke `aapt2` bawaan Debian (`/usr/bin/aapt2`, versi 2.19).
Pakai aapt2 Maven lewat box64: jalankan `bash scripts/setup-termux.sh`, atau
lihat `TERMUX_DEBIAN_SETUP.md` Langkah 5 Jalur B.

### `AAPT2 ... Daemon #0: Unexpected error output: [BOX64] Error: Symbol nftw not found`

Pembungkus `~/bin/aapt2` belum menyaring keluaran box64 (box64 menulis pesan
ini ke stdout). Build biasanya tetap sukses, tapi pesannya mengganggu dan bisa
mengacaukan protokol daemon aapt2. Buat ulang pembungkusnya dengan
`bash scripts/setup-termux.sh`.

### Build dibunuh di tengah jalan tanpa pesan error, atau `Gradle daemon disappeared`

Android membunuh prosesnya karena memori. Yang bisa dilakukan:

```bash
# 1. jangan biarkan Termux tertidur
termux-wake-lock

# 2. turunkan heap di ~/.gradle/gradle.properties
org.gradle.jvmargs=-Xmx1024m -XX:MaxMetaspaceSize=384m

# 3. serialkan
org.gradle.parallel=false
org.gradle.workers.max=1

# 4. matikan incremental Kotlin kalau masih kurang
kotlin.incremental=false
```

Tutup aplikasi lain, dan matikan optimasi baterai untuk Termux di setelan HP.

### `Could not connect to Kotlin compile daemon`

Pastikan ada di `~/.gradle/gradle.properties`:

```
kotlin.compiler.execution.strategy=in-process
```

### Build gagal aneh-aneh saat repo ditaruh di `/sdcard`

`/sdcard` tidak mendukung symlink, hard link, dan bit permission. Pindahkan repo
ke filesystem Linux (`~/projects/`) dan clone ulang. Jangan `cp -r` dari
`/sdcard`, karena metadata yang rusak ikut terbawa.

### `Permission denied` saat menjalankan `./gradlew`

```bash
chmod +x gradlew
```

### Unduhan Gradle atau dependency macet / timeout

Jaringan, bukan konfigurasi. Pakai Wi-Fi, lalu ulangi. Kalau cache sudah terisi
sebelumnya, build berikutnya bisa dicoba offline:

```bash
./gradlew assembleDebug --offline
```

---

## B. Khusus WSL (proyek berada di `/mnt/c`, `/mnt/d`, ...)

### `Operation not permitted` saat AGP menyalin file

drvfs tidak mendukung copy-dengan-atribut yang dipakai AGP. Pindahkan folder
`build/` ke filesystem Linux lewat init script Gradle — **setelan mesin, di luar
repo**:

```bash
mkdir -p ~/.gradle/init.d
cat > ~/.gradle/init.d/wsl-builddir.init.gradle.kts <<'EOF'
// Untuk project di /mnt/*, pindahkan folder build ke filesystem Linux.
gradle.beforeProject {
    val root = rootDir.absolutePath
    if (root.startsWith("/mnt/")) {
        val name = if (path == ":") "build" else path.removePrefix(":").replace(':', '/')
        layout.buildDirectory.set(
            File(System.getProperty("user.home"), "gradle-builds/${rootDir.name}/$name")
        )
    }
}
EOF
```

Efek sampingnya: APK **tidak lagi** di `app/build/outputs/...` melainkan di
`~/gradle-builds/<NAMA_FOLDER>/app/outputs/apk/debug/app-debug.apk`, dengan
`<NAMA_FOLDER>` = nama folder project di disk (bukan `rootProject.name`).
Daripada menghafal, cari saja:

```bash
find ~/gradle-builds -name '*.apk'
```

### `git init` gagal: `chmod on .git/config.lock failed: Operation not permitted`

Atau `fatal: detected dubious ownership in repository`.

`/mnt/c`, `/mnt/d`, dan seterusnya dimount 9p/drvfs **tanpa opsi `metadata`**.
Akibatnya semua file tampak milik `root` dan **setiap `chmod` ditolak**, jadi
`git` versi Linux tidak bisa membuat maupun memakai repo di sana. Cek sendiri:

```bash
grep ' /mnt/d ' /proc/mounts     # kalau tidak ada kata "metadata", inilah sebabnya
```

Pakai **Git for Windows**, yang jalan native di NTFS:

```bash
GIT="/mnt/c/Program Files/Git/cmd/git.exe"
cd /mnt/d/ProgramAndroid/AndroidMaster     # sesuaikan dengan folder kamu
"$GIT" status
"$GIT" push
```

Enak dibuatkan alias di `~/.bashrc`:

```bash
alias gitw='"/mnt/c/Program Files/Git/cmd/git.exe"'
```

Dua hal yang harus diingat saat memakai git Windows untuk repo yang juga
dibangun di Linux:

1. **Bit executable tidak terbaca** dari NTFS, jadi `gradlew` bisa ter-commit
   sebagai `100644` dan di Termux hasilnya `Permission denied`. Setel manual
   di index, sekali saja:
   ```bash
   "$GIT" update-index --chmod=+x gradlew
   "$GIT" ls-files -s gradlew        # harus 100755
   ```
2. **`core.autocrlf` default `true`** di Git for Windows. Sudah ditangani
   `.gitattributes` di repo ini (`* text=auto eol=lf`), dan di repo ini
   `core.autocrlf` juga sudah diset `false`. Jangan diubah.

Alternatif permanen kalau mau tetap pakai git Linux: aktifkan metadata di
`/etc/wsl.conf` lalu `wsl --shutdown` dari Windows.

```ini
[automount]
options = "metadata,umask=22,fmask=11"
```

### Configuration cache gagal diam-diam

Sudah dimatikan di `gradle.properties` repo (`org.gradle.configuration-cache=false`)
justru karena ini. Biarkan.

### `adb` Linux di WSL tidak melihat HP yang tertancap ke Windows

Memang begitu; USB tidak diteruskan ke WSL. Pakai `adb.exe` milik Windows:

```bash
ADB=$(ls /mnt/c/Users/*/AppData/Local/Android/Sdk/platform-tools/adb.exe | head -1)
"$ADB" devices
```

Karena itu `./gradlew connectedDebugAndroidTest` tidak bisa dipakai dari WSL.

---

## C. Berlaku di mana saja

### `SDK location not found`

Buat `local.properties`:

```bash
cp local.properties.example local.properties
echo "sdk.dir=$ANDROID_HOME" > local.properties
```

### `Failed to find Platform SDK with path: platforms;android-37.2` / compileSdk tidak tersedia

Pasang platform-nya:

```bash
sdkmanager "platforms;android-37.2" "build-tools;37.0.0"
sdkmanager --list_installed
```

Kalau API 37 benar-benar belum tersedia di `sdkmanager` kamu, **boleh**
diturunkan — tapi sadari ini mengubah file repo, jadi lakukan sengaja dan
commit dengan pesan yang jelas. Di `app/build.gradle.kts`:

```kotlin
  compileSdk = 36        // DSL lama, satu angka, tanpa minor API level
  defaultConfig {
    targetSdk = 36
  }
```

Hapus baris `compileSdk { version = release(37) { ... } }` saat memakai bentuk
itu. `minSdk = 26` tidak perlu diubah.

### `Unsupported class file major version` / `Gradle requires JVM 17`

JDK terlalu tua. AGP 9.x minimal JDK 17.

```bash
java -version
# arahkan ke JDK yang benar, di ~/.gradle/gradle.properties (bukan di repo):
#   org.gradle.java.home=/usr/lib/jvm/java-21-openjdk-arm64
```

### `Could not resolve all files for configuration ':app:...'`

Tidak ada koneksi ke Maven, atau cache rusak.

```bash
./gradlew assembleDebug --refresh-dependencies
```

Kalau di jaringan yang butuh proxy, setelan proxy ditulis di
`~/.gradle/gradle.properties` — **jangan** di repo, karena isinya kredensial.

### Hasil build terasa basi atau tidak konsisten

```bash
./gradlew clean
./gradlew --stop
rm -rf .gradle .kotlin        # aman, hanya cache lokal proyek
```

### `License for package ... not accepted`

```bash
yes | sdkmanager --licenses
```

### Mencari akar masalah secara umum

```bash
./gradlew assembleDebug --stacktrace      # lihat exception aslinya
./gradlew assembleDebug --info            # lebih berisik
./gradlew assembleDebug --debug           # terakhir, sangat berisik
```

Baca error **paling atas**, bukan paling bawah. Baris paling bawah biasanya
cuma "build failed", sedangkan sebabnya ada di atas.
