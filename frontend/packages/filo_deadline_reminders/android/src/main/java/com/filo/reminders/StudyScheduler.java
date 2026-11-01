package com.filo.reminders;

import android.app.*;
import android.content.*;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import java.time.*;
import java.util.*;
import org.json.*;

/** Study schedules share the active account lease, but never the deadline registry. */
final class StudyScheduler {
    static final String FIRE="com.filo.reminders.STUDY_FIRE", CHANNEL="filo_study";
    final DeadlineScheduler owner;
    StudyScheduler(DeadlineScheduler owner) { this.owner=owner; }
    private String account() { return owner.store.getString("account",""); }
    private String lease() { return owner.store.getString("lease",""); }
    private AlarmManager alarms() { return (AlarmManager)owner.context.getSystemService(Context.ALARM_SERVICE); }
    private NotificationManager notifications() { return (NotificationManager)owner.context.getSystemService(Context.NOTIFICATION_SERVICE); }
    private JSONArray registry() throws Exception { return new JSONArray(owner.store.getString("study_registry","[]")); }
    private JSONArray shown() throws Exception { return new JSONArray(owner.store.getString("study_shown","[]")); }
    private JSONObject consumed() throws Exception { return new JSONObject(owner.store.getString("study_consumed","{}")); }
    private String key(JSONObject r) throws Exception { return r.getString("alarmId")+":"+r.getString("revision")+":"+r.getInt("weekday"); }
    private PendingIntent pending(JSONObject r) throws Exception {
        Intent i=new Intent(owner.context,DeadlineReceiver.class).setAction(FIRE)
            .setData(Uri.parse("filo-study://"+account()+"/"+r.getInt("id")))
            .putExtra("account",account()).putExtra("lease",lease()).putExtra("id",r.getInt("id"))
            .putExtra("fireAt",r.getLong("fireAt")).putExtra("revision",r.getString("revision"));
        return PendingIntent.getBroadcast(owner.context,r.getInt("id"),i,PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);
    }
    void clear() throws Exception {
        JSONArray cleanup=new JSONArray(owner.store.getString("study_cleanup","[]")), scheduled=registry();
        for(int i=0;i<scheduled.length();i++) cleanup.put(scheduled.getJSONObject(i));
        for(int i=0;i<cleanup.length();i++) {
            JSONObject r=cleanup.getJSONObject(i);
            alarms().cancel(pending(r)); notifications().cancel("study:"+account(),r.getInt("id"));
        }
        for(int i=0;i<shown().length();i++) notifications().cancel("study:"+account(),shown().getJSONObject(i).getInt("id"));
        owner.commit(owner.store.edit().remove("study_registry").remove("study_consumed").remove("study_error").remove("study_shown").remove("study_cleanup").remove("study_once"));
    }
    private JSONArray desired() throws Exception {
        JSONArray rows=new JSONArray();
        JSONObject onceAnchors=new JSONObject(owner.store.getString("study_once","{}")), retainedAnchors=new JSONObject();
        try(SQLiteDatabase db=owner.database()) {
            if(!lease().equals(owner.value(db,"deadline_lease"))) return rows;
            try(Cursor profile=db.rawQuery("SELECT id FROM cache_profiles WHERE id=? AND role='student' AND deleted_at IS NULL",new String[]{account()})) {
                if(!profile.moveToFirst()) return rows;
            }
            try(Cursor c=db.rawQuery("SELECT a.id,a.subject,a.minute_of_day,a.repeat_days,s.weekday,s.system_alarm_id FROM study_alarms a JOIN alarm_slots s ON s.alarm_id=a.id WHERE a.enabled=1",null)) {
                while(c.moveToNext()) {
                    String meta=owner.value(db,"study_alarm:"+c.getString(0));
                    if(meta.isEmpty()) continue;
                    JSONObject m=new JSONObject(meta);
                    LocalDate onceDate=LocalDate.parse(m.getString("onceDate"));
                    long once=StudyTime.at(onceDate,c.getInt(2),ZoneId.systemDefault()).toInstant().toEpochMilli();
                    if(once<=m.getLong("savedAt")) once=StudyTime.at(onceDate.plusDays(1),c.getInt(2),ZoneId.systemDefault()).toInstant().toEpochMilli();
                    int weekday=c.getInt(4), days=c.getInt(3);
                    if((days==0 && weekday!=0)||(days!=0 && (weekday==0 || (days & (1<<(weekday-1)))==0))) continue;
                    if(weekday==0) {
                        String anchorKey=c.getString(0)+":"+m.getString("revision");
                        once=onceAnchors.optLong(anchorKey,once);
                        retainedAnchors.put(anchorKey,once);
                    }
                    rows.put(new JSONObject().put("alarmId",c.getString(0)).put("subject",c.getString(1))
                        .put("minute",c.getInt(2)).put("weekday",weekday).put("id",c.getInt(5))
                        .put("revision",m.getString("revision")).put("onceAt",once));
                }
            }
        }
        owner.commit(owner.store.edit().putString("study_once",retainedAnchors.toString()));
        return rows;
    }
    List<Map<String,String>> restore() throws Exception {
        synchronized(DeadlineScheduler.class) {
            List<Map<String,String>> completed=new ArrayList<>();
            if(lease().isEmpty()) return completed;
            long now=System.currentTimeMillis(); ZoneId zone=ZoneId.systemDefault();
            JSONArray wanted=desired(), old=registry(), future=new JSONArray(); JSONObject done=consumed(), retained=new JSONObject();
            JSONArray cleanup=new JSONArray(owner.store.getString("study_cleanup","[]"));
            for(int i=0;i<old.length();i++) cleanup.put(old.getJSONObject(i));
            Set<String> wantedKeys=new HashSet<>();
            for(int i=0;i<wanted.length();i++) wantedKeys.add(key(wanted.getJSONObject(i)));
            JSONArray keepShown=new JSONArray(), shown=shown();
            for(int i=0;i<shown.length();i++) {
                JSONObject row=shown.getJSONObject(i);
                if(wantedKeys.contains(key(row))) keepShown.put(row);
                else notifications().cancel("study:"+account(),row.getInt("id"));
            }
            owner.commit(owner.store.edit().putString("study_shown",keepShown.toString()));
            Set<Integer> ids=new HashSet<>();
            for(int i=0;i<wanted.length();i++) {
                JSONObject row=wanted.getJSONObject(i); String k=key(row), last=done.optString(k,"");
                long at;
                if(row.getInt("weekday")==0) {
                    at=row.getLong("onceAt");
                    if(!StudyTime.futureOnce(at,now,!last.isEmpty())) {
                        retained.put(k,"once");
                        Map<String,String> result=new HashMap<>(); result.put("id",row.getString("alarmId")); result.put("revision",row.getString("revision")); completed.add(result); continue;
                    }
                } else at=StudyTime.next(row.getInt("minute"),row.getInt("weekday"),now,last,zone);
                if(!last.isEmpty()) retained.put(k,last);
                row.put("fireAt",at); future.put(row); ids.add(row.getInt("id"));
            }
            owner.commit(owner.store.edit().putString("study_registry",future.toString()).putString("study_consumed",retained.toString()).putString("study_cleanup",cleanup.toString()).putBoolean("study_error",true));
            for(int i=0;i<cleanup.length();i++) {
                JSONObject r=cleanup.getJSONObject(i);
                if(!ids.contains(r.getInt("id"))) { alarms().cancel(pending(r)); notifications().cancel("study:"+account(),r.getInt("id")); }
            }
            notifications().createNotificationChannel(new NotificationChannel(CHANNEL,"Study alarms",NotificationManager.IMPORTANCE_DEFAULT));
            for(int i=0;i<future.length();i++) {
                JSONObject r=future.getJSONObject(i); PendingIntent pi=pending(r);
                if(owner.exact()) {
                    try { alarms().setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,r.getLong("fireAt"),pi); }
                    catch(SecurityException e) { alarms().setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,r.getLong("fireAt"),pi); }
                } else alarms().setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,r.getLong("fireAt"),pi);
            }
            owner.commit(owner.store.edit().putBoolean("study_error",false).remove("study_cleanup"));
            return completed;
        }
    }
    void fire(Intent intent) throws Exception {
        synchronized(DeadlineScheduler.class) {
            if(!DeadlinePolicy.current(account(),lease(),intent.getStringExtra("account"),intent.getStringExtra("lease"))) return;
            JSONArray wanted=desired(), scheduled=registry(); long now=System.currentTimeMillis();
            for(int i=0;i<scheduled.length();i++) {
                JSONObject r=scheduled.getJSONObject(i);
                if(r.getInt("id")!=intent.getIntExtra("id",0) || r.getLong("fireAt")!=intent.getLongExtra("fireAt",0) || !r.getString("revision").equals(intent.getStringExtra("revision")) || r.getLong("fireAt")>now) continue;
                boolean valid=false;
                for(int j=0;j<wanted.length();j++) if(key(wanted.getJSONObject(j)).equals(key(r))) valid=true;
                if(!valid) { restore(); return; }
                String date=Instant.ofEpochMilli(r.getLong("fireAt")).atZone(ZoneId.systemDefault()).toLocalDate().toString();
                JSONObject done=consumed(); String k=key(r);
                if(done.optString(k,"").equals(date) || done.optString(k,"").equals("once")) return;
                done.put(k,r.getInt("weekday")==0?"once":date);
                owner.commit(owner.store.edit().putString("study_consumed",done.toString()));
                restore();
                NotificationChannel channel=notifications().getNotificationChannel(CHANNEL);
                if(!notifications().areNotificationsEnabled() || (channel!=null && channel.getImportance()==0)) return;
                Intent launch=owner.context.getPackageManager().getLaunchIntentForPackage(owner.context.getPackageName());
                if(launch==null) return;
                launch.setData(Uri.parse("filo-study-tap://"+account()+"/"+r.getInt("id")))
                    .putExtra(DeadlineScheduler.TAP,new JSONObject().put("kind","study").put("accountId",account()).put("alarmId",r.getString("alarmId")).put("nonce",UUID.randomUUID().toString()).toString());
                PendingIntent tap=PendingIntent.getActivity(owner.context,r.getInt("id"),launch,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
                JSONArray shown=shown(), nextShown=new JSONArray();
                for(int j=0;j<shown.length();j++) if(shown.getJSONObject(j).getInt("id")!=r.getInt("id")) nextShown.put(shown.getJSONObject(j));
                nextShown.put(r);
                owner.commit(owner.store.edit().putString("study_shown",nextShown.toString()));
                notifications().notify("study:"+account(),r.getInt("id"),new Notification.Builder(owner.context,CHANNEL)
                    .setSmallIcon(com.filo.reminders.R.drawable.filo_deadline).setContentTitle("Time to study: "+r.getString("subject"))
                    .setContentText("Open your study material when you're ready.").setVisibility(Notification.VISIBILITY_PRIVATE)
                    .setContentIntent(tap).setAutoCancel(true).build());
                return;
            }
        }
    }
    void failed() { owner.store.edit().putBoolean("study_error",true).commit(); }
}
