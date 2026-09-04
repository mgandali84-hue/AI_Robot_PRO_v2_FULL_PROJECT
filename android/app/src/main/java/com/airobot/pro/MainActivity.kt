package com.airobot.pro

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "ai_robot_pro_v2/phone_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                val service = RobotAccessibilityService.getInstance()
                when (call.method) {
                    "isAccessibilityEnabled" -> result.success(service != null)
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(true)
                    }
                    "action" -> {
                        when (call.argument<String>("name")) {
                            "home" -> result.success(service?.home() ?: false)
                            "back" -> result.success(service?.back() ?: false)
                            "recents" -> result.success(service?.recents() ?: false)
                            "notifications" -> result.success(service?.notifications() ?: false)
                            else -> result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
