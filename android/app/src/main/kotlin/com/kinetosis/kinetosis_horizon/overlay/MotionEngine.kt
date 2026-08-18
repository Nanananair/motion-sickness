package com.kinetosis.kinetosis_horizon.overlay

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import kotlin.math.atan2
import kotlin.math.sqrt

/**
 * Turns raw sensor traffic into the two things the dot field needs: how far the device is rolled
 * against gravity, and what the vehicle is doing in screen-space (surge = forward/back,
 * sway = left/right).
 *
 * The filter constants and the roll formula are the ones already tuned in
 * lib/services/sensor_service.dart, kept identical so the overlay and the in-app preview agree.
 */
class MotionEngine(context: Context) : SensorEventListener {

    private val sensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    private val gravitySensor = sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY)
    private val linearSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
    private val accelSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

    /** Cheap phones ship without the fused sensors; fall back to raw accelerometer for those. */
    private val needsAccelFallback = gravitySensor == null || linearSensor == null

    /** Roll in radians. Read from the render thread, written from the sensor thread. */
    @Volatile
    var roll: Float = 0f
        private set

    /** Screen-space linear acceleration, m/s^2. */
    @Volatile
    var sway: Float = 0f
        private set

    @Volatile
    var surge: Float = 0f
        private set

    /** Surface.ROTATION_*, kept current by the view as the display turns. */
    @Volatile
    var displayRotation: Int = Surface.ROTATION_0

    // Device-space state, all in sensor coordinates.
    private var gx = 0f
    private var gy = 0f
    private var gz = 9.81f
    private var ax = 0f
    private var ay = 0f

    private var listening = false

    fun start() {
        if (listening) return
        listening = true
        gravitySensor?.let { sensorManager.registerListener(this, it, SAMPLING_US) }
        linearSensor?.let { sensorManager.registerListener(this, it, SAMPLING_US) }
        if (needsAccelFallback) {
            accelSensor?.let { sensorManager.registerListener(this, it, SAMPLING_US) }
        }
    }

    fun stop() {
        if (!listening) return
        listening = false
        sensorManager.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_GRAVITY -> {
                gx = lowPass(gx, event.values[0], GRAVITY_ALPHA)
                gy = lowPass(gy, event.values[1], GRAVITY_ALPHA)
                gz = lowPass(gz, event.values[2], GRAVITY_ALPHA)
            }

            Sensor.TYPE_LINEAR_ACCELERATION -> {
                ax = lowPass(ax, event.values[0], LINEAR_ALPHA)
                ay = lowPass(ay, event.values[1], LINEAR_ALPHA)
            }

            Sensor.TYPE_ACCELEROMETER -> {
                if (gravitySensor == null) {
                    gx = lowPass(gx, event.values[0], GRAVITY_ALPHA)
                    gy = lowPass(gy, event.values[1], GRAVITY_ALPHA)
                    gz = lowPass(gz, event.values[2], GRAVITY_ALPHA)
                }
                if (linearSensor == null) {
                    // Whatever the low-pass did not attribute to gravity is the vehicle moving.
                    ax = lowPass(ax, event.values[0] - gx, LINEAR_ALPHA)
                    ay = lowPass(ay, event.values[1] - gy, LINEAR_ALPHA)
                }
            }

            else -> return
        }
        recompute()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun recompute() {
        val sgx: Float
        val sgy: Float
        val sax: Float
        val say: Float
        when (displayRotation) {
            Surface.ROTATION_90 -> {
                sgx = -gy; sgy = gx; sax = -ay; say = ax
            }

            Surface.ROTATION_180 -> {
                sgx = -gx; sgy = -gy; sax = -ax; say = -ay
            }

            Surface.ROTATION_270 -> {
                sgx = gy; sgy = -gx; sax = ay; say = -ax
            }

            else -> {
                sgx = gx; sgy = gy; sax = ax; say = ay
            }
        }
        roll = atan2(sgx, sqrt(sgy * sgy + gz * gz))
        sway = sax
        surge = say
    }

    private companion object {
        const val GRAVITY_ALPHA = 0.10f
        const val LINEAR_ALPHA = 0.25f

        /** ~50 Hz. Matches SensorInterval.gameInterval used by the Dart side. */
        const val SAMPLING_US = SensorManager.SENSOR_DELAY_GAME

        fun lowPass(prev: Float, raw: Float, alpha: Float): Float =
            alpha * raw + (1f - alpha) * prev
    }
}
