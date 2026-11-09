// Build file tingkat atas: hanya mendaftarkan plugin, penerapannya di :app.
// Versi plugin diatur di gradle/libs.versions.toml.
plugins {
  alias(libs.plugins.android.application) apply false
  alias(libs.plugins.kotlin.compose) apply false
}
