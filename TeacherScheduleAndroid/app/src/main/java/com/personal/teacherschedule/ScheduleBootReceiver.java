package com.personal.teacherschedule;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class ScheduleBootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction()) && ScheduleNotifications.isEnabled(context)) {
            ScheduleNotifications.schedule(context);
        }
    }
}
