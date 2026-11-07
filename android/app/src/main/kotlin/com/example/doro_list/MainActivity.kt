package com.example.doro_list

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var liveActivityChannel: MethodChannel? = null
    private var ready = false
    private var latestState: Map<*, *>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        liveActivityChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "doro_list/pomodoro_live_activity").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        ready = true
                        val action = PomodoroNotification.readAction(intent)
                        intent.removeExtra(PomodoroNotification.EXTRA_ACTION)
                        intent.removeExtra(PomodoroNotification.EXTRA_SESSION)
                        result.success(action)
                    }
                    "sync" -> {
                        latestState = call.arguments as? Map<*, *>
                        try {
                            PomodoroNotification(this).sync(latestState)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("ongoing_notification", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = PomodoroNotification.readAction(intent) ?: return
        if (ready) {
            liveActivityChannel?.invokeMethod("timerAction", action)
            intent.removeExtra(PomodoroNotification.EXTRA_ACTION)
            intent.removeExtra(PomodoroNotification.EXTRA_SESSION)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // The first countdown can be published before the notification permission dialog closes.
        try { PomodoroNotification(this).sync(latestState) } catch (_: Exception) { }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ready = false
        liveActivityChannel?.setMethodCallHandler(null)
        liveActivityChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
