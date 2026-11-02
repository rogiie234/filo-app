package com.filo.reminders;

final class DeadlinePolicy {
    static boolean restore(long fireAt, long now, boolean delivered) { return fireAt > now && !delivered; }
    static boolean deliver(long fireAt, long dueAt, long now) { return fireAt <= now && now < dueAt; }
    static boolean current(String account, String lease, String eventAccount, String eventLease) {
        return !lease.isEmpty() && account.equals(eventAccount) && lease.equals(eventLease);
    }
    static boolean ownsAccount(String current, String deleting) {
        return deleting != null && !deleting.isEmpty() && deleting.equals(current);
    }
    static boolean accountNotification(String tag, String account) {
        return account != null && !account.isEmpty() &&
            (("deadline:" + account).equals(tag) || ("study:" + account).equals(tag));
    }
    static boolean exact(int sdk, boolean allowed) { return sdk < 31 || allowed; }
}
