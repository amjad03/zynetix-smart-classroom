package app.zynetix.board

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Opens the board after a reboot (a power cut) while kiosk mode is on. As device owner the board
 * is also the home app, so it opens anyway; this covers screen-pinned boards. Android 10+ blocks
 * activity starts from the background for most apps, so on those a non-owner board may not open
 * (docs/hardware/kiosk-mode.md).
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!Kiosk.bootLaunch(context)) return
        context.startActivity(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
