package com.barakah.market

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationChannelId = "barakah_orders"
    private val urgentOrderChannelId = "barakah_urgent_orders_v2"
    private val notificationMethodChannel = "com.barakah.market/notifications"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createBarakahOrdersChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationMethodChannel
        ).setMethodCallHandler { call, result ->
            if (call.method != "show") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val title = call.argument<String>("title").orEmpty()
            val body = call.argument<String>("body").orEmpty()
            val tag = call.argument<String>("tag").orEmpty()
            val urgent = call.argument<Boolean>("urgent") == true
            if (title.isBlank() || body.isBlank()) {
                result.error("invalid_notification", "العنوان والنص مطلوبان.", null)
                return@setMethodCallHandler
            }

            showForegroundNotification(title, body, tag, urgent)
            result.success(null)
        }
    }

    private fun createBarakahOrdersChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                notificationChannelId,
                "طلبات بركة",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "إشعارات الطلبات وحالاتها في بركة"
                enableVibration(true)
                setShowBadge(true)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)

            val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .build()
            val urgentChannel = NotificationChannel(
                urgentOrderChannelId,
                "طلبات جديدة - عاجل",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "تنبيه واضح ومستمر للطلبات الجديدة حتى فتحها"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 700, 250, 700, 250, 1000)
                setSound(alarmSound, audioAttributes)
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(urgentChannel)
        }
    }

    @Suppress("DEPRECATION")
    private fun showForegroundNotification(title: String, body: String, tag: String, urgent: Boolean) {
        val manager = getSystemService(NotificationManager::class.java)
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                tag.ifBlank { title }.hashCode(),
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(
                this,
                if (urgent) urgentOrderChannelId else notificationChannelId
            )
        } else {
            android.app.Notification.Builder(this)
        }

        builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(!urgent)
            .setOngoing(urgent)
            .setCategory(if (urgent) android.app.Notification.CATEGORY_ALARM else android.app.Notification.CATEGORY_MESSAGE)
            .setVisibility(android.app.Notification.VISIBILITY_PUBLIC)
        contentIntent?.let(builder::setContentIntent)
        val notification = builder.build()

        manager.notify(tag.ifBlank { title }.hashCode(), notification)
    }
}
