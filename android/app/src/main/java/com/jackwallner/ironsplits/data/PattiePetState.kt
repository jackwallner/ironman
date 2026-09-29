package com.jackwallner.ironsplits.data

import com.jackwallner.ironsplits.R

/**
 * The companion's poses. Each maps to one of the bundled portraits plus a small
 * looping motion; mapping is keyed on stable content ids, not hosted copy.
 */
enum class PattiePetState(val accessibilityName: String) {
    IDLE("ready"),
    COACH("thinking"),
    CELEBRATE("celebrating"),
    ENCOURAGE("encouraging"),
    SHOES("talking about shoes"),
    SWIM("talking about swimming"),
    BIKE("talking about the bike"),
    RUN("running"),
    TRANSITION("in transition"),
    FINISH("finishing"),
    DANCE("dancing"),
    WARMUP("warming up"),
    HYDRATE("hydrating"),
    STRETCH("stretching"),
    RECOVERY("recovering");

    data class MotionProfile(val rotationDegrees: Double, val horizontalShift: Double, val verticalLift: Double, val duration: Double)

    data class MotionFrame(
        val imageRes: Int,
        val horizontalShift: Double,
        val verticalLift: Double,
        val rotationDegrees: Double,
        val scale: Double,
        val duration: Double,
    ) {
        fun interpolated(next: MotionFrame, progress: Double): MotionFrame {
            val amount = progress.coerceIn(0.0, 1.0)
            fun mix(a: Double, b: Double) = a + (b - a) * amount
            return MotionFrame(
                imageRes = if (amount < 0.5) imageRes else next.imageRes,
                horizontalShift = mix(horizontalShift, next.horizontalShift),
                verticalLift = mix(verticalLift, next.verticalLift),
                rotationDegrees = mix(rotationDegrees, next.rotationDegrees),
                scale = mix(scale, next.scale),
                duration = duration,
            )
        }
    }

    /** The accessory badge's meaning; drawn by the companion as a Material icon. */
    val hasAccessory: Boolean get() = this != IDLE

    val imageRes: Int
        get() = when (bundledAsset) {
            BIKE -> R.drawable.pattie_pet_bike
            CELEBRATE -> R.drawable.pattie_pet_celebrate
            COACH -> R.drawable.pattie_pet_coach
            DANCE -> R.drawable.pattie_pet_dance
            ENCOURAGE -> R.drawable.pattie_pet_encourage
            RUN -> R.drawable.pattie_pet_run
            SHOES -> R.drawable.pattie_pet_shoes
            SWIM -> R.drawable.pattie_pet_swim
            else -> R.drawable.pattie_pet_idle
        }

    private val bundledAsset: PattiePetState
        get() = when (this) {
            STRETCH, RECOVERY -> ENCOURAGE
            TRANSITION -> SHOES
            FINISH -> CELEBRATE
            WARMUP -> IDLE
            HYDRATE -> SWIM
            else -> this
        }

    val motionProfile: MotionProfile
        get() = when (this) {
            IDLE -> MotionProfile(0.0, 0.0, 0.5, 1.8)
            COACH -> MotionProfile(0.0, 0.0, 0.5, 1.4)
            CELEBRATE -> MotionProfile(-3.0, 0.0, 1.0, 0.54)
            ENCOURAGE -> MotionProfile(0.0, 0.5, 0.75, 0.72)
            SHOES -> MotionProfile(3.0, 0.5, 0.75, 0.64)
            SWIM -> MotionProfile(-2.0, -1.0, 0.75, 0.72)
            BIKE -> MotionProfile(2.0, 1.0, 0.5, 0.68)
            RUN -> MotionProfile(-4.0, 1.0, 1.0, 0.46)
            TRANSITION -> MotionProfile(3.0, 0.5, 0.75, 0.58)
            FINISH -> MotionProfile(-3.0, 0.0, 1.0, 0.62)
            DANCE -> MotionProfile(6.0, 1.0, 1.0, 0.42)
            WARMUP -> MotionProfile(-1.0, 0.5, 0.75, 0.86)
            HYDRATE -> MotionProfile(2.0, 0.5, 0.5, 0.78)
            STRETCH -> MotionProfile(4.0, -0.5, 0.5, 0.92)
            RECOVERY -> MotionProfile(-2.0, -0.5, 0.5, 1.1)
        }

    val animationFrames: List<MotionFrame>
        get() {
            val asset = imageRes
            return when (this) {
                RUN -> frames(
                    asset, 0.11,
                    listOf(
                        listOf(-1.0, 0.0, 3.0, 0.98), listOf(-0.35, 0.65, 1.0, 1.0), listOf(0.55, 1.0, -2.0, 1.018),
                        listOf(1.0, 0.35, -4.0, 1.0), listOf(0.45, 0.0, -1.0, 0.98), listOf(-0.45, 0.55, 2.0, 1.0),
                    ),
                )
                DANCE -> frames(
                    asset, 0.13,
                    listOf(
                        listOf(-1.0, 0.0, -5.0, 0.98), listOf(-0.35, 0.8, 0.0, 1.01), listOf(0.75, 1.0, 6.0, 1.02),
                        listOf(0.2, 0.45, 2.0, 1.0), listOf(-0.7, 0.1, -6.0, 0.98), listOf(-0.15, 0.7, -1.0, 1.01),
                    ),
                )
                else -> {
                    val p = motionProfile
                    val lift = p.verticalLift
                    val shift = p.horizontalShift
                    val rotation = p.rotationDegrees
                    frames(
                        asset, maxOf(0.09, p.duration / 5),
                        listOf(
                            listOf(-shift, 0.0, -rotation * 0.55, 0.99),
                            listOf(-shift * 0.35, lift * 0.65, -rotation * 0.1, 1.0),
                            listOf(shift, lift, rotation, 1.018),
                            listOf(shift * 0.3, lift * 0.5, rotation * 0.15, 1.0),
                            listOf(-shift, 0.0, -rotation * 0.55, 0.99),
                        ),
                    )
                }
            }
        }

    /** Samples the loop continuously; the view calls this every frame. */
    fun animationFrame(elapsed: Double): MotionFrame {
        val frames = animationFrames
        val first = frames.first()
        val cycle = maxOf(frames.sumOf { it.duration }, first.duration)
        var remaining = elapsed % cycle
        if (remaining < 0) remaining += cycle
        for (index in frames.indices) {
            val frame = frames[index]
            val next = frames[(index + 1) % frames.size]
            if (remaining <= frame.duration) return frame.interpolated(next, remaining / maxOf(frame.duration, 0.001))
            remaining -= frame.duration
        }
        return first
    }

    companion object {
        val activeMotionStates = listOf(WARMUP, SWIM, TRANSITION, BIKE, RUN, FINISH, DANCE, HYDRATE, STRETCH, RECOVERY)

        fun motionState(index: Int): PattiePetState {
            val count = activeMotionStates.size
            val wrapped = ((index % count) + count) % count
            return activeMotionStates[wrapped]
        }

        fun forTopicId(id: String): PattiePetState = when (id) {
            "swim-start", "swim-gear" -> SWIM
            "bike-handling", "bike-trouble" -> BIKE
            "feet" -> SHOES
            "after" -> CELEBRATE
            "run-form" -> ENCOURAGE
            else -> COACH
        }

        private fun frames(asset: Int, duration: Double, values: List<List<Double>>) = values.map {
            MotionFrame(asset, it[0], it[1], it[2], it[3], duration)
        }
    }
}
