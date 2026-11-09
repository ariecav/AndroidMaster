# Menjalankan Master_Android di Debian proot (Termux)

Panduan untuk **AI/agent maupun manusia** yang mengembangkan repo ini dari HP
Android. Ikuti urut; tiap langkah ada perintah verifikasinya. Jangan lanjut
sebelum verifikasi langkahnya lolos.

---

## 0. Yang paling penting, baca dulu

Membangun Android di HP gagal karena **satu** alasan utama, dan itu bukan soal
dependency, bukan soal versi Gradle:

> **`aapt2` dan `zipalign` dari Google adalah binary x86_64.** HP Android itu
> `aarch64`. Binary x86_64 **tidak bisa dijalankan** di aarch64 tanpa
> penerjemah.

Ini sudah diverifikasi langsung di SDK yang dipakai repo ini:

```
build-tools/37.0.0/aapt2     : ELF 64-bit, x86-64   <- TIDAK jalan di aarch64
build-tools/37.0.0/zipalign  : ELF 64-bit, x86-64   <- TIDAK jalan di aarch64
aapt2 dari Maven (AGP 9.4.1) : ELF 64-bit, x86-64   <- TIDAK jalan di aarch64
build-tools/37.0.0/d8        : skrip bash -> java   <- AMAN, jalan di mana saja
```

Kabar baiknya: semua yang lain berjalan di atas JVM dan **aman** di aarch64 —
Gradle, kompiler Kotlin, compiler plugin Compose, KSP, Hilt, R8/D8, apksigner,
lint. Jadi masalahnya sempit dan bisa diselesaikan: lihat **Langkah 5**.

Dan satu kesalahpahaman yang harus dibuang di awal:

> `./gradlew testDebugUnitTest` **juga butuh `aapt2`**, walaupun namanya "unit
> test JVM". Sebab kompilasi Kotlin memerlukan kelas `R` yang dihasilkan dari
> resource, dan yang menghasilkannya adalah `aapt2`. Tidak ada task Android
> yang bisa jalan tanpa `aapt2`. Selesaikan Langkah 5 lebih dulu.

---

## 1. Prasyarat dan verifikasi lingkungan

Jalankan **di dalam Debian proot**, lalu catat semua hasilnya sebelum lanjut:

```bash
uname -m                       # harus aarch64
cat /etc/os-release | head -2
java -version                  # WAJIB 17 atau lebih baru (AGP 9.x)
echo "ANDROID_HOME=$ANDROID_HOME"
echo "JAVA_HOME=$JAVA_HOME"
ls "$ANDROID_HOME/platforms"     # butuh android-37.2
ls "$ANDROID_HOME/build-tools"   # butuh 37.0.0
which git
df -h ~                        # sisakan minimal 6 GB
```

Yang harus ada:

| Komponen | Minimal | Cara pasang kalau belum ada |
|---|---|---|
| JDK | 17 (21 juga baik) | `apt install openjdk-21-jdk-headless` |
| Android SDK platform | `android-37.2` | `sdkmanager "platforms;android-37.2"` |
| Android build-tools | `37.0.0` | `sdkmanager "build-tools;37.0.0"` |
| git | apa saja | `apt install git` |
| RAM bebas | ~2 GB | tutup aplikasi lain, aktifkan swap |
| Ruang disk | ~6 GB | Gradle dist + cache Maven + build |

> `sdkmanager` itu skrip shell yang memanggil `java`, jadi dia **jalan normal**
> di aarch64. Yang tidak jalan hanya sebagian binary **hasil unduhannya**.

Supaya Termux tidak dibunuh Android saat build lama, jalankan ini di Termux
(bukan di dalam Debian): `termux-wake-lock`.

---

## 2. Di mana repo harus ditaruh

**Taruh di filesystem Linux milik Debian proot**, misalnya `~/projects/`.

```bash
mkdir -p ~/projects && cd ~/projects
```

**JANGAN** menaruh repo di `/sdcard`, `/storage/emulated/0`, atau folder
share Termux mana pun. Penyimpanan itu FUSE/sdcardfs: tidak mendukung symlink,
hard link, dan bit permission. Gradle dan AGP memakai ketiganya, jadi build akan
gagal dengan error yang menyesatkan seperti `Operation not permitted`,
`Failed to create parent directories`, atau file lock yang tidak pernah lepas.

