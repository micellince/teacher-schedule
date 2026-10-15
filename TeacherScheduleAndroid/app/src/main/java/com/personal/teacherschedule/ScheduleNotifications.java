package com.personal.teacherschedule;

import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Calendar;
import java.util.HashSet;
import java.util.Set;

final class ScheduleNotifications {
    static final String PREFS = "teacher_schedule_android";
    static final String SCHEDULE_KEY = "schedule_json";
    private static final String ENABLED_KEY = "notifications_enabled";
    private static final String ALARM_IDS_KEY = "scheduled_alarm_ids";
    static final String CHANNEL_ID = "class_reminders";
    private static final int DAYS_AHEAD = 14;
    private static final int REMINDER_MINUTES = 5;

    private ScheduleNotifications() {}

    static boolean isEnabled(Context context) {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(ENABLED_KEY, false);
    }

    static void setEnabled(Context context, boolean enabled) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(ENABLED_KEY, enabled).apply();
    }

    static void createChannel(Context context) {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "上课提醒", NotificationManager.IMPORTANCE_DEFAULT);
            channel.setDescription("课程开始前提醒");
            context.getSystemService(NotificationManager.class).createNotificationChannel(channel);
        }
    }

    static void schedule(Context context) {
        cancelAll(context);
        if (!isEnabled(context)) return;
        createChannel(context);
        String json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(SCHEDULE_KEY, "{}");
        try {
            JSONArray courses = new JSONObject(json).optJSONArray("courses");
            if (courses == null) return;
            AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            Calendar today = Calendar.getInstance();
            long now = System.currentTimeMillis();
            Set<String> ids = new HashSet<>();
            for (int offset = 0; offset < DAYS_AHEAD; offset++) {
                Calendar day = (Calendar) today.clone();
                day.add(Calendar.DAY_OF_YEAR, offset);
                int weekday = day.get(Calendar.DAY_OF_WEEK);
                for (int index = 0; index < courses.length(); index++) {
                    JSONObject course = courses.optJSONObject(index);
                    if (course == null || course.optInt("weekday") != weekday) continue;
                    int startMinute = course.optInt("startMinute", -1);
                    int reminderMinute = startMinute - REMINDER_MINUTES;
                    if (reminderMinute < 0) continue;
                    Calendar when = (Calendar) day.clone();
                    when.set(Calendar.HOUR_OF_DAY, reminderMinute / 60);
                    when.set(Calendar.MINUTE, reminderMinute % 60);
                    when.set(Calendar.SECOND, 0);
                    when.set(Calendar.MILLISECOND, 0);
                    if (when.getTimeInMillis() <= now) continue;
                    String id = dateKey(day) + ":" + course.optString("id", String.valueOf(index));
                    int requestCode = id.hashCode() & 0x7fffffff;
                    Intent intent = new Intent(context, LessonReminderReceiver.class);
                    intent.putExtra("classroom", course.optString("classroom", ""));
                    intent.putExtra("subject", course.optString("subject", "课程"));
                    intent.putExtra("label", course.optString("label", ""));
                    intent.putExtra("period", course.optInt("period", 1));
                    intent.putExtra("startMinute", startMinute);
                    PendingIntent pending = PendingIntent.getBroadcast(context, requestCode, intent,
                            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                    alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when.getTimeInMillis(), pending);
                    ids.add(String.valueOf(requestCode));
                }
            }
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putStringSet(ALARM_IDS_KEY, ids).apply();
        } catch (Exception ignored) {
            // Ignore malformed or unavailable data rather than breaking the app.
        }
    }

    static void cancelAll(Context context) {
        Set<String> ids = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getStringSet(ALARM_IDS_KEY, null);
        if (ids == null || ids.isEmpty()) return;
        AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        for (String value : new HashSet<>(ids)) {
            try {
                int requestCode = Integer.parseInt(value);
                PendingIntent pending = PendingIntent.getBroadcast(context, requestCode,
                        new Intent(context, LessonReminderReceiver.class),
                        PendingIntent.FLAG_NO_CREATE | PendingIntent.FLAG_IMMUTABLE);
                if (pending != null) {
                    alarms.cancel(pending);
                    pending.cancel();
                }
            } catch (NumberFormatException ignored) {}
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(ALARM_IDS_KEY).apply();
    }

    private static String dateKey(Calendar day) {
        return day.get(Calendar.YEAR) + "-" + day.get(Calendar.DAY_OF_YEAR);
    }
}
