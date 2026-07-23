package com.poyrazoncel.korubeni.emergency

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        EmergencyReceiverGuard.run(
            context,
            NativeSafetyEventCode.BOOT_RECEIVER_BOUNDARY_FAILURE,
        ) {
            val action = intent?.action ?: return@run
            if (action !in SUPPORTED_ACTIONS) return@run
            Log.i("BootCompletedReceiver", "System restore event received; reconciling safety state")

            val coordinator = EmergencySessionRuntime.coordinator(context)
            if (
                action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
                action == Intent.ACTION_BOOT_COMPLETED
            ) {
                coordinator.reconcileAfterBoot()
            } else {
                coordinator.reconcileCurrentBoot()
            }
            Log.i("BootCompletedReceiver", "Safety state reconciliation completed")
        }
    }

    companion object {
        private val SUPPORTED_ACTIONS = setOf(
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_USER_UNLOCKED,
        )
    }
}
