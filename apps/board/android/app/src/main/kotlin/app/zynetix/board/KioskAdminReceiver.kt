package app.zynetix.board

import android.app.admin.DeviceAdminReceiver

/** Device admin so the board can be provisioned as device owner for kiosk mode:
 * adb shell dpm set-device-owner app.zynetix.board/.KioskAdminReceiver */
class KioskAdminReceiver : DeviceAdminReceiver()
