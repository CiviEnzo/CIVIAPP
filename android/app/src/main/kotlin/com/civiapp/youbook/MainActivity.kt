package com.civiapp.youbook

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import androidx.core.content.getSystemService
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    createDefaultNotificationChannel()
  }

  private fun createDefaultNotificationChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
      return
    }

    val channelId = "youbook_default"
    val channelName = "Promemoria You Book"
    val channelDescription = "Notifiche per promemoria appuntamenti e comunicazioni"

    val notificationManager = getSystemService<NotificationManager>() ?: return
    val existing = notificationManager.getNotificationChannel(channelId)
    if (existing != null) {
      return
    }

    val channel = NotificationChannel(
      channelId,
      channelName,
      NotificationManager.IMPORTANCE_HIGH,
    ).apply {
      description = channelDescription
      enableLights(true)
      enableVibration(true)
    }

    notificationManager.createNotificationChannel(channel)
  }
}
