package `in`.zynetix.zynetix_board

import android.app.admin.DeviceAdminReceiver

/** Device admin so the board can be provisioned as device owner for kiosk mode:
 * adb shell dpm set-device-owner in.zynetix.zynetix_board/.KioskAdminReceiver */
class KioskAdminReceiver : DeviceAdminReceiver()
