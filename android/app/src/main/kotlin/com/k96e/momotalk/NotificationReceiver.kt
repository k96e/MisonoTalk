package com.k96e.momotalk

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class NotificationReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "default title"
        val message = intent.getStringExtra("message") ?: "default message"
        val showAvatar = intent.getBooleanExtra("showAvatar", true)

        showNotification(context, title, message, showAvatar)
    }

    private fun showNotification(context: Context, title: String, message: String, showAvatar: Boolean = true) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "k96e.momotalk.notification"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "notification",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Message notifications"
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("notification_source", "external_event")
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        if (showAvatar) {
            try {
                val largeIcon = android.graphics.BitmapFactory.decodeResource(context.resources, R.drawable.head_round)
                notificationBuilder.setLargeIcon(largeIcon)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        notificationManager.notify(java.util.Random().nextInt(), notificationBuilder.build())
    }
}