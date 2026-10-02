package com.poyrazoncel.korubeni.security

import android.view.MotionEvent

/**
 * Policy for touches that arrive while another app's window is drawn over ours.
 *
 * ## The threat
 *
 * An app holding SYSTEM_ALERT_WINDOW can draw on top of this one. Over the PIN
 * pad it can present a look-alike keypad and harvest the PIN; over a consent or
 * destructive confirmation it can hide what the user is actually agreeing to.
 * FLAG_SECURE does not help: it stops capture of our window, not someone else
 * drawing over it. In a duress model the overlay-capable app is the expected
 * adversary, so this is not a theoretical surface.
 *
 * ## Why not simply discard every obscured touch
 *
 * `View.setFilterTouchesWhenObscured(true)` discards them with NO opacity
 * threshold. Android 12+ already blocks untrusted touches by default but only
 * above an opacity threshold, so turning the view flag on is strictly stricter
 * than what the platform does and newly affects overlays that are currently
 * allowed through -- blue-light filters and screen dimmers being the common
 * ones. minSdk here is 29, where the platform does none of this.
 *
 * Discarding touches on a screen the user must get past to reach the app at all
 * therefore risks locking an owner out of their own safety app, including out of
 * the panic button. "PIN'imi unuttum" is a touch too, so there would be no
 * escape. That is why [Policy] separates the two cases instead of having one
 * global switch:
 *
 * - [Policy.WARN] on gateway surfaces (unlock, consent): the touch lands, and
 *   the user is told an app is drawing over the screen. Actionable, never
 *   locking.
 * - [Policy.BLOCK] on surfaces that are not gateways (data export, local-data
 *   reset): the touch is discarded, because refusing the action is a safe
 *   answer there.
 *
 * Both policies report, so a discarded touch never reads as a dead button --
 * a silent refusal on a safety control is its own defect in this project.
 *
 * ## Honest limit
 *
 * Which overlays actually set [MotionEvent.FLAG_WINDOW_IS_OBSCURED] on a given
 * OEM build has NOT been measured on a device. The policy split above is what
 * keeps that uncertainty from being able to cause harm: the unmeasured case
 * degrades to a warning, not to a locked-out user.
 */
object OverlayTouchGuard {

    enum class Policy(val wire: String) {
        /** No sensitive surface is on screen. */
        OFF("off"),

        /** Let the touch through; tell the user. */
        WARN("warn"),

        /** Discard the touch; tell the user why. */
        BLOCK("block"),
    }

    /**
     * Strict decoding of the Dart request. Null for anything unrecognised: a
     * platform-channel argument is input, and an unknown policy must not
     * silently become a weaker one.
     */
    fun policyFrom(raw: String?): Policy? =
        Policy.values().firstOrNull { it.wire == raw }

    /** Whether the window should hand obscured touches to the framework filter. */
    fun filterTouches(policy: Policy): Boolean = policy == Policy.BLOCK

    /**
     * True when this event arrived while our window was obscured AT the touch
     * point.
     *
     * Deliberately not FLAG_WINDOW_IS_PARTIALLY_OBSCURED: that one fires when
     * something covers the window somewhere else, which includes ordinary,
     * harmless chrome and would warn constantly.
     */
    fun isObscured(flags: Int): Boolean =
        flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED != 0

    /**
     * Report once per activation of a sensitive surface, under BOTH active
     * policies.
     *
     * Once, not per event: a single tap produces DOWN/MOVE/UP and a scroll
     * produces dozens, and a warning that repeats on every one of them is
     * noise the user learns to dismiss.
     */
    fun shouldReport(
        policy: Policy,
        obscured: Boolean,
        alreadyReported: Boolean,
    ): Boolean = policy != Policy.OFF && obscured && !alreadyReported
}
