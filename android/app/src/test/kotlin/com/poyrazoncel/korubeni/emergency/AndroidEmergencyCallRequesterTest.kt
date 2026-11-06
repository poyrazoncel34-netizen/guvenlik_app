package com.poyrazoncel.korubeni.emergency

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.TelephonyManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowSubscriptionManager
import org.robolectric.util.ReflectionHelpers
import org.robolectric.util.ReflectionHelpers.ClassParameter

/**
 * Dual-SIM "ask every time": without an explicit account Telecom parks the
 * call in SELECT_PHONE_ACCOUNT until someone taps a SIM, which a locked or
 * pocketed phone never does. The request must carry the account itself.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class AndroidEmergencyCallRequesterTest {
    private val context: Context = RuntimeEnvironment.getApplication()
    private val telecom = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
    private val component = ComponentName("com.android.phone", "com.android.services.telephony.TelephonyConnectionService")
    private val sim1 = PhoneAccountHandle(component, "sim1")
    private val sim2 = PhoneAccountHandle(component, "sim2")

    @Before
    fun grantPhonePermissions() {
        shadowOf(RuntimeEnvironment.getApplication()).grantPermissions(
            Manifest.permission.CALL_PHONE,
            Manifest.permission.READ_PHONE_STATE,
        )
    }

    private fun registerSim(handle: PhoneAccountHandle) {
        val builder = PhoneAccount.builder(handle, handle.id)
            .setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER or PhoneAccount.CAPABILITY_SIM_SUBSCRIPTION)
            .addSupportedUriScheme(PhoneAccount.SCHEME_TEL)
        // Telephony registers SIM accounts enabled; the setter is @hide and
        // the shadow only lists enabled accounts, as Telecom does.
        ReflectionHelpers.callInstanceMethod<Any>(
            builder,
            "setIsEnabled",
            ClassParameter.from(Boolean::class.javaPrimitiveType, true),
        )
        telecom.registerPhoneAccount(builder.build())
    }

    private fun placedAccount(): PhoneAccountHandle? {
        val extras = shadowOf(telecom).onlyOutgoingCall.extras
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            extras?.getParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, PhoneAccountHandle::class.java)
        } else {
            @Suppress("DEPRECATION")
            extras?.getParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE)
        }
    }

    @Test
    fun `dual SIM without a default places the call on an explicit SIM`() {
        registerSim(sim1)
        registerSim(sim2)

        val outcome = AndroidEmergencyCallRequester(context).requestCall("+905550102030")

        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, outcome)
        assertEquals(sim1, placedAccount())
    }

    @Test
    fun `dual SIM with a default places the call on the default`() {
        registerSim(sim1)
        registerSim(sim2)
        shadowOf(telecom).setDefaultOutgoingPhoneAccount(PhoneAccount.SCHEME_TEL, sim2)

        AndroidEmergencyCallRequester(context).requestCall("+905550102030")

        assertEquals(sim2, placedAccount())
    }

    private fun simState(handle: PhoneAccountHandle, state: Int) {
        val perAccount = Shadow.newInstanceOf(TelephonyManager::class.java)
        shadowOf(perAccount).setSimState(state)
        val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        shadowOf(telephony).setTelephonyManagerForHandle(handle, perAccount)
    }

    @Test
    @Config(sdk = [29])
    fun `API 29 dual SIM without a default skips a slot with no card`() {
        registerSim(sim1)
        registerSim(sim2)
        // The shadow keeps SIM state globally, not per account, so only the
        // empty slot gets a TelephonyManager; sim2 stays "unknown" (usable).
        simState(sim1, TelephonyManager.SIM_STATE_ABSENT)

        AndroidEmergencyCallRequester(context).requestCall("+905550102030")

        assertEquals(sim2, placedAccount())
    }

    @Test
    fun `dual SIM without a default follows the system default voice subscription`() {
        registerSim(sim1)
        registerSim(sim2)
        val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        shadowOf(telephony).setPhoneAccountHandleSubscriptionId(sim1, 1)
        shadowOf(telephony).setPhoneAccountHandleSubscriptionId(sim2, 2)
        ShadowSubscriptionManager.setDefaultVoiceSubscriptionId(2)

        AndroidEmergencyCallRequester(context).requestCall("+905550102030")

        assertEquals(sim2, placedAccount())
    }

    @Test
    fun `no account still submits the call exactly as before`() {
        val outcome = AndroidEmergencyCallRequester(context).requestCall("+905550102030")

        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, outcome)
        assertEquals(null, placedAccount())
    }

    @Test
    fun `denied READ_PHONE_STATE still places the call without an account`() {
        registerSim(sim1)
        registerSim(sim2)
        shadowOf(RuntimeEnvironment.getApplication()).denyPermissions(Manifest.permission.READ_PHONE_STATE)

        val outcome = AndroidEmergencyCallRequester(context).requestCall("+905550102030")

        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, outcome)
        assertEquals(null, placedAccount())
    }

    @Test
    fun `missing CALL_PHONE still fails so the manual fallback runs`() {
        shadowOf(RuntimeEnvironment.getApplication()).denyPermissions(Manifest.permission.CALL_PHONE)

        val outcome = AndroidEmergencyCallRequester(context).requestCall("+905550102030")

        assertEquals(CallRequestOutcome.FAILED, outcome)
        assertTrue(shadowOf(telecom).allOutgoingCalls.isEmpty())
    }
}
