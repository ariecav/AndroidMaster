plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.kotlin.compose)
}

android {
  namespace = "id.sepultura.masterandroid"

  // DSL compileSdk gaya AGP 9.x. Butuh platform android-37.2 terpasang
  // di SDK. Kalau SDK di HP tidak punya API 37, lihat docs/TROUBLESHOOTING.md
  // bagian "compileSdk tidak tersedia".
  compileSdk { version = release(37) { minorApiLevel = 2 } }

  defaultConfig {
    applicationId = "id.sepultura.masterandroid"
    minSdk = 26
    targetSdk = 37
    versionCode = 1
    versionName = "1.0"

    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
  }

  buildTypes {
    release {
      isMinifyEnabled = false
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
  }

  buildFeatures {
    compose = true
    buildConfig = true
  }

  testOptions {
    unitTests { isReturnDefaultValues = true }
  }

  packaging {
    resources.excludes += setOf("/META-INF/{AL2.0,LGPL2.1}")
  }
}

dependencies {
  // --- Compose / AndroidX ---
  implementation(platform(libs.androidx.compose.bom))
  implementation(libs.androidx.core.ktx)
  implementation(libs.androidx.activity.compose)
  implementation(libs.androidx.compose.ui)
  implementation(libs.androidx.compose.ui.graphics)
  implementation(libs.androidx.compose.ui.tooling.preview)
  implementation(libs.androidx.compose.material3)
  implementation(libs.androidx.lifecycle.runtime.ktx)
  implementation(libs.androidx.lifecycle.runtime.compose)
  implementation(libs.androidx.lifecycle.viewmodel.compose)

  // --- Unit test (JVM, jalan tanpa HP/emulator) ---
  testImplementation(libs.junit)

  // --- Instrumented test (butuh HP/emulator tersambung) ---
  androidTestImplementation(platform(libs.androidx.compose.bom))
  androidTestImplementation(libs.androidx.junit)
  androidTestImplementation(libs.androidx.espresso.core)
  androidTestImplementation(libs.androidx.compose.ui.test.junit4)

  // --- Tooling mode debug ---
  debugImplementation(libs.androidx.compose.ui.tooling)
  debugImplementation(libs.androidx.compose.ui.test.manifest)
}