Ini masalah yang sama bentuknya dengan `/mnt/d` di WSL, hanya lebih parah.

---

## 3. Clone dan buat `local.properties`

```bash
cd ~/projects
git clone https://github.com/NAMA_KAMU/Master_Android.git
cd Master_Android

# wrapper harus bisa dieksekusi; bit ini kadang hilang saat clone
chmod +x gradlew

# beri tahu Gradle di mana SDK berada
cp local.properties.example local.properties
echo "sdk.dir=$ANDROID_HOME" > local.properties
cat local.properties
```

Verifikasi:

```bash
./gradlew --version
```

Harus muncul `Gradle 9.6.0`. Unduhan pertama distribusi Gradle sekitar 150 MB —
pakai Wi-Fi. `Launcher JVM` yang tampil harus 17+.

Kalau macet di `Downloading https://services.gradle.org/...`, itu murni soal
jaringan, bukan konfigurasi. Ulangi saja.

---

## 4. Setelan Gradle khusus HP

Setelan ini **tidak boleh** ditulis ke `gradle.properties` di dalam repo, karena
akan ikut ter-commit dan merusak build di PC. Tempatnya di
`~/.gradle/gradle.properties`, di luar repo.

```bash
mkdir -p ~/.gradle
cat > ~/.gradle/gradle.properties <<'EOF'
# ---- Setelan khusus HP (Termux + Debian proot, aarch64) ----
# Heap kecil: HP tidak punya 4 GB bebas untuk satu daemon JVM.
org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=512m -Dfile.encoding=UTF-8

# Build serial. Paralel di HP justru memperlambat dan memicu OOM-kill.
org.gradle.parallel=false
org.gradle.workers.max=2

# File watching dimatikan: inotify di dalam proot tidak bisa diandalkan.
org.gradle.vfs.watch=false

org.gradle.caching=true
org.gradle.configuration-cache=false
org.gradle.daemon=true

# Kompilasi Kotlin di dalam proses Gradle, bukan daemon terpisah.
# Mencegah "Could not connect to Kotlin compile daemon" dan hemat memori.
kotlin.compiler.execution.strategy=in-process

# Lihat Langkah 5. Baris ini WAJIB di aarch64, isi path-nya nanti.
# android.aapt2FromMavenOverride=/root/bin/aapt2
EOF
```

Yang **tidak boleh** ditiru dari setelan PC: `org.gradle.java.home` (path JDK
beda), dan semua `systemProp.http*.proxy*` (berisi kredensial dan hanya berlaku
di jaringan kantor).

---

## 5. Menyelesaikan masalah `aapt2` di aarch64

Ini inti seluruh panduan. Ada tiga jalur. Coba **A**, kalau gagal **B**, dan
**C** adalah jaring pengaman yang selalu berhasil.

### Jalur A — pakai `aapt2` native aarch64 dari repo Termux

Paling murah kalau tersedia, karena tidak ada lapisan emulasi.

Jalankan **di Termux, bukan di dalam Debian**:

```bash
pkg update
pkg search aapt2
pkg install aapt2        # kalau paketnya ada
command -v aapt2
aapt2 version
```

Jebakannya: binary Termux ditaut ke dynamic loader milik Termux di
`/data/data/com.termux/files/usr/lib`, yang **tidak ada** di dalam Debian proot.
Jadi `aapt2` Termux belum tentu bisa dipanggil dari Debian. Buktikan dulu —
dari dalam **Debian proot**, jalankan:

```bash
/data/data/com.termux/files/usr/bin/aapt2 version
```

- **Keluar nomor versi** → bisa dipakai. Arahkan AGP ke sana:
  ```bash
  sed -i 's|^# android.aapt2FromMavenOverride=.*|android.aapt2FromMavenOverride=/data/data/com.termux/files/usr/bin/aapt2|' ~/.gradle/gradle.properties
  ```
- **`No such file or directory` padahal file-nya ada** → itu loader yang hilang,
  bukan file-nya. Lanjut ke Jalur B.
- **Paket `aapt2` tidak ada di repo** → lanjut Jalur B.

