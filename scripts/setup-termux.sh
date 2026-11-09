#!/bin/bash
# Menyiapkan HP (Termux + Debian proot, aarch64) supaya repo ini bisa di-build.
#
# Jalankan SEKALI setelah clone, dari mana saja:
#   bash scripts/setup-termux.sh
#
# Skrip ini aman diulang. Semua yang ditulisnya ada DI LUAR repo
# (~/android-sdk, ~/bin, ~/.gradle) kecuali local.properties yang di-ignore git,
# sesuai aturan di CLAUDE.md. Langkah manualnya: docs/TERMUX_DEBIAN_SETUP.md.
#
# Variabel yang bisa diubah sebelum menjalankan:
#   ANDROID_HOME   lokasi SDK (default ~/android-sdk)
#   CMDLINE_TOOLS_URL  zip cmdline-tools kalau sdkmanager belum ada

set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
SDK="${ANDROID_HOME:-$HOME/android-sdk}"
BIN="$HOME/bin"
GRADLE_PROPS="$HOME/.gradle/gradle.properties"
CMDLINE_TOOLS_URL="${CMDLINE_TOOLS_URL:-https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip}"
MAVEN="https://dl.google.com/android/maven2/com/android/tools/build/aapt2"

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
die() { echo "!! $*" >&2; exit 1; }

# Di proot user biasa butuh sudo untuk apt; sebagai root tidak.
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

# ---------------------------------------------------------------------------
step "1. Cek lingkungan"
arch=$(uname -m)
echo "arsitektur: $arch"
[ "$arch" = "aarch64" ] || die "Skrip ini untuk HP (aarch64). Di PC/WSL tidak perlu setup ini."

# ---------------------------------------------------------------------------
step "2. Paket sistem (JDK, box64, unzip, curl, adb)"
# box64 menerjemahkan binary x86_64 ke aarch64. Dibutuhkan karena aapt2 dari
# Google hanya tersedia x86_64, dan aapt2 arm64 bawaan Debian (paket `aapt`)
# terlalu tua untuk membaca android.jar API 37.x.
need=()
java -version 2>&1 | grep -qE 'version "(1[7-9]|[2-9][0-9])' || need+=(openjdk-21-jdk-headless)
for p in box64 unzip curl adb git; do
  command -v "$p" >/dev/null || need+=("$p")
