package id.sepultura.masterandroid

/**
 * Kotlin murni, tanpa `android.*`, supaya bisa diuji unit test JVM.
 * Unit test JVM adalah cara tercepat memverifikasi build di HP karena
 * tidak butuh aapt2/d8 maupun perangkat tersambung.
 */
object Greeting {
  const val TEXT: String = "Hello Apps"

  fun greet(name: String): String = if (name.isBlank()) TEXT else "Hello $name"
}
