package app.zynetix.board

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The board. Answers the `zynetix/kiosk` channel (lib/core/kiosk.dart): status, enter, exit;
 * and `zynetix/apps` (lib/core/apps.dart): isInstalled, launch, for the full Zynetix Board app.
 */
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zynetix/apps").setMethodCallHandler { call, result ->
            val pkg = call.argument<String>("package")
            if (pkg == null) {
                result.error("apps", "package missing", null)
                return@setMethodCallHandler
            }
            // Visible because AndroidManifest.xml lists the package under <queries>.
            val launch = packageManager.getLaunchIntentForPackage(pkg)
            when (call.method) {
                "isInstalled" -> result.success(launch != null)
                "launch" -> {
                    if (launch == null) {
                        result.success(false)
                    } else {
                        try {
                            startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("apps", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
