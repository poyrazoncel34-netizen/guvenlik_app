package com.poyrazoncel.korubeni.integrity

import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * A-017 device evidence. Runs inside the app process (the app's UID and its
 * package visibility), so what it observes is what production code observes.
 *
 * Not a substitute for the JVM tests; it measures the real device.
 * Results are logged under tag A017_EVIDENCE and recorded in
 * docs/audit/device-verification-2026-09-22-a017-integrity-probe.md.
 *
 * Until 2026-10-06 this class also called RootBeer and safe_device by
 * reflection to compare the old verdict with the new probe. Both libraries
 * left the APK with F-06 (6bb7361), so those two methods could only throw
 * ClassNotFoundException: they measured nothing that still ships. The
 * comparison they produced is preserved in the audit note above; what
 * remains here is the production path.
 */
@RunWith(AndroidJUnit4::class)
class DeviceIntegrityEmulatorProbeTest {

    /** The probe the Dart side relies on, run directly on this device. */
    @Test
    fun probeOutcomesOnThisDevice() {
        val started = SystemClock.elapsedRealtime()
        val probe = DeviceIntegrityProbe()
        val result = probe.run()
        val elapsed = SystemClock.elapsedRealtime() - started
        Log.i(TAG, "PROBE ms=$elapsed result=$result")
        Log.i(TAG, "PROBE failedPaths=${probe.failedPaths()}")
        val reader = DeviceIntegrityProbe.GetpropReader()
        val snapshot = reader.snapshot()
        Log.i(
            TAG,
            "PROPS snapshotSize=${snapshot?.size} " +
                DeviceIntegrityProbe.DANGEROUS_PROPS.joinToString(" ") { (name, _) ->
                    "$name=${snapshot?.get(name) ?: "<missing>"}" +
                        "(areaReadable=${reader.areaReadable(name)})"
                },
        )
        Log.i(TAG, "BUILD type=${android.os.Build.TYPE} tags=${android.os.Build.TAGS}")

        assertEquals(8, result.size)
        assertTrue(result.values.all { it in setOf("found", "absent", "error") })
        assertTrue("probe must finish well inside the 3 s Dart timeout", elapsed < 3_000)
    }

    /**
     * The exact channel Dart calls: MethodChannel decode, the worker thread,
     * the hop back to the main looper and the StandardMethodCodec reply.
     */
    @Test
    fun productionChannelRepliesWithEveryCheck() {
        val messenger = CapturingMessenger()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            DeviceIntegrityChannel.register(messenger)
        }
        val handler = messenger.handler
        assertNotNull("the channel handler was not installed", handler)

        val replied = CountDownLatch(1)
        var reply: ByteBuffer? = null
        val started = SystemClock.elapsedRealtime()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            // The engine hands handlers a buffer positioned at its start.
            val call = CODEC.encodeMethodCall(MethodCall("probe", null)).apply { rewind() }
            handler!!.onMessage(call) { bytes ->
                reply = bytes
                replied.countDown()
            }
        }
        assertTrue("no reply within the 3 s Dart budget", replied.await(3, TimeUnit.SECONDS))
        val elapsed = SystemClock.elapsedRealtime() - started

        val envelope = reply
        assertNotNull("the channel replied with no envelope", envelope)
        envelope!!.rewind()
        val decoded = CODEC.decodeEnvelope(envelope) as Map<*, *>
        Log.i(TAG, "CHANNEL ms=$elapsed result=$decoded")
        assertEquals(8, decoded.size)
        assertTrue(decoded.values.all { it in setOf("found", "absent", "error") })
    }

    /** Records the handler MethodChannel installs; nothing is sent to Flutter. */
    private class CapturingMessenger : BinaryMessenger {
        var handler: BinaryMessenger.BinaryMessageHandler? = null

        override fun send(channel: String, message: ByteBuffer?) = Unit

        override fun send(
            channel: String,
            message: ByteBuffer?,
            callback: BinaryMessenger.BinaryReply?,
        ) = Unit

        override fun setMessageHandler(
            channel: String,
            handler: BinaryMessenger.BinaryMessageHandler?,
        ) {
            if (channel == DeviceIntegrityChannel.NAME) this.handler = handler
        }
    }

    private companion object {
        const val TAG = "A017_EVIDENCE"
        val CODEC: StandardMethodCodec = StandardMethodCodec.INSTANCE
    }
}
