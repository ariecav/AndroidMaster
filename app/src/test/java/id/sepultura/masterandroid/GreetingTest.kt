package id.sepultura.masterandroid

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit test JVM. Jalankan dengan `./gradlew testDebugUnitTest`.
 * Tidak butuh HP, emulator, aapt2, maupun d8 -- jadi ini cek kesehatan
 * build paling murah, termasuk di Termux.
 */
class GreetingTest {
  @Test
  fun teks_default_adalah_hello_apps() {
    assertEquals("Hello Apps", Greeting.TEXT)
  }

  @Test
  fun nama_kosong_jatuh_ke_teks_default() {
    assertEquals("Hello Apps", Greeting.greet("   "))
  }

  @Test
  fun nama_terisi_dipakai() {
    assertEquals("Hello Awan", Greeting.greet("Awan"))
  }
}
