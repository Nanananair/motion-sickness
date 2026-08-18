package com.kinetosis.kinetosis_horizon.overlay

import kotlin.math.sqrt
import kotlin.random.Random

/**
 * A field of dots sitting at varying depths.
 *
 * Depth is what sells the effect: a near dot is drawn larger *and* displaced further than a far
 * one, so the field reads as a world outside the car rather than as decoration painted on the
 * glass. Each dot chases its displaced target through a critically damped spring, which turns
 * noisy sensor input into a glide that settles instead of a jitter.
 */
class DotField(private val seed: Int = 42) {

    class Dot(
        /** Home position in normalised field space, spanning [-MARGIN, 1 + MARGIN]. */
        val homeX: Float,
        val homeY: Float,
        /** 0.35 (near) .. 1.0 (far). */
        val depth: Float,
    ) {
        var offsetX = 0f
        var offsetY = 0f
        var velocityX = 0f
        var velocityY = 0f
    }

    var dots: List<Dot> = emptyList()
        private set

    private var seededCount = -1

    /**
     * Seeds [count] dots, deterministically, over a field wider than the screen. The margin keeps
     * the corners populated once the whole field counter-rotates against the device's roll.
     */
    fun reseed(count: Int) {
        if (count == seededCount) return
        seededCount = count
        val rng = Random(seed)
        val span = 1f + 2f * MARGIN
        dots = List(count) {
            Dot(
                homeX = -MARGIN + rng.nextFloat() * span,
                homeY = -MARGIN + rng.nextFloat() * span,
                depth = MIN_DEPTH + rng.nextFloat() * (1f - MIN_DEPTH),
            )
        }
    }

    /**
     * Advances the spring by [dtSeconds] towards a displacement of ([targetX], [targetY]) pixels
     * at unit depth.
     */
    fun step(dtSeconds: Float, targetX: Float, targetY: Float) {
        // A dropped frame must not launch the dots across the screen.
        val dt = dtSeconds.coerceIn(0f, MAX_STEP_SECONDS)
        if (dt <= 0f) return
        for (dot in dots) {
            val tx = targetX / dot.depth
            val ty = targetY / dot.depth
            dot.velocityX += ((tx - dot.offsetX) * STIFFNESS - dot.velocityX * DAMPING) * dt
            dot.velocityY += ((ty - dot.offsetY) * STIFFNESS - dot.velocityY * DAMPING) * dt
            dot.offsetX += dot.velocityX * dt
            dot.offsetY += dot.velocityY * dt
        }
    }

    fun recentre() {
        for (dot in dots) {
            dot.offsetX = 0f
            dot.offsetY = 0f
            dot.velocityX = 0f
            dot.velocityY = 0f
        }
    }

    companion object {
        /** Fraction of the screen the field extends past each edge. */
        const val MARGIN = 0.25f

        const val MIN_DEPTH = 0.35f

        private const val STIFFNESS = 26f
        private val DAMPING = 2f * sqrt(STIFFNESS)
        private const val MAX_STEP_SECONDS = 0.05f
    }
}
