package com.filo.reminders;

import android.app.*;
import android.content.*;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import org.json.*;
import java.io.File;
import java.text.DateFormat;
import java.util.*;

/** Native registry is recoverable from the account DB, including after reboot. */
final class DeadlineScheduler {
    static final String CHANNEL = "filo_deadlines", FIRE = "com.filo.reminders.FIRE";
    static final String TAP = "filo.deadline.tap";
    final Context context;
    final SharedPreferences store;
    DeadlineScheduler(Context context) {
        this.context = context.getApplicationContext();
        store = context.getSharedPreferences("filo_deadlines", Context.MODE_PRIVATE);
    }
    private AlarmManager alarms() { return (AlarmManager) context.getSystemService(Context.ALARM_SERVICE); }
    private NotificationManager notifications() { return (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE); }
    boolean exact() { return DeadlinePolicy.exact(Build.VERSION.SDK_INT, Build.VERSION.SDK_INT < 31 || alarms().canScheduleExactAlarms()); }
    synchronized Map<String, Object> status() {
        NotificationChannel channel = notifications().getNotificationChannel(CHANNEL);
        Map<String, Object> result = new HashMap<>();
        result.put("enabled", notifications().areNotificationsEnabled() && (channel == null || channel.getImportance() != 0));
        result.put("exact", exact());
        result.put("error", store.getBoolean("error", false));
        return result;
    }
    private void commit(SharedPreferences.Editor editor) {
        if (!editor.commit()) throw new IllegalStateException("Could not persist reminder state");
    }
    private JSONArray registry() { try { return new JSONArray(store.getString("registry", "[]")); } catch (JSONException e) { throw new IllegalStateException(e); } }
    private SQLiteDatabase database() throws Exception {
        File file = new File(store.getString("database", "")).getCanonicalFile();
        File root = new File(context.getApplicationInfo().dataDir).getCanonicalFile();
        if (!file.getPath().startsWith(root.getPath() + File.separator)) throw new SecurityException("Invalid account path");
        return SQLiteDatabase.openDatabase(file.getPath(), null, SQLiteDatabase.OPEN_READONLY | SQLiteDatabase.NO_LOCALIZED_COLLATORS);
    }
    private String value(SQLiteDatabase db, String key) {
        try (Cursor c = db.rawQuery("SELECT value FROM file_settings WHERE key=?", new String[]{key})) { return c.moveToFirst() ? c.getString(0) : ""; }
    }
    private JSONArray desired() throws Exception {
        try (SQLiteDatabase db = database()) {
            if (!store.getString("lease", "").equals(value(db, "deadline_lease"))) return new JSONArray();
            String plan = value(db, "deadline_desired");
            return new JSONArray(plan.isEmpty() ? "[]" : plan);
        }
    }
    private PendingIntent intent(JSONObject row) throws Exception {
        Intent i = new Intent(context, DeadlineReceiver.class).setAction(FIRE)
            .setData(Uri.parse("filo-deadline://" + store.getString("account", "") + "/" + row.getInt("id")))
            .putExtra("id", row.getInt("id")).putExtra("account", store.getString("account", ""))
            .putExtra("lease", store.getString("lease", "")).putExtra("fireAt", row.getLong("fireAt"));
        return PendingIntent.getBroadcast(context, row.getInt("id"), i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }
    private String token(JSONObject row) throws Exception { return row.getInt("id") + ":" + row.getLong("fireAt"); }
    private void cancel(JSONObject row) throws Exception {
        alarms().cancel(intent(row));
        notifications().cancel("deadline:" + store.getString("account", ""), row.getInt("id"));
    }
    void activate(String account, String lease, String path) throws Exception {
        synchronized (DeadlineScheduler.class) {
            if (account.equals(store.getString("account", "")) && lease.equals(store.getString("lease", ""))) return;
            clear();
            commit(store.edit().putString("account", account).putString("lease", lease).putString("database", path));
        }
    }
    void clear() throws Exception {
        synchronized (DeadlineScheduler.class) {
            JSONArray old = registry();
            String account = store.getString("account", "");
            // Invalidate receivers before cancellation, even if Android cleanup fails.
            commit(store.edit().remove("lease"));
            for (int i = 0; i < old.length(); i++) cancel(old.getJSONObject(i));
            for (android.service.notification.StatusBarNotification n : notifications().getActiveNotifications()) {
                if (("deadline:" + account).equals(n.getTag())) notifications().cancel(n.getTag(), n.getId());
            }
            commit(store.edit().clear());
        }
    }
    void reconcile(String account, String lease) throws Exception {
        synchronized (DeadlineScheduler.class) {
            if (!account.equals(store.getString("account", "")) || !lease.equals(store.getString("lease", ""))) throw new IllegalStateException("Reminder account changed");
            restore();
        }
    }
    void restore() throws Exception {
        synchronized (DeadlineScheduler.class) {
            if (store.getString("lease", "").isEmpty()) return;
            JSONArray wanted = desired(), old = registry(), future = new JSONArray();
            Set<String> delivered = new HashSet<>(store.getStringSet("delivered", Collections.emptySet()));
            Set<Integer> ids = new HashSet<>();
            for (int i = 0; i < wanted.length(); i++) {
                JSONObject row = wanted.getJSONObject(i);
                if (DeadlinePolicy.restore(row.getLong("fireAt"), System.currentTimeMillis(), delivered.contains(token(row)))) { future.put(row); ids.add(row.getInt("id")); }
            }
            // Save the plan first; interrupted AlarmManager calls retry from this registry/DB.
            commit(store.edit().putString("registry", future.toString()).putBoolean("error", true));
            for (int i = 0; i < old.length(); i++) if (!ids.contains(old.getJSONObject(i).getInt("id"))) cancel(old.getJSONObject(i));
            notifications().createNotificationChannel(new NotificationChannel(CHANNEL, "Assignment deadlines", NotificationManager.IMPORTANCE_DEFAULT));
            for (int i = 0; i < future.length(); i++) {
                JSONObject row = future.getJSONObject(i);
                PendingIntent pending = intent(row);
                if (exact()) {
                    try { alarms().setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, row.getLong("fireAt"), pending); }
                    catch (SecurityException e) { alarms().setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, row.getLong("fireAt"), pending); }
                } else alarms().setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, row.getLong("fireAt"), pending);
            }
            Set<String> retained = new HashSet<>();
            for (int i = 0; i < wanted.length(); i++) if (delivered.contains(token(wanted.getJSONObject(i)))) retained.add(token(wanted.getJSONObject(i)));
            commit(store.edit().putStringSet("delivered", retained).putBoolean("error", false));
        }
    }
    private boolean eligible(JSONObject row) throws Exception {
        try (SQLiteDatabase db = database(); Cursor c = db.rawQuery(
            "SELECT p.due_at FROM cache_posts p JOIN cache_classes c ON c.id=p.class_id " +
            "JOIN cache_profiles u ON u.id=? WHERE p.id=? AND u.role='student' AND u.deleted_at IS NULL AND p.kind='assignment' " +
            "AND p.deleted_at IS NULL AND c.deleted_at IS NULL AND c.archived_at IS NULL " +
            "AND EXISTS(SELECT 1 FROM cache_class_members m WHERE m.class_id=c.id AND m.student_id=u.id AND m.status='active') " +
            "AND NOT EXISTS(SELECT 1 FROM cache_submissions s WHERE s.post_id=p.id AND s.student_id=u.id AND s.status='turned_in')",
            new String[]{store.getString("account", ""), row.getString("postId")})) {
            return c.moveToFirst() && !c.isNull(0) && c.getLong(0) * 1000 == row.getLong("dueAt");
        }
    }
    void fire(Intent intent) throws Exception {
        synchronized (DeadlineScheduler.class) {
            String account = store.getString("account", ""), lease = store.getString("lease", "");
            if (!DeadlinePolicy.current(account, lease, intent.getStringExtra("account"), intent.getStringExtra("lease"))) return;
            JSONArray wanted = desired();
            for (int i = 0; i < wanted.length(); i++) {
                JSONObject row = wanted.getJSONObject(i);
                if (row.getInt("id") != intent.getIntExtra("id", 0) || row.getLong("fireAt") != intent.getLongExtra("fireAt", 0)) continue;
                if (!DeadlinePolicy.deliver(row.getLong("fireAt"), row.getLong("dueAt"), System.currentTimeMillis()) || !eligible(row)) return;
                Set<String> delivered = new HashSet<>(store.getStringSet("delivered", Collections.emptySet()));
                if (!delivered.add(token(row))) return;
                commit(store.edit().putStringSet("delivered", delivered));
                if (!(Boolean) status().get("enabled")) return;
                JSONObject tap = new JSONObject().put("accountId", account).put("postId", row.getString("postId")).put("nonce", token(row));
                Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
                if (launch == null) return;
                launch.setAction("com.filo.reminders.OPEN").setData(Uri.parse("filo-deadline-tap://" + account + "/" + row.getInt("id"))).putExtra(TAP, tap.toString());
                PendingIntent open = PendingIntent.getActivity(context, row.getInt("id"), launch, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                String body = row.getString("title") + " in " + row.getString("className") + " is due " + DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(new Date(row.getLong("dueAt"))) + ".";
                notifications().notify("deadline:" + account, row.getInt("id"), new Notification.Builder(context, CHANNEL)
                    .setSmallIcon(com.filo.reminders.R.drawable.filo_deadline).setContentTitle("Assignment due").setContentText(body)
                    .setStyle(new Notification.BigTextStyle().bigText(body)).setContentIntent(open).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build());
                return;
            }
        }
    }
    void failed() { store.edit().putBoolean("error", true).commit(); }
}
