package de.alex468187.handyapp

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FragmentActivity: nötig für den Fingerabdruck (local_auth).
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "summer/messages")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "isEnabled" -> {
                            val list = Settings.Secure.getString(
                                contentResolver, "enabled_notification_listeners") ?: ""
                            result.success(list.contains(packageName))
                        }
                        "openSettings" -> {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                            result.success(null)
                        }
                        "openAppInfo" -> {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                android.net.Uri.parse("package:$packageName")))
                            result.success(null)
                        }
                        "filePath" -> result.success(SummerListener.file(this).absolutePath)
                        "canReply" -> result.success(
                            SummerListener.canReply(call.argument<String>("chat")!!))
                        "reply" -> result.success(SummerListener.reply(this,
                            call.argument<String>("chat")!!, call.argument<String>("text")!!))
                        "open" -> result.success(SummerListener.open(this,
                            call.argument<String>("chat")!!, call.argument<String>("package")!!))
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("summer", e.message, null)
                }
            }
    }
}
