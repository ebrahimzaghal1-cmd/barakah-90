package com.barakah.market

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationChannelId = "barakah_orders"
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
            if (title.isBlank() || body.isBlank()) {
                result.error("invalid_notification", "العنوان والنص مطلوبان.", null)
                return@setMethodCallHandler
            }

            showForegroundNotification(title, body, tag)
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
        }
    }

    @Suppress("DEPRECATION")
    private fun showForegroundNotification(title: String, body: String, tag: String) {
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
            android.app.Notification.Builder(this, notificationChannelId)
        } else {
            android.app.Notification.Builder(this)
        }

        builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
        contentIntent?.let(builder::setContentIntent)
        val notification = builder.build()

        manager.notify(tag.ifBlank { title }.hashCode(), notification)
    }
}
