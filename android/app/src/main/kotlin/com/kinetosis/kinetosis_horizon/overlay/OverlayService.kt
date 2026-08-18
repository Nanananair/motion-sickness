package com.kinetosis.kinetosis_horizon.overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import com.kinetosis.kinetosis_horizon.MainActivity
import com.kinetosis.kinetosis_horizon.R

/**
 * Owns the window that draws over other apps.
 *
 * This has to be a foreground service, not an activity: the whole point is that the cue survives
 * the user leaving for Photos, Maps or their messages.
 */
class OverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var view: DotFieldView? = null
    private var motion: MotionEngine? = null

    /**
     * Sensors and the vsync loop are the entire cost of running, and both are pointless with the
     * screen off — so a whole journey with the phone pocketed costs nothing.
     */
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    view?.pause()
                    motion?.stop()
                }

                Intent.ACTION_SCREEN_ON -> {
                    motion?.start()
                    view?.resume()
                }
            }
        }
    }

    private var receiverRegistered = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Must happen before anything else can throw, or the system kills us for not posting.
        startForegroundNotification()

        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        if (!Settings.canDrawOverlays(this)) {
            // Permission was revoked while we were away.
            stopSelf()
            return START_NOT_STICKY
        }

        // Every path attaches, including a settings change: if the process was killed and
        // restarted, the running flag can outlive the window, and applying settings to nothing
        // would leave an ongoing notification claiming a cue that is not on screen.
        attachOverlay()
        if (intent?.action == ACTION_SETTINGS_CHANGED) {
            view?.applySettings(OverlayPrefs.read(this))
        }
        return START_STICKY
    }

    private fun attachOverlay() {
        if (view != null) return

        val engine = MotionEngine(this)
        val overlay = DotFieldView(this, engine, OverlayPrefs.read(this))
        val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        try {
            manager.addView(overlay, buildLayoutParams())
        } catch (e: WindowManager.BadTokenException) {
            // Some OEM builds refuse the window even with the grant in place.
            stopSelf()
            return
        }

        motion = engine
        view = overlay
        windowManager = manager
        engine.start()

        registerScreenReceiver()
        OverlayPrefs.setRunning(this, true)
    }

    private fun buildLayoutParams(): WindowManager.LayoutParams {
        @Suppress("DEPRECATION")
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            // NOT_TOUCHABLE is what makes the dots draw over the app underneath without
            // swallowing a single tap. NO_LIMITS lets the field reach the status bar and notch.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT,
        )
        params.gravity = Gravity.TOP or Gravity.START
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            params.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        }
        return params
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        view?.syncDisplayRotation()
    }

    override fun onDestroy() {
        unregisterScreenReceiver()
        motion?.stop()
        motion = null
        view?.let { overlay ->
            overlay.pause()
            try {
                windowManager?.removeView(overlay)
            } catch (e: IllegalArgumentException) {
                // Already detached; nothing to undo.
            }
        }
        view = null
        windowManager = null
        OverlayPrefs.setRunning(this, false)
        super.onDestroy()
    }

    private fun registerScreenReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        registerReceiver(screenReceiver, filter)
        receiverRegistered = true
    }

    private fun unregisterScreenReceiver() {
        if (!receiverRegistered) return
        unregisterReceiver(screenReceiver)
        receiverRegistered = false
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.overlay_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.overlay_channel_description)
            setShowBadge(false)
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun startForegroundNotification() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            pendingFlags,
        )

        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, OverlayService::class.java).setAction(ACTION_STOP),
            pendingFlags,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_overlay)
            .setContentTitle(getString(R.string.overlay_notification_title))
            .setContentText(getString(R.string.overlay_notification_text))
            .setContentIntent(contentIntent)
            .addAction(0, getString(R.string.overlay_notification_stop), stopIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }

    companion object {
        const val ACTION_START = "com.kinetosis.kinetosis_horizon.overlay.START"
        const val ACTION_STOP = "com.kinetosis.kinetosis_horizon.overlay.STOP"
        const val ACTION_SETTINGS_CHANGED =
            "com.kinetosis.kinetosis_horizon.overlay.SETTINGS_CHANGED"

        private const val CHANNEL_ID = "overlay"
        private const val NOTIFICATION_ID = 1
    }
}
