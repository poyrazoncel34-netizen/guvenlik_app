package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.os.Build
import android.os.UserManager

object DirectBootAccess {
    fun isUserUnlocked(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return true
        val manager = context.getSystemService(Context.USER_SERVICE) as? UserManager
        return manager?.isUserUnlocked ?: false
    }
}
