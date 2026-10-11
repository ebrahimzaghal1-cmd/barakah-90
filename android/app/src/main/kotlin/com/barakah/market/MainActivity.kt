package com.barakah.market

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val notificationChannelId =
        "barakah_orders"

    private val urgentOrderChannelId =
        "barakah_urgent_orders_v3"

    private val coinOrderChannelId =
        "barakah_orders_coin_v1"

    private val coinUrgentOrderChannelId =
        "barakah_urgent_orders_coin_v1"

    private val notificationMethodChannel =
        "com.barakah.market/notifications"


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createBarakahOrdersChannels()
    }


    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationMethodChannel
        ).setMethodCallHandler { call, result ->

            if (call.method != "show") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val title =
                call.argument<String>("title").orEmpty()

            val body =
                call.argument<String>("body").orEmpty()

            val tag =
                call.argument<String>("tag").orEmpty()

            val urgent =
                call.argument<Boolean>("urgent") == true

            val coinSound =
                call.argument<Boolean>("coinSound") == true

            if (title.isBlank() || body.isBlank()) {
                result.error(
                    "invalid_notification",
                    "العنوان والنص مطلوبان.",
                    null
                )
                return@setMethodCallHandler
            }

            val blockedReason =
                notificationBlockedReason(
                    urgent = urgent,
                    coinSound = coinSound
                )

            if (blockedReason != null) {
                result.error(
                    "notifications_disabled",
                    blockedReason,
                    null
                )
                return@setMethodCallHandler
            }

            showForegroundNotification(
                title = title,
                body = body,
                tag = tag,
                urgent = urgent,
                coinSound = coinSound
            )

            result.success(null)
        }
    }


    private fun coinSoundUri() =
        android.net.Uri.parse(
            "android.resource://$packageName/${R.raw.barakah_coin}"
        )


    private fun createBarakahOrdersChannels() {

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager =
            getSystemService(NotificationManager::class.java)

        /*
         * القناة العادية القديمة.
         * نبقيها حتى لا تتأثر إشعارات غير الطلبات.
         */
        val normalChannel =
            NotificationChannel(
                notificationChannelId,
                "إشعارات بركة",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description =
                    "إشعارات بركة العامة"
                enableVibration(true)
                setShowBadge(true)
                lockscreenVisibility =
                    Notification.VISIBILITY_PUBLIC
            }

        manager.createNotificationChannel(normalChannel)


        /*
         * القناة العاجلة القديمة كاحتياط.
         */
        val alarmSound =
            RingtoneManager.getDefaultUri(
                RingtoneManager.TYPE_ALARM
            )

        val alarmAttributes =
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(
                    AudioAttributes.CONTENT_TYPE_SONIFICATION
                )
                .build()

        val urgentChannel =
            NotificationChannel(
                urgentOrderChannelId,
                "طلبات جديدة - عاجل",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description =
                    "إشعارات الطلبات العاجلة في بركة"
                enableVibration(true)
                vibrationPattern =
                    longArrayOf(
                        0,
                        700,
                        250,
                        700,
                        250,
                        1000
                    )
                setSound(
                    alarmSound,
                    alarmAttributes
                )
                setShowBadge(true)
                lockscreenVisibility =
                    Notification.VISIBILITY_PUBLIC
            }

        manager.createNotificationChannel(urgentChannel)


        /*
         * صوت الليرة المخصص.
         */
        val coinSound =
            coinSoundUri()

        val coinAttributes =
            AudioAttributes.Builder()
                .setUsage(
                    AudioAttributes.USAGE_NOTIFICATION
                )
                .setContentType(
                    AudioAttributes.CONTENT_TYPE_SONIFICATION
                )
                .build()


        /*
         * تحديث حالة الطلب:
         * صوت ليرة + اهتزاز عادي.
         */
        val coinOrderChannel =
            NotificationChannel(
                coinOrderChannelId,
                "تحديثات الطلبات 🪙",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description =
                    "رنة الليرة عند تحديث حالة الطلب"

                enableVibration(true)

                vibrationPattern =
                    longArrayOf(
                        0,
                        180,
                        100,
                        220
                    )

                setSound(
                    coinSound,
                    coinAttributes
                )

                setShowBadge(true)

                lockscreenVisibility =
                    Notification.VISIBILITY_PUBLIC
            }

        manager.createNotificationChannel(
            coinOrderChannel
        )


        /*
         * طلب جديد:
         * نفس صوت الليرة لكن بأولوية وتنبيه أقوى.
         */
        val coinUrgentChannel =
            NotificationChannel(
                coinUrgentOrderChannelId,
                "طلبات جديدة 🪙",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {

                description =
                    "رنة الليرة للطلبات الجديدة"

                enableVibration(true)

                vibrationPattern =
                    longArrayOf(
                        0,
                        450,
                        150,
                        450,
                        150,
                        650
                    )

                setSound(
                    coinSound,
                    coinAttributes
                )

                setShowBadge(true)

                lockscreenVisibility =
                    Notification.VISIBILITY_PUBLIC
            }

        manager.createNotificationChannel(
            coinUrgentChannel
        )
    }


    private fun notificationBlockedReason(
        urgent: Boolean,
        coinSound: Boolean
    ): String? {

        val manager =
            getSystemService(NotificationManager::class.java)

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.N &&
            !manager.areNotificationsEnabled()
        ) {
            return "إشعارات تطبيق بركة معطلة من إعدادات الهاتف."
        }

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ) {

            val channelId =
                when {
                    coinSound && urgent ->
                        coinUrgentOrderChannelId

                    coinSound ->
                        coinOrderChannelId

                    urgent ->
                        urgentOrderChannelId

                    else ->
                        notificationChannelId
                }

            var channel =
                manager.getNotificationChannel(
                    channelId
                )

            if (channel == null) {
                createBarakahOrdersChannels()

                channel =
                    manager.getNotificationChannel(
                        channelId
                    )
            }

            if (
                channel != null &&
                channel.importance ==
                NotificationManager.IMPORTANCE_NONE
            ) {
                return "قناة إشعارات بركة معطلة من إعدادات الهاتف."
            }
        }

        return null
    }


    @Suppress("DEPRECATION")
    private fun showForegroundNotification(
        title: String,
        body: String,
        tag: String,
        urgent: Boolean,
        coinSound: Boolean
    ) {

        val manager =
            getSystemService(NotificationManager::class.java)

        val launchIntent =
            packageManager
                .getLaunchIntentForPackage(packageName)
                ?.apply {
                    flags =
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                }

        val notificationId =
            tag.ifBlank { title }.hashCode()

        val contentIntent =
            launchIntent?.let {

                PendingIntent.getActivity(
                    this,
                    notificationId,
                    it,
                    PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE
                )
            }


        val channelId =
            when {
                coinSound && urgent ->
                    coinUrgentOrderChannelId

                coinSound ->
                    coinOrderChannelId

                urgent ->
                    urgentOrderChannelId

                else ->
                    notificationChannelId
            }


        val builder =
            if (
                Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.O
            ) {

                Notification.Builder(
                    this,
                    channelId
                )

            } else {

                Notification.Builder(this)
            }


        builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(!urgent)
            .setOngoing(urgent)
            .setCategory(
                if (urgent) {
                    Notification.CATEGORY_ALARM
                } else {
                    Notification.CATEGORY_MESSAGE
                }
            )
            .setVisibility(
                Notification.VISIBILITY_PUBLIC
            )


        contentIntent?.let(
            builder::setContentIntent
        )


        /*
         * Android 7.1 وما قبله لا يستخدم NotificationChannel.
         */
        if (
            Build.VERSION.SDK_INT <
            Build.VERSION_CODES.O
        ) {

            if (coinSound) {

                builder
                    .setPriority(
                        if (urgent) {
                            Notification.PRIORITY_MAX
                        } else {
                            Notification.PRIORITY_HIGH
                        }
                    )
                    .setSound(
                        coinSoundUri(),
                        AudioManager.STREAM_NOTIFICATION
                    )
                    .setVibrate(
                        if (urgent) {
                            longArrayOf(
                                0,
                                450,
                                150,
                                450,
                                150,
                                650
                            )
                        } else {
                            longArrayOf(
                                0,
                                180,
                                100,
                                220
                            )
                        }
                    )

            } else if (urgent) {

                builder
                    .setPriority(
                        Notification.PRIORITY_MAX
                    )
                    .setSound(
                        RingtoneManager.getDefaultUri(
                            RingtoneManager.TYPE_ALARM
                        ),
                        AudioManager.STREAM_ALARM
                    )
                    .setVibrate(
                        longArrayOf(
                            0,
                            700,
                            250,
                            700,
                            250,
                            1000
                        )
                    )

            } else {

                builder
                    .setPriority(
                        Notification.PRIORITY_HIGH
                    )
                    .setDefaults(
                        Notification.DEFAULT_SOUND or
                            Notification.DEFAULT_VIBRATE
                    )
            }
        }


        manager.notify(
            notificationId,
            builder.build()
        )
    }
}
