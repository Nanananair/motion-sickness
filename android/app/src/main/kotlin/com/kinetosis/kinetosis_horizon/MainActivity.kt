package com.kinetosis.kinetosis_horizon

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.kinetosis.kinetosis_horizon.overlay.OverlayPrefs
import com.kinetosis.kinetosis_horizon.overlay.OverlayService
import com.kinetosis.kinetosis_horizon.overlay.OverlaySettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Flutter side is only a control panel. Everything that has to keep running once the user
 * leaves for another app lives in [OverlayService].
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))

            "requestOverlayPermission" -> {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName"),
                    ),
                )
                result.success(null)
            }

            "canPostNotifications" -> result.success(canPostNotifications())

            "requestNotificationPermission" -> {
                requestNotificationPermission()
                result.success(null)
            }

            "openAppSettings" -> {
                startActivity(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName"),
                    ),
                )
                result.success(null)
            }

            "isRunning" -> result.success(OverlayPrefs.isRunning(this))

            "readSettings" -> result.success(OverlayPrefs.read(this).toMap())

            "updateSettings" -> {
                OverlayPrefs.write(this, settingsFrom(call))
                if (OverlayPrefs.isRunning(this)) {
                    startService(overlayIntent(OverlayService.ACTION_SETTINGS_CHANGED))
                }
                result.success(null)
            }

            "start" -> {
                if (!Settings.canDrawOverlays(this)) {
                    result.error(
                        "permission_denied",
                        "Display over other apps has not been granted.",
                        null,
                    )
                    return
                }
                val intent = overlayIntent(OverlayService.ACTION_START)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                result.success(true)
            }

            "stop" -> {
                stopService(Intent(this, OverlayService::class.java))
                OverlayPrefs.setRunning(this, false)
                result.success(false)
            }

            else -> result.notImplemented()
        }
    }

    private fun overlayIntent(action: String): Intent =
        Intent(this, OverlayService::class.java).setAction(action)

    private fun canPostNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    private fun settingsFrom(call: MethodCall): OverlaySettings {
        val defaults = OverlaySettings.defaults
        return OverlaySettings(
            dotCount = call.argument<Int>("dotCount") ?: defaults.dotCount,
            sensitivity = call.argument<Double>("sensitivity")?.toFloat() ?: defaults.sensitivity,
            dotSize = call.argument<Double>("dotSize")?.toFloat() ?: defaults.dotSize,
            opacity = call.argument<Double>("opacity")?.toFloat() ?: defaults.opacity,
        )
    }

    private fun OverlaySettings.toMap(): Map<String, Any> = mapOf(
        "dotCount" to dotCount,
        "sensitivity" to sensitivity.toDouble(),
        "dotSize" to dotSize.toDouble(),
        "opacity" to opacity.toDouble(),
    )

    private companion object {
        const val CHANNEL = "com.kinetosis.kinetosis_horizon/overlay"
        const val NOTIFICATION_PERMISSION_REQUEST = 7001
    }
}
