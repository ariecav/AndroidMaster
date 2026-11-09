package id.sepultura.masterandroid

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import id.sepultura.masterandroid.ui.theme.MasterAndroidTheme

/**
 * Satu-satunya Activity. Titik mula pengembangan aplikasi baru.
 *
 * Mau menambah layar? Dua pilihan:
 *  - tambah dependency `androidx.navigation:navigation-compose` lalu pakai
 *    NavHost di sini, atau
 *  - tambah Activity baru dan daftarkan di AndroidManifest.xml.
 */
class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge()
    setContent {
      MasterAndroidTheme {
        Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
          HelloScreen(modifier = Modifier.padding(innerPadding))
        }
      }
    }
  }
}

@Composable
fun HelloScreen(modifier: Modifier = Modifier) {
  Column(
    modifier = modifier.fillMaxSize().padding(24.dp),
    verticalArrangement = Arrangement.Center,
    horizontalAlignment = Alignment.CenterHorizontally,
  ) {
    Text(
      text = Greeting.TEXT,
      style = MaterialTheme.typography.headlineMedium,
      textAlign = TextAlign.Center,
    )
    Text(
      text = "Master_Android siap dipakai",
      style = MaterialTheme.typography.bodyLarge,
      textAlign = TextAlign.Center,
      modifier = Modifier.padding(top = 8.dp),
    )
  }
}

@Preview(showBackground = true)
@Composable
private fun HelloScreenPreview() {
  MasterAndroidTheme { HelloScreen() }
}