Catatan jujur: `aapt2` dari Termux biasanya versi lebih tua daripada yang
diminta AGP 9.4.1. Kalau versinya terlalu jauh, AGP menolak dengan keluhan
protokol daemon `aapt2`. Kalau itu terjadi, Jalur B lagi.

### Jalur B — jalankan `aapt2` x86_64 lewat box64

`box64` menerjemahkan binary x86_64 ke aarch64. Caranya: bungkus `aapt2` asli
dengan skrip, lalu arahkan AGP ke skrip itu.

1. Pasang box64 di Termux (dari TUR):

```bash
pkg install tur-repo
pkg install box64
box64 --version
```

Di dalam Debian proot, alternatifnya `apt install qemu-user-static` lalu pakai
`qemu-x86_64-static` sebagai pengganti `box64` di skrip di bawah. Perlu
diketahui: **`binfmt_misc` tidak tersedia di dalam proot** (tidak ada akses
tulis ke `/proc/sys/fs/binfmt_misc`), jadi penerjemah tidak bisa dipanggil
otomatis. Karena itu pembungkus eksplisit seperti di bawah bukan pilihan gaya,
tapi satu-satunya cara.

2. Pancing AGP mengunduh `aapt2` x86_64-nya, lalu temukan file-nya:

```bash
cd ~/projects/Master_Android
./gradlew :app:processDebugResources || true     # boleh gagal, tujuannya unduh
find ~/.gradle/caches -type f -name aapt2 -path '*aapt2-*-linux*' | head
```

Untuk AGP 9.4.1 artifact-nya `com.android.tools.build:aapt2:9.4.1-15978811:linux`
dan file hasil ekstraknya bernama `.../aapt2-9.4.1-15978811-linux/aapt2`.
Periksa arsitekturnya untuk memastikan: `file <path tadi>` harus menyebut
`x86-64`.

3. Buat pembungkusnya:

```bash
AAPT2_X86=$(find ~/.gradle/caches -type f -name aapt2 -path '*aapt2-*-linux*' | head -1)
mkdir -p ~/bin
cat > ~/bin/aapt2 <<EOF
#!/bin/sh
# aapt2 asli adalah x86_64; box64 menerjemahkannya ke aarch64.
# "\$@" dan stdin diteruskan apa adanya karena AGP memakai mode daemon.
exec /data/data/com.termux/files/usr/bin/box64 "$AAPT2_X86" "\$@"
EOF
chmod +x ~/bin/aapt2
~/bin/aapt2 version        # harus keluar nomor versi, bukan Exec format error
```

4. Arahkan AGP ke pembungkus itu:

```bash
sed -i "s|^# android.aapt2FromMavenOverride=.*|android.aapt2FromMavenOverride=$HOME/bin/aapt2|" ~/.gradle/gradle.properties
grep aapt2 ~/.gradle/gradle.properties
```

### Jalur C — jaring pengaman: HP untuk ngoding, PC untuk APK

Kalau A dan B dua-duanya gagal, **jangan buang waktu** dan jangan ubah kode
repo untuk mengakalinya. Yang masih bisa dikerjakan penuh di HP:

- menulis dan membaca kode, refactor, git commit/push,
- memeriksa sintaks Kotlin dengan `kotlinc` secara terpisah,
- menjalankan logika Kotlin murni (seperti `Greeting.kt`) langsung lewat
  `kotlinc -script` atau `kotlin` REPL — tanpa Gradle, tanpa `aapt2`.

Yang pindah ke PC: `./gradlew assembleDebug` dan seluruh test Gradle. Alurnya
jadi: ngoding di HP → `git push` → PC `git pull` lalu build → APK dikirim
kembali ke HP. Tidak ideal, tapi jujur dan tetap produktif.

### Verifikasi Langkah 5

```bash
cd ~/projects/Master_Android
./gradlew :app:processDebugResources --rerun-tasks
```

`BUILD SUCCESSFUL` artinya hambatan terbesar sudah lewat.

---

## 6. Build

```bash
cd ~/projects/Master_Android

./gradlew testDebugUnitTest      # paling murah: 3 unit test, harus hijau
./gradlew assembleDebug          # APK debug
```

