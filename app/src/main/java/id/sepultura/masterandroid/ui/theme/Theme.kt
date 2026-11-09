package id.sepultura.masterandroid.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

// Tanpa dynamic color dan tanpa dark theme supaya tampilan sama di semua HP.
// Mau dark theme? Tambahkan darkColorScheme() dan isSystemInDarkTheme().
private val LightColorScheme =
  lightColorScheme(
    primary = PrimaryBlue,
    secondary = SecondaryTeal,
    tertiary = AccentCyan,
    background = BackgroundGrey,
    surface = SurfaceWhite,
    outline = OutlineGrey,
    error = ErrorRed,
  )

@Composable
fun MasterAndroidTheme(content: @Composable () -> Unit) {
  MaterialTheme(colorScheme = LightColorScheme, typography = Typography, content = content)
}
