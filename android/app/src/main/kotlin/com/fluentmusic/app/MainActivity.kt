package com.fluentmusic.app

import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    WindowCompat.setDecorFitsSystemWindows(getWindow(), false)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      splashScreen.setOnExitAnimationListener { splashScreenView -> splashScreenView.remove() }
    }

    super.onCreate(savedInstanceState)
  }

  override fun onResume() {
    super.onResume()
    applyHighRefreshRate()
  }

  /**
   * Asks the display for its highest supported refresh rate.
   *
   * This is a request, not a guarantee: OEMs may cap the app, and battery
   * saver keeps the panel at its default rate so playback does not burn the
   * battery. All calls are guarded because some vendor ROMs throw from
   * setFrameRate even on API 30+.
   */
  private fun applyHighRefreshRate() {
    val powerManager = getSystemService(POWER_SERVICE) as? PowerManager
    if (powerManager?.isPowerSaveMode == true) return

    val window = window ?: return
    val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      this.display
    } else {
      @Suppress("DEPRECATION")
      windowManager.defaultDisplay
    } ?: return

    val bestMode = currentDisplay.supportedModes.maxByOrNull { it.refreshRate }
      ?: return
    if (bestMode.refreshRate <= 60f) return

    runCatching {
      window.attributes = window.attributes.apply {
        preferredRefreshRate = bestMode.refreshRate
      }
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      runCatching {
        window.setFrameRate(
          bestMode.refreshRate,
          WindowManager.LayoutParams.FRAME_RATE_COMPATIBILITY_DEFAULT,
        )
      }
    }
  }
}
