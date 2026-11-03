package app.zynetix.board

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** The board. Answers the `zynetix/kiosk` channel (lib/core/kiosk.dart): status, enter, exit. */
class MainActivity : FlutterActivity() {
    private val kiosk by lazy { Kiosk(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zynetix/kiosk").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "status" -> result.success(kiosk.status())
                    "enter" -> result.success(kiosk.enter())
                    "exit" -> result.success(kiosk.exit(call.argument<Boolean>("keepBootLaunch") ?: false))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("kiosk", e.message, null)
            }
        }
    }
}
