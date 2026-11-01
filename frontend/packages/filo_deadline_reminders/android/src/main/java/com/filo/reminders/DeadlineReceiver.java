package com.filo.reminders;

import android.content.*;

public final class DeadlineReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        PendingResult pending = goAsync();
        DeadlineReminderPlugin.WORK.execute(() -> {
            DeadlineScheduler scheduler = new DeadlineScheduler(context);
            try {
                if (DeadlineScheduler.FIRE.equals(intent.getAction())) scheduler.fire(intent);
                else scheduler.restore();
            } catch (Exception e) { scheduler.failed(); }
            finally { pending.finish(); }
        });
    }
}
