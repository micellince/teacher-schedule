package com.personal.teacherschedule;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Comparator;
import java.util.List;

public class ScheduleWidgetProvider extends AppWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] widgetIds) {
        for (int widgetId : widgetIds) updateOne(context, manager, widgetId);
    }

    static void updateAll(Context context) {
        AppWidgetManager manager = AppWidgetManager.getInstance(context);
        int[] ids = manager.getAppWidgetIds(new ComponentName(context, ScheduleWidgetProvider.class));
        if (ids.length > 0) new ScheduleWidgetProvider().onUpdate(context, manager, ids);
    }

    private static void updateOne(Context context, AppWidgetManager manager, int widgetId) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.schedule_widget);
        Intent launch = new Intent(context, MainActivity.class);
        PendingIntent click = PendingIntent.getActivity(context, 0, launch,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_root, click);
        renderSchedule(context, views);
        manager.updateAppWidget(widgetId, views);
    }

    private static void renderSchedule(Context context, RemoteViews views) {
        String json = context.getSharedPreferences(ScheduleNotifications.PREFS, Context.MODE_PRIVATE)
                .getString(ScheduleNotifications.SCHEDULE_KEY, "{}");
        Calendar now = Calendar.getInstance();
        int minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE);
        List<JSONObject> courses = new ArrayList<>();
        try {
            JSONArray array = new JSONObject(json).optJSONArray("courses");
            if (array != null) {
                for (int i = 0; i < array.length(); i++) {
                    JSONObject course = array.optJSONObject(i);
                    if (course != null && course.optInt("weekday") == now.get(Calendar.DAY_OF_WEEK)) courses.add(course);
                }
            }
        } catch (Exception ignored) {}
        courses.sort(Comparator.comparingInt(course -> course.optInt("startMinute")));
        JSONObject active = null;
        JSONObject next = null;
        for (JSONObject course : courses) {
            int start = course.optInt("startMinute");
            int end = course.optInt("endMinute");
            if (minute >= start && minute < end) { active = course; break; }
            if (start > minute && next == null) next = course;
        }
        JSONObject shown = active != null ? active : next;
        String state;
        String main;
        String timing;
        if (shown != null) {
            state = active != null ? "正在上课" : "下一节课程";
            main = shown.optString("subject", "课程") + " · " + shown.optString("classroom", "");
            int start = shown.optInt("startMinute");
            int end = shown.optInt("endMinute");
            timing = clock(start) + " — " + clock(end)
                    + (shown.optString("label", "").isEmpty() ? "  ·  第 " + shown.optInt("period", 1) + " 节" : "  ·  " + shown.optString("label"));
        } else {
            state = courses.isEmpty() ? "今天没有课程" : "今日课程已结束";
            main = "接下来好好休息";
            timing = now.get(Calendar.MONTH) + 1 + "月" + now.get(Calendar.DAY_OF_MONTH) + "日";
        }
        views.setTextViewText(R.id.widget_date, String.format("%d月%d日 · 教师课表", now.get(Calendar.MONTH) + 1, now.get(Calendar.DAY_OF_MONTH)));
        views.setTextViewText(R.id.widget_state, state);
        views.setTextViewText(R.id.widget_course, main);
        views.setTextViewText(R.id.widget_time, timing);
    }

    private static String clock(int minute) {
        return String.format("%02d:%02d", minute / 60, minute % 60);
    }
}