done
if [ ${#need[@]} -gt 0 ]; then
  echo "memasang: ${need[*]}"
  $SUDO apt-get update
  $SUDO apt-get install -y "${need[@]}"
else
  echo "semua sudah terpasang"
fi
java -version 2>&1 | head -1
box64 --version 2>/dev/null | head -1 || true

# ---------------------------------------------------------------------------
step "3. Android SDK di $SDK"
SDKMANAGER=$(ls "$SDK"/cmdline-tools/*/bin/sdkmanager 2>/dev/null | head -1 || true)
if [ -z "$SDKMANAGER" ]; then
  echo "sdkmanager belum ada, mengunduh cmdline-tools"
  tmp=$(mktemp -d)
  curl -fL --progress-bar -o "$tmp/cmdline-tools.zip" "$CMDLINE_TOOLS_URL"
  unzip -q "$tmp/cmdline-tools.zip" -d "$tmp"
  mkdir -p "$SDK/cmdline-tools"
  rm -rf "$SDK/cmdline-tools/latest"
  mv "$tmp/cmdline-tools" "$SDK/cmdline-tools/latest"
  rm -rf "$tmp"
  SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"
fi

# Platform dibaca dari build.gradle.kts supaya skrip ikut benar kalau
# compileSdk diganti. Pola yang dikenali: release(37) { minorApiLevel = 2 }
gradle_kts="$REPO/app/build.gradle.kts"
api=$(grep -oP 'release\(\K[0-9]+' "$gradle_kts" | head -1 || true)
minor=$(grep -oP 'minorApiLevel\s*=\s*\K[0-9]+' "$gradle_kts" | head -1 || true)
[ -n "$api" ] || api=$(grep -oP 'compileSdk\s*=\s*\K[0-9]+' "$gradle_kts" | head -1 || true)
[ -n "$api" ] || die "compileSdk tidak terbaca dari $gradle_kts"
platform="android-$api${minor:+.$minor}"
echo "platform yang dibutuhkan: $platform"

# Lisensi harus diterima, kalau tidak AGP gagal saat mengunduh build-tools
# sendiri di build pertama. build-tools tidak dipasang di sini: AGP memilih
# dan mengunduh versinya sendiri.
yes | "$SDKMANAGER" --sdk_root="$SDK" --licenses >/dev/null 2>&1 || true
if [ ! -d "$SDK/platforms/$platform" ]; then
  yes | "$SDKMANAGER" --sdk_root="$SDK" "platforms;$platform" >/dev/null
fi
ls -d "$SDK/platforms/$platform" >/dev/null || die "gagal memasang platforms;$platform"
echo "OK: $SDK/platforms/$platform"

# ---------------------------------------------------------------------------
step "4. aapt2 x86_64 + pembungkus box64"
agp=$(grep -oP '^agp\s*=\s*"\K[^"]+' "$REPO/gradle/libs.versions.toml")
[ -n "$agp" ] || die "versi agp tidak terbaca dari gradle/libs.versions.toml"
# Nomor build aapt2 (mis. 9.4.1-15978811) tidak bisa ditebak dari versi AGP,
# jadi diambil dari metadata Maven Google.
aapt2_ver=$(curl -fsSL "$MAVEN/maven-metadata.xml" | grep -oP "<version>\K$agp-[0-9]+(?=</version>)" | tail -1)
[ -n "$aapt2_ver" ] || die "aapt2 untuk AGP $agp tidak ditemukan di Maven Google"
echo "AGP $agp -> aapt2 $aapt2_ver"

aapt2_dir="$BIN/aapt2-$aapt2_ver-linux"
if [ ! -x "$aapt2_dir/aapt2" ]; then
  mkdir -p "$aapt2_dir"
  curl -fsSL -o "$aapt2_dir/aapt2.jar" "$MAVEN/$aapt2_ver/aapt2-$aapt2_ver-linux.jar"
  unzip -oq "$aapt2_dir/aapt2.jar" aapt2 -d "$aapt2_dir"
  rm -f "$aapt2_dir/aapt2.jar"
  chmod +x "$aapt2_dir/aapt2"
fi

# box64 menulis peringatan "Symbol nftw not found" ke STDOUT setiap kali jalan.
# AGP memakai aapt2 dalam mode daemon dan menganggap baris asing di stdout
# sebagai error, jadi baris [BOX64] disaring dari stdout maupun stderr.
cat > "$BIN/aapt2" <<EOF
#!/bin/bash
# Dibuat oleh scripts/setup-termux.sh -- aapt2 $aapt2_ver (x86_64) lewat box64.
export BOX64_LOG=0 BOX64_NOBANNER=1
exec /usr/bin/box64 "$aapt2_dir/aapt2" "\$@" \\
  > >(grep --line-buffered -v "BOX64") 2> >(grep --line-buffered -v "BOX64" >&2)
EOF
chmod +x "$BIN/aapt2"
"$BIN/aapt2" version || die "aapt2 lewat box64 tidak mau jalan"

# ---------------------------------------------------------------------------
step "5. ~/.gradle/gradle.properties (setelan khusus HP)"
mkdir -p "$(dirname "$GRADLE_PROPS")"
touch "$GRADLE_PROPS"
# Nilai yang sudah ada TIDAK ditimpa (bisa jadi sengaja diubah pemilik HP),
# kecuali override aapt2 yang harus menunjuk ke pembungkus di atas.
set_default() {
  grep -qE "^$1=" "$GRADLE_PROPS" || echo "$1=$2" >> "$GRADLE_PROPS"
}
set_default org.gradle.jvmargs "-Xmx1536m -XX:MaxMetaspaceSize=512m -Dfile.encoding=UTF-8"
set_default org.gradle.parallel false
set_default org.gradle.workers.max 2
set_default org.gradle.vfs.watch false
set_default org.gradle.caching true
set_default org.gradle.configuration-cache false
set_default org.gradle.daemon true
set_default kotlin.compiler.execution.strategy in-process
sed -i '/^#\? *android.aapt2FromMavenOverride=/d' "$GRADLE_PROPS"
echo "android.aapt2FromMavenOverride=$BIN/aapt2" >> "$GRADLE_PROPS"
cat "$GRADLE_PROPS"

# ---------------------------------------------------------------------------
step "6. local.properties"
echo "sdk.dir=$SDK" > "$REPO/local.properties"
cat "$REPO/local.properties"

# ---------------------------------------------------------------------------
step "7. Perintah install-hp"
chmod +x "$REPO/scripts/install-hp" "$REPO/gradlew"
ln -sf "$REPO/scripts/install-hp" "$BIN/install-hp"
echo "OK: $BIN/install-hp -> $REPO/scripts/install-hp"

# ---------------------------------------------------------------------------
step "Selesai"
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "~/bin belum ada di PATH. Tambahkan sekali:"
     echo "  echo 'export PATH=\"\$HOME/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc" ;;
esac
echo
echo "Langkah berikutnya:"
echo "  install-hp --build_only     # build pertama 15-40 menit (unduh dependency)"
echo "  install-hp --toHP           # pasang ke HP lewat adb"
