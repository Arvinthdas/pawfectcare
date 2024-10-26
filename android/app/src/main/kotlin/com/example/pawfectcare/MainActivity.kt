package com.example.pawfectcare

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Set the window background to transparent to skip the native background
        window.setBackgroundDrawableResource(android.R.color.transparent)

        // Initialize notification channel if Android version is Oreo or higher
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "channel_id"
            val channelName = "Vaccination Reminders"
            val channelDescription = "Channel for vaccination reminders"
            val importance = NotificationManager.IMPORTANCE_HIGH

            val notificationChannel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(notificationChannel)
        }
    }
}
