package app.zynetix.board

import android.app.Activity
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.BatteryManager
import android.provider.Settings
import android.view.WindowManager

/**
 * Kiosk mode, ported from the Zynetix Board (amjad03/Kinetix) Kiosk.kt.
 *
 * As device owner (`adb shell dpm set-device-owner app.zynetix.board/.KioskAdminReceiver`)
 * the board allows itself in lock task mode and locks fully, with no system prompt; it also turns
 * off the lock screen and status bar, becomes the home app and stays awake while plugged in.
 * Allowed by an MDM instead (its DPC put us in the lock task packages), it locks fully too. Otherwise
 * startLockTask() falls back to screen pinning, which the user confirms and can undo.
 */
class Kiosk(private val activity: Activity) {
    private val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val am = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val admin = ComponentName(activity, KioskAdminReceiver::class.java)

    /** The full Zynetix Board app may also run inside the lock (Smartboard → Open Zynetix Board app). */
    private val kinetixBoard = "in.kinetix.board"

    /** The HOME entry point (an activity-alias, disabled unless kiosk mode is on). */
    private val homeAlias = ComponentName(activity, "app.zynetix.board.KioskHome")

    private fun setHomeAlias(enabled: Boolean) {
        val state = if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        activity.packageManager.setComponentEnabledSetting(homeAlias, state, PackageManager.DONT_KILL_APP)
    }

    private val deviceOwner: Boolean
        get() = dpm.isDeviceOwnerApp(activity.packageName)

    fun status(): Map<String, Any> = mapOf("deviceOwner" to deviceOwner, "lockTask" to lockTaskName())

    private fun lockTaskName(): String = when (am.lockTaskModeState) {
        ActivityManager.LOCK_TASK_MODE_LOCKED -> "locked"
        ActivityManager.LOCK_TASK_MODE_PINNED -> "pinned"
        else -> "none"
    }

    fun enter(): Map<String, Any> {
        val owner = deviceOwner
        if (owner) {
            dpm.setLockTaskPackages(admin, arrayOf(activity.packageName, kinetixBoard))
            dpm.setKeyguardDisabled(admin, true)
            dpm.setStatusBarDisabled(admin, true)
            val home = IntentFilter(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                addCategory(Intent.CATEGORY_DEFAULT)
            }
            setHomeAlias(true)
            dpm.addPersistentPreferredActivity(admin, home, homeAlias)
            val plugged = BatteryManager.BATTERY_PLUGGED_AC or BatteryManager.BATTERY_PLUGGED_USB or BatteryManager.BATTERY_PLUGGED_WIRELESS
            try {
                dpm.setGlobalSetting(admin, Settings.Global.STAY_ON_WHILE_PLUGGED_IN, plugged.toString())
            } catch (e: SecurityException) {
                // Not allowed on this Android version or build: the screen-on flag below still applies.
            }
        }
        setBootLaunch(activity, true)
        activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        // Locked when we are allowed (device owner or MDM), else the system asks to pin the screen.
        val permitted = dpm.isLockTaskPermitted(activity.packageName)
        if (am.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_NONE) activity.startLockTask()
        // The state changes asynchronously; report what startLockTask leads to.
        return mapOf("deviceOwner" to owner, "lockTask" to if (permitted) "locked" else "pinned")
    }

    /** Unlocks and undoes what [enter] set. [keepBootLaunch]: kiosk mode is only paused by IT. */
    fun exit(keepBootLaunch: Boolean): Map<String, Any> {
        setBootLaunch(activity, keepBootLaunch)
        if (am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE) activity.stopLockTask()
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val owner = deviceOwner
        if (owner) {
            dpm.setKeyguardDisabled(admin, false)
            dpm.setStatusBarDisabled(admin, false)
            dpm.clearPackagePersistentPreferredActivities(admin, activity.packageName)
            setHomeAlias(false)
            try {
                dpm.setGlobalSetting(admin, Settings.Global.STAY_ON_WHILE_PLUGGED_IN, "0")
            } catch (e: SecurityException) {
            }
            dpm.setLockTaskPackages(admin, emptyArray<String>())
        }
        return mapOf("deviceOwner" to owner, "lockTask" to "none")
    }

    fun openSystemSettings() {
        activity.startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    companion object {
        private const val PREFS = "zynetix_kiosk"
        private const val BOOT_LAUNCH = "boot_launch"

        /** Read by [BootReceiver]: open the board after a reboot. */
        fun bootLaunch(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(BOOT_LAUNCH, false)

        fun setBootLaunch(context: Context, on: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(BOOT_LAUNCH, on).apply()
        }
    }
}
