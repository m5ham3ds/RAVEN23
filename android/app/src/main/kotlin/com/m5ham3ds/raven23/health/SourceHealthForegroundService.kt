package com.m5ham3ds.raven23.health

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.m5ham3ds.raven23.MainActivity
import com.m5ham3ds.raven23.R

/** Keeps an active RAVEN23 source-health session visible while the app is in
 * the background. The Flutter-owned session continues to run in the retained
 * app engine; this service supplies foreground execution priority and a
 * persistent progress notification. */
class SourceHealthForegroundService : Service() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                isActive = false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                val notification = buildNotification(
                    videoDone = intent.getIntExtra(EXTRA_VIDEO_DONE, 0),
                    videoTotal = intent.getIntExtra(EXTRA_VIDEO_TOTAL, 0),
                    mihonDone = intent.getIntExtra(EXTRA_MIHON_DONE, 0),
                    mihonTotal = intent.getIntExtra(EXTRA_MIHON_TOTAL, 0),
                )
                if (isActive) {
                    getSystemService(NotificationManager::class.java)
                        .notify(NOTIFICATION_ID, notification)
                } else {
                    isActive = true
                    startForeground(NOTIFICATION_ID, notification)
                }
            }
            else -> {
                isActive = true
                startForeground(NOTIFICATION_ID, buildNotification())
            }
        }
        // If Android recreates the service under process pressure, the
        // notification brings the user back to the saved session; Dart resumes
        // only sources which had not finished before process recreation.
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Keep running when the task is swiped away. A user force-stop still
        // stops the service, as required by Android's process controls.
        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isActive = false
        super.onDestroy()
    }

    private fun buildNotification(
        videoDone: Int = 0,
        videoTotal: Int = 0,
        mihonDone: Int = 0,
        mihonTotal: Int = 0,
    ): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_OPEN_HEALTH_CHECK
            putExtra(EXTRA_OPEN_HEALTH_CHECK, true)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            REQUEST_OPEN_HEALTH_CHECK,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val line = if (videoTotal + mihonTotal == 0) {
            "Preparing installed sources…"
        } else {
            "Video $videoDone/$videoTotal  ·  Mihon $mihonDone/$mihonTotal"
        }
        val total = videoTotal + mihonTotal
        val progress = (videoDone + mihonDone).coerceIn(0, total.coerceAtLeast(1))
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("RAVEN23 · Source health check")
            .setContentText(line)
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "$line\nTap to return to Provider Health and watch the live results.",
                ),
            )
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(total, progress, total == 0)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Source health checks",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Progress while RAVEN23 checks installed video and Mihon sources"
                setShowBadge(false)
            },
        )
    }

    companion object {
        const val CHANNEL_ID = "source_health_checks"
        const val NOTIFICATION_ID = 4_410
        const val ACTION_START = "com.m5ham3ds.raven23.health.START"
        const val ACTION_UPDATE = "com.m5ham3ds.raven23.health.UPDATE"
        const val ACTION_STOP = "com.m5ham3ds.raven23.health.STOP"
        const val ACTION_OPEN_HEALTH_CHECK = "com.m5ham3ds.raven23.health.OPEN"
        const val EXTRA_OPEN_HEALTH_CHECK = "raven23.open_source_health"
        const val EXTRA_VIDEO_DONE = "videoDone"
        const val EXTRA_VIDEO_TOTAL = "videoTotal"
        const val EXTRA_MIHON_DONE = "mihonDone"
        const val EXTRA_MIHON_TOTAL = "mihonTotal"
        private const val REQUEST_OPEN_HEALTH_CHECK = 4_411

        @Volatile
        var isActive: Boolean = false
            private set

        fun start(context: Context) {
            val intent = Intent(context, SourceHealthForegroundService::class.java)
                .setAction(ACTION_START)
            isActive = true
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (error: Exception) {
                isActive = false
                throw error
            }
        }

        fun update(
            context: Context,
            videoDone: Int,
            videoTotal: Int,
            mihonDone: Int,
            mihonTotal: Int,
        ) {
            val intent = Intent(context, SourceHealthForegroundService::class.java)
                .setAction(ACTION_UPDATE)
                .putExtra(EXTRA_VIDEO_DONE, videoDone)
                .putExtra(EXTRA_VIDEO_TOTAL, videoTotal)
                .putExtra(EXTRA_MIHON_DONE, mihonDone)
                .putExtra(EXTRA_MIHON_TOTAL, mihonTotal)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            // stopService is valid when the app is backgrounded. Sending a new
            // ACTION_STOP with startService can be rejected by Android's
            // background-service restrictions after the user leaves RAVEN23.
            isActive = false
            context.stopService(
                Intent(context, SourceHealthForegroundService::class.java),
            )
        }
    }
}