APK keluar di `app/build/outputs/apk/debug/app-debug.apk`.

Perkiraan waktu di HP: build pertama **15–40 menit** (mengunduh dependency dan
mengisi cache), build berikutnya 1–5 menit. Sabar, dan jangan dibatalkan di
tengah jalan — build yang dibunuh bisa meninggalkan cache rusak.

Kalau `assembleDebug` gagal di tahap `zipalign`, ingat `zipalign` juga x86_64:
bungkus dengan cara yang sama seperti `aapt2` di Jalur B lalu taruh
`~/bin` di depan `PATH`.

---

## 7. Memasang APK ke HP

### Cara paling sederhana: tanpa adb

Salin APK ke penyimpanan bersama lalu buka seperti file biasa:

```bash
cp app/build/outputs/apk/debug/app-debug.apk /sdcard/Download/
# lalu di Termux (bukan Debian):
termux-open /sdcard/Download/app-debug.apk
```

Android akan menampilkan dialog pemasangan. Izinkan "install dari sumber tidak
dikenal" untuk Termux sekali saja. Ini sudah cukup untuk siklus
ngoding-pasang-coba sehari-hari.

### Dengan adb ke HP itu sendiri (loopback)

Butuh **Wireless debugging** aktif di Opsi Pengembang. Jalankan di Termux:

```bash
pkg install android-tools        # adb build aarch64; adb dari SDK itu x86_64
# Opsi Pengembang -> Wireless debugging -> Pair device with pairing code
adb pair 127.0.0.1:<PORT_PAIRING> <KODE>
adb connect 127.0.0.1:<PORT_CONNECT>
adb devices
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n id.sepultura.masterandroid/.MainActivity
adb logcat --pid=$(adb shell pidof id.sepultura.masterandroid)
```

Dua port itu **berbeda** dan **berubah setiap kali** Wireless debugging
dinyalakan ulang. Baca dari layar Opsi Pengembang, jangan dihafal.

`adb` dari `$ANDROID_HOME/platform-tools` adalah binary x86_64, jadi pakai
`adb` milik paket `android-tools` Termux.

---

## 8. Alur kerja harian

```bash
cd ~/projects/Master_Android
git pull

# ... edit kode ...

./gradlew testDebugUnitTest          # cek cepat
./gradlew assembleDebug              # kalau mau dicoba di HP

git status                           # pastikan local.properties TIDAK muncul
git add -A
git commit -m "pesan yang jelas"
git push
```

Dua hal yang selalu dicek sebelum commit:

1. `local.properties` tidak ikut — isinya path SDK khas mesin ini.
2. `gradle.properties` di repo **tidak berubah**. Semua penyesuaian HP, termasuk
   `android.aapt2FromMavenOverride`, tempatnya di `~/.gradle/gradle.properties`.
   Kalau file repo ini berubah, kembalikan: `git checkout -- gradle.properties`.

Daemon Gradle memakan RAM dan tidak mati sendiri. Setelah selesai bekerja:

```bash
./gradlew --stop
```

---

## 9. Checklist untuk AI/agent

Sebelum menyentuh kode:

- [ ] `uname -m` → kalau `aarch64`, Langkah 5 sudah beres atau belum?
- [ ] `java -version` → 17 atau lebih?
- [ ] `local.properties` ada dan menunjuk SDK yang benar?
- [ ] Repo ada di filesystem Linux, **bukan** di `/sdcard`?
- [ ] `./gradlew --version` keluar `Gradle 9.6.0`?

Saat bekerja:

- [ ] Satu build Gradle saja pada satu waktu. Dua daemon di HP = OOM-kill.
- [ ] Build bisa makan puluhan menit. Jangan asumsikan gagal hanya karena lama,
      dan jangan jalankan ulang sambil yang pertama masih hidup.
- [ ] Error `Exec format error` / `No such file or directory` pada binary yang
      jelas-jelas ada = **masalah arsitektur**, bukan bug kode. Kembali ke
      Langkah 5. **Jangan** mengubah `build.gradle.kts`, menurunkan versi AGP,
      atau menghapus resource untuk "memperbaikinya".
- [ ] Laporkan kegagalan apa adanya, lengkap dengan pesan error aslinya.
