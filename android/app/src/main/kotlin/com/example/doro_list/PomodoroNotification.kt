package com.example.doro_list

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.Uri
import android.os.Build
import java.util.Locale

/** System-rendered countdown: no background Dart timer or foreground service is needed. */
class PomodoroNotification(private val context: Context) {
    private val manager = context.getSystemService(NotificationManager::class.java)

    fun sync(state: Map<*, *>?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) cancelLegacyTimeout()
        if (state == null) {
            manager.cancel(NOTIFICATION_ID)
            return
        }
        val session = state["sessionId"] as? String ?: return
        val phase = state["phaseLabel"] as? String ?: return
        val task = (state["taskTitle"] as? String)?.take(160)
        val deadline = (state["deadline"] as? Number)?.toLong()
        val remaining = (state["remainingSeconds"] as? Number)?.toInt() ?: 0
        val now = System.currentTimeMillis()
        if (deadline != null && deadline <= now) {
            manager.cancel(NOTIFICATION_ID)
            return
        }
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Pomodoro em andamento", NotificationManager.IMPORTANCE_LOW)
            channel.description = "Tempo restante, tarefa e controles da sessão de foco ou pausa"
            channel.setSound(null, null)
            channel.enableVibration(false)
            manager.createNotificationChannel(channel)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_LOW)
        }
        val running = deadline != null
        val title = if (running) phase else "$phase em pausa"
        val pausedTime = String.format(Locale.ROOT, "%02d:%02d", remaining / 60, remaining % 60)
        val text = if (running) task ?: "Doro List" else "$pausedTime · ${task ?: "Doro List"}"
        val tint = if (state["phase"] == "short" || state["phase"] == "long") Color.rgb(156, 81, 59) else Color.rgb(36, 107, 91)
        builder.setSmallIcon(R.drawable.ic_stat_timer)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(actionIntent("open", session))
            .setCategory(Notification.CATEGORY_STOPWATCH)
            .setColor(tint)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setShowWhen(running)
            .setUsesChronometer(running)
        if (deadline != null) {
            builder.setWhen(deadline).setChronometerCountDown(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                builder.setTimeoutAfter(deadline - now)
            } else {
                scheduleLegacyTimeout(deadline)
            }
        }
        val action = if (running) "pause" else "resume"
        builder.addAction(Notification.Action.Builder(
            null, if (running) "Pausar" else "Continuar", actionIntent(action, session)).build())
        manager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun actionIntent(action: String, session: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(ACTION)
            .setData(Uri.Builder().scheme("doro-list").authority("pomodoro")
                .appendPath(session).appendPath(action).build())
            .putExtra(EXTRA_ACTION, action)
            .putExtra(EXTRA_SESSION, session)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun timeoutIntent(): PendingIntent = PendingIntent.getBroadcast(context, 0,
        Intent(context, PomodoroNotificationTimeout::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun cancelLegacyTimeout() {
        context.getSystemService(AlarmManager::class.java).cancel(timeoutIntent())
    }

    private fun scheduleLegacyTimeout(deadline: Long) {
        context.getSystemService(AlarmManager::class.java).setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP, deadline, timeoutIntent())
    }

    companion object {
        // Flutter's scheduled finish alerts use non-negative IDs.
        const val NOTIFICATION_ID = -2048
        const val CHANNEL_ID = "pomodoro_ongoing_v1"
        const val ACTION = "com.example.doro_list.POMODORO_ACTION"
        const val EXTRA_ACTION = "pomodoro_action"
        const val EXTRA_SESSION = "pomodoro_session"

        fun readAction(intent: Intent?): Map<String, String>? {
            if (intent?.action != ACTION) return null
            val action = intent.getStringExtra(EXTRA_ACTION) ?: return null
            val session = intent.getStringExtra(EXTRA_SESSION) ?: return null
            if (action !in setOf("open", "pause", "resume")) return null
            return mapOf("action" to action, "sessionId" to session)
        }
    }
}

class PomodoroNotificationTimeout : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        context.getSystemService(NotificationManager::class.java).cancel(PomodoroNotification.NOTIFICATION_ID)
    }
}
