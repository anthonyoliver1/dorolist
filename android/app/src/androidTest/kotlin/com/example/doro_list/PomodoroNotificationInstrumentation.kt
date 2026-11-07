package com.example.doro_list

import android.app.Activity
import android.app.Instrumentation
import android.app.Notification
import android.app.NotificationManager
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.os.SystemClock

/** Exercises the real Android notification manager without running the Flutter timer. */
class PomodoroNotificationInstrumentation : Instrumentation() {
    private fun waitUntil(message: String, condition: () -> Boolean) {
        val end = SystemClock.elapsedRealtime() + 5000
        while (!condition() && SystemClock.elapsedRealtime() < end) SystemClock.sleep(50)
        check(condition()) { message }
    }

    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val result = Bundle()
        val context = targetContext
        val manager = context.getSystemService(NotificationManager::class.java)
        try {
            // The emulator must allow notifications, just as a user does when starting a timer.
            if (android.os.Build.VERSION.SDK_INT >= 33) {
                ParcelFileDescriptor.AutoCloseInputStream(uiAutomation.executeShellCommand(
                    "pm grant ${context.packageName} android.permission.POST_NOTIFICATIONS")).use { it.readBytes() }
            }
            val renderer = PomodoroNotification(context)
            val end = System.currentTimeMillis() + 60000
            val state = mapOf<String, Any?>("sessionId" to "native-notification-test",
                "phase" to "pomodoro", "phaseLabel" to "Pomodoro",
                "taskTitle" to "Sessão de teste", "deadline" to end,
                "remainingSeconds" to null)
            renderer.sync(state)
            waitUntil("notification was not published") { manager.activeNotifications.any { it.id == PomodoroNotification.NOTIFICATION_ID } }
            val active = manager.activeNotifications.single { it.id == PomodoroNotification.NOTIFICATION_ID }.notification
            check(active.extras.getString(Notification.EXTRA_TITLE) == "Pomodoro")
            check(active.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
            check(active.extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN))
            check(active.`when` == end)
            check(active.actions.single().title.toString() == "Pausar")
            if (android.os.Build.VERSION.SDK_INT >= 26) {
                check(manager.getNotificationChannel(PomodoroNotification.CHANNEL_ID).sound == null)
            }
            renderer.sync(state + mapOf("deadline" to null, "remainingSeconds" to 1480))
            waitUntil("notification did not pause") { manager.activeNotifications.any { it.id == PomodoroNotification.NOTIFICATION_ID && it.notification.extras.getString(Notification.EXTRA_TITLE) == "Pomodoro em pausa" } }
            val paused = manager.activeNotifications.single { it.id == PomodoroNotification.NOTIFICATION_ID }.notification
            check(paused.extras.getString(Notification.EXTRA_TITLE) == "Pomodoro em pausa")
            check(paused.extras.getString(Notification.EXTRA_TEXT)!!.contains("24:40"))
            check(!paused.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
            check(paused.actions.single().title.toString() == "Continuar")
            renderer.sync(null)
            waitUntil("notification was not removed") { manager.activeNotifications.none { it.id == PomodoroNotification.NOTIFICATION_ID } }
            // Android removes the countdown at the deadline without any Dart callbacks.
            renderer.sync(state + mapOf("deadline" to System.currentTimeMillis() + 1500))
            waitUntil("countdown was not published") { manager.activeNotifications.any { it.id == PomodoroNotification.NOTIFICATION_ID } }
            waitUntil("countdown did not expire") { manager.activeNotifications.none { it.id == PomodoroNotification.NOTIFICATION_ID } }
            result.putString("stream", "PASS: running countdown, paused controls, reset and native expiration\n")
            finish(Activity.RESULT_OK, result)
        } catch (error: Throwable) {
            manager.cancel(PomodoroNotification.NOTIFICATION_ID)
            result.putString("stream", error.stackTraceToString())
            finish(Activity.RESULT_CANCELED, result)
        }
    }
}
