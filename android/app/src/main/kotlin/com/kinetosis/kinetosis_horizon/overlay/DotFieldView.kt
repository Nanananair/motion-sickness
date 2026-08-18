package com.kinetosis.kinetosis_horizon.overlay

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.Choreographer
import android.view.Surface
import android.view.View
import kotlin.math.roundToInt

/**
 * The overlay's only content: rings of light floating over whatever app is on screen.
 *
 * The view is transparent and never touchable — the window flags in [OverlayService] see to the
 * touch side, this class only draws.
 */
@SuppressLint("ViewConstructor")
class DotFieldView(
    context: Context,
    private val motion: MotionEngine,
    initialSettings: OverlaySettings,
) : View(context) {

    private val field = DotField()
    private val density = resources.displayMetrics.density

    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }

    private var settings: OverlaySettings = initialSettings.sanitised()
    private var lastFrameNanos = 0L
    private var running = false

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (!running) return
            val dt = if (lastFrameNanos == 0L) {
                0f
            } else {
                (frameTimeNanos - lastFrameNanos) / 1_000_000_000f
            }
            lastFrameNanos = frameTimeNanos
            advance(dt)
            invalidate()
            Choreographer.getInstance().postFrameCallback(this)
        }
    }

    init {
        setBackgroundColor(Color.TRANSPARENT)
        setLayerType(LAYER_TYPE_HARDWARE, null)
        field.reseed(settings.dotCount)
    }

    fun applySettings(next: OverlaySettings) {
        settings = next.sanitised()
        field.reseed(settings.dotCount)
        invalidate()
    }

    fun resume() {
        if (running) return
        running = true
        lastFrameNanos = 0L
        Choreographer.getInstance().postFrameCallback(frameCallback)
    }

    fun pause() {
        if (!running) return
        running = false
        Choreographer.getInstance().removeFrameCallback(frameCallback)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        syncDisplayRotation()
        resume()
    }

    override fun onDetachedFromWindow() {
        pause()
        super.onDetachedFromWindow()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        syncDisplayRotation()
        // The field is expressed in normalised coordinates, so a resize only invalidates the
        // in-flight spring offsets, which were pixels of the old geometry.
        field.recentre()
    }

    fun syncDisplayRotation() {
        motion.displayRotation = display?.rotation ?: Surface.ROTATION_0
    }

    private fun advance(dt: Float) {
        // Dots drift *against* the acceleration: the vehicle pushes you forward, the world outside
        // slides back. Signs match the in-app painter in lib/widgets/dot_field_painter.dart.
        val scale = PIXELS_PER_ACCELERATION_UNIT * settings.sensitivity * density
        field.step(dt, -motion.sway * scale, motion.surge * scale)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0f || h <= 0f) return

        val spanX = w * (1f + 2f * DotField.MARGIN)
        val spanY = h * (1f + 2f * DotField.MARGIN)
        val originX = -w * DotField.MARGIN
        val originY = -h * DotField.MARGIN
        val baseRadius = BASE_RADIUS_DP * settings.dotSize * density

        canvas.save()
        // Counter-rotate the whole field so it stays level with the earth while the phone tilts.
        canvas.rotate(-Math.toDegrees(motion.roll.toDouble()).toFloat(), w / 2f, h / 2f)

        for (dot in field.dots) {
            val x = wrap(dot.homeX * w + dot.offsetX, originX, spanX)
            val y = wrap(dot.homeY * h + dot.offsetY, originY, spanY)

            val radius = baseRadius / dot.depth
            // Near dots read brighter, far dots recede.
            val depthAlpha = 0.5f + 0.5f * (1f - dot.depth)
            val fillAlpha = settings.opacity * depthAlpha * FILL_ALPHA_SCALE
            val ringAlpha = settings.opacity * depthAlpha

            fillPaint.color = whiteWithAlpha(fillAlpha)
            canvas.drawCircle(x, y, radius, fillPaint)

            ringPaint.color = whiteWithAlpha(ringAlpha)
            ringPaint.strokeWidth = (radius * RING_WIDTH_RATIO).coerceAtLeast(density)
            canvas.drawCircle(x, y, radius, ringPaint)
        }

        canvas.restore()
    }

    private companion object {
        /**
         * Pixels of drift per m/s^2, at unit depth and unit sensitivity. Carried over from
         * `dotSensitivity` in lib/widgets/horizon_painter.dart, where it was tuned on the road.
         */
        const val PIXELS_PER_ACCELERATION_UNIT = 28f
        const val BASE_RADIUS_DP = 3.2f
        const val RING_WIDTH_RATIO = 0.35f

        /** The disc sits behind the ring, so it has to be dimmer or the dot turns into a blob. */
        const val FILL_ALPHA_SCALE = 0.45f

        fun whiteWithAlpha(alpha: Float): Int =
            Color.argb((alpha.coerceIn(0f, 1f) * 255f).roundToInt(), 255, 255, 255)

        /** Keeps a dot inside the field even under sustained acceleration. */
        fun wrap(value: Float, origin: Float, span: Float): Float {
            if (span <= 0f) return value
            var offset = (value - origin) % span
            if (offset < 0f) offset += span
            return origin + offset
        }
    }
}
