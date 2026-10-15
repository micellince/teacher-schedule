package com.personal.teacherschedule;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

public class LessonReminderReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return;
        ScheduleNotifications.createChannel(context);
        String classroom = intent.getStringExtra("classroom");
        String subject = intent.getStringExtra("subject");
        String label = intent.getStringExtra("label");
        int period = intent.getIntExtra("period", 1);
        int startMinute = intent.getIntExtra("startMinute", 0);
        String title = "5分钟后上课 · " + (classroom == null ? "" : classroom);
        String lesson = (label == null || label.isEmpty() ? "第 " + period + " 节" : label)
                + " · " + (subject == null ? "课程" : subject)
                + " · " + String.format("%02d:%02d", startMinute / 60, startMinute % 60);
        Intent open = new Intent(context, MainActivity.class);
        PendingIntent content = PendingIntent.getActivity(context, 0, open,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(context, ScheduleNotifications.CHANNEL_ID)
                : new Notification.Builder(context);
        Notification notification = builder.setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title).setContentText(lesson).setStyle(new Notification.BigTextStyle().bigText(lesson))
                .setContentIntent(content).setAutoCancel(true).build();
        context.getSystemService(NotificationManager.class).notify((int) (System.currentTimeMillis() & 0x7fffffff), notification);
        ScheduleWidgetProvider.updateAll(context);
        if (ScheduleNotifications.isEnabled(context)) ScheduleNotifications.schedule(context);
    }
}
