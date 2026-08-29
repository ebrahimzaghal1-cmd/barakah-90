package com.example.barakah_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createBarakahOrdersChannel()
    }

    private fun createBarakahOrdersChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "barakah_orders",
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
}
