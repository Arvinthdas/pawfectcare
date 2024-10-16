package com.example.pawfectcare

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)

        // Check if the Android version is Oreo or higher (API 26+), which requires a notification channel
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Define the notification channel with an ID, name, importance, and description
            val channelId = "channel_id"  // Same ID as used in your Dart code
            val channelName = "Vaccination Reminders"
            val channelDescription = "Channel for vaccination reminders"
            val importance = NotificationManager.IMPORTANCE_HIGH

            // Create the notification channel
            val notificationChannel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
            }

            // Register the channel with the system
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(notificationChannel)
        }
    }
}
