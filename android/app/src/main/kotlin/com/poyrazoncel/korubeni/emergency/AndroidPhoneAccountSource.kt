package com.poyrazoncel.korubeni.emergency

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat

/**
 * Production [PhoneAccountSource]. Every read needs READ_PHONE_STATE except
 * the static default-subscription getters; a revoked permission surfaces as
 * SecurityException, which [PhoneAccountSelector] turns into "no explicit
 * account" so the call is still placed.
 */
class AndroidPhoneAccountSource(
    private val context: Context,
    private val telecom: TelecomManager,
) : PhoneAccountSource<PhoneAccountHandle> {
    // Checked before every protected read: a denied permission costs no binder
    // call and surfaces as the SecurityException the selector already maps
    // to "no explicit account".
    override fun defaultOutgoing(): PhoneAccountHandle? {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("READ_PHONE_STATE not granted")
        }
        return telecom.getDefaultOutgoingPhoneAccount(PhoneAccount.SCHEME_TEL)
    }

    override fun callCapable(): List<PhoneAccountCandidate<PhoneAccountHandle>> {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("READ_PHONE_STATE not granted")
        }
        val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        return telecom.callCapablePhoneAccounts.map { handle ->
            PhoneAccountCandidate(
                handle = handle,
                // A SIM slot with no card or a locked card cannot place the
                // call; demoting it keeps FIRST_CAPABLE off it on API 29,
                // where subscription ids are unavailable.
                isSimSubscription = isSim(handle) && simUsable(telephony, handle),
                subscriptionId = subscriptionIdOf(telephony, handle),
            )
        }
    }

    override fun activeSubscriptionIds(): Set<Int> {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("READ_PHONE_STATE not granted")
        }
        val manager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
            ?: return emptySet()
        return manager.activeSubscriptionInfoList.orEmpty().map { it.subscriptionId }.toSet()
    }

    override fun preferredSubscriptionIds(): List<Int> =
        listOf(
            SubscriptionManager.getDefaultVoiceSubscriptionId(),
            SubscriptionManager.getDefaultDataSubscriptionId(),
        ).filter { SubscriptionManager.isValidSubscriptionId(it) }.distinct()

    private fun isSim(handle: PhoneAccountHandle): Boolean = try {
        telecom.getPhoneAccount(handle)
            ?.hasCapabilities(PhoneAccount.CAPABILITY_SIM_SUBSCRIPTION) == true
    } catch (_: RuntimeException) {
        false
    }

    /** Unknown counts as usable: only a definite non-ready state demotes. */
    private fun simUsable(telephony: TelephonyManager?, handle: PhoneAccountHandle): Boolean = try {
        val state = telephony?.createForPhoneAccountHandle(handle)?.simState
        state == null || state == TelephonyManager.SIM_STATE_READY
    } catch (_: RuntimeException) {
        true
    }

    private fun subscriptionIdOf(telephony: TelephonyManager?, handle: PhoneAccountHandle): Int? {
        if (telephony == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return try {
            telephony.getSubscriptionId(handle).takeIf { SubscriptionManager.isValidSubscriptionId(it) }
        } catch (_: SecurityException) {
            null
        } catch (_: RuntimeException) {
            null
        }
    }
}
