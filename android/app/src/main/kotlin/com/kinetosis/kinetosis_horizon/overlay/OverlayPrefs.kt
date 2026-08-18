package com.kinetosis.kinetosis_horizon.overlay

import android.content.Context

/**
 * Tuning knobs for the dot field.
 *
 * [sensitivity], [dotSize] and [opacity] are multipliers around a hand-tuned baseline rather than
 * absolute values, so the defaults stay meaningful if the baseline is ever retuned.
 */
data class OverlaySettings(
    val dotCount: Int,
    val sensitivity: Float,
    val dotSize: Float,
    val opacity: Float,
) {
    fun sanitised(): OverlaySettings = OverlaySettings(
        dotCount = dotCount.coerceIn(MIN_DOTS, MAX_DOTS),
        sensitivity = sensitivity.coerceIn(0.1f, 3f),
        dotSize = dotSize.coerceIn(0.4f, 3f),
        opacity = opacity.coerceIn(0.05f, 1f),
    )

    companion object {
        const val MIN_DOTS = 30
        const val MAX_DOTS = 200

        /** ~40 dots land on screen; the rest sit in the margin the field is seeded over. */
        val defaults = OverlaySettings(
            dotCount = 90,
            sensitivity = 1f,
            dotSize = 1f,
            opacity = 0.55f,
        )
    }
}

/**
 * Settings live in SharedPreferences rather than being pushed from Dart on demand: while the user
 * is in another app the Flutter engine is gone, so the service has to be able to read its own
 * configuration without asking anyone.
 */
object OverlayPrefs {
    private const val FILE = "kinetosis_overlay"
    private const val KEY_DOT_COUNT = "dotCount"
    private const val KEY_SENSITIVITY = "sensitivity"
    private const val KEY_DOT_SIZE = "dotSize"
    private const val KEY_OPACITY = "opacity"
    private const val KEY_RUNNING = "running"

    fun read(context: Context): OverlaySettings {
        val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        val d = OverlaySettings.defaults
        return OverlaySettings(
            dotCount = prefs.getInt(KEY_DOT_COUNT, d.dotCount),
            sensitivity = prefs.getFloat(KEY_SENSITIVITY, d.sensitivity),
            dotSize = prefs.getFloat(KEY_DOT_SIZE, d.dotSize),
            opacity = prefs.getFloat(KEY_OPACITY, d.opacity),
        ).sanitised()
    }

    fun write(context: Context, settings: OverlaySettings) {
        val clean = settings.sanitised()
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
            .putInt(KEY_DOT_COUNT, clean.dotCount)
            .putFloat(KEY_SENSITIVITY, clean.sensitivity)
            .putFloat(KEY_DOT_SIZE, clean.dotSize)
            .putFloat(KEY_OPACITY, clean.opacity)
            .apply()
    }

    fun isRunning(context: Context): Boolean =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getBoolean(KEY_RUNNING, false)

    fun setRunning(context: Context, running: Boolean) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_RUNNING, running)
            .apply()
    }
}
