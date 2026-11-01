package com.filo.reminders;

import android.content.*;

public final class DeadlineReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        PendingResult pending = goAsync();
        DeadlineReminderPlugin.WORK.execute(() -> {
            DeadlineScheduler scheduler = new DeadlineScheduler(context);
            try {
                if (DeadlineScheduler.FIRE.equals(intent.getAction())) scheduler.fire(intent);
                else if (StudyScheduler.FIRE.equals(intent.getAction())) new StudyScheduler(scheduler).fire(intent);
                else {
                    try { scheduler.restore(); } catch(Exception e) { scheduler.failed(); }
                    new StudyScheduler(scheduler).restore();
                }
            } catch (Exception e) {
                if (!DeadlineScheduler.FIRE.equals(intent.getAction())) new StudyScheduler(scheduler).failed();
                else scheduler.failed();
            }
            finally { pending.finish(); }
        });
    }
}
