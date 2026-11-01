package com.filo.reminders;

import android.content.*;
import android.os.*;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.*;
import io.flutter.plugin.common.*;
import org.json.JSONObject;
import java.util.*;
import java.util.concurrent.*;

public final class DeadlineReminderPlugin implements FlutterPlugin, ActivityAware, PluginRegistry.NewIntentListener {
    static final ExecutorService WORK = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private MethodChannel channel;
    private DeadlineScheduler scheduler;
    private ActivityPluginBinding activity;
    private Map<String, Object> tap;
    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        scheduler = new DeadlineScheduler(binding.getApplicationContext());
        channel = new MethodChannel(binding.getBinaryMessenger(), "com.filo.filo/deadline_reminders");
        channel.setMethodCallHandler((call, result) -> {
            if (call.method.equals("takeTap")) { result.success(tap); tap = null; return; }
            WORK.execute(() -> {
                try {
                    Object response = null;
                    switch (call.method) {
                        case "activate": scheduler.activate(call.argument("accountId"), call.argument("lease"), call.argument("database")); break;
                        case "reconcile": scheduler.reconcile(call.argument("accountId"), call.argument("lease")); break;
                        case "studyReconcile":
                            if (!DeadlinePolicy.current(scheduler.store.getString("account",""), scheduler.store.getString("lease",""),call.argument("accountId"),call.argument("lease"))) throw new IllegalStateException("Alarm account changed");
                            try { response = new StudyScheduler(scheduler).restore(); }
                            catch(Exception e) { new StudyScheduler(scheduler).failed(); throw e; }
                            break;
                        case "clear": scheduler.clear(); break;
                        case "status": response = scheduler.status(); break;
                        case "openSettings": openSettings(call.argument("section")); break;
                        case "guideCapabilities": response=new PhoneSettings(scheduler.context).capabilities(); break;
                        case "guideOpenSettings": response=new PhoneSettings(scheduler.context).open(call.argument("section")); break;
                        default: main.post(result::notImplemented); return;
                    }
                    Object answer = response; main.post(() -> result.success(answer));
                } catch (Exception e) {
                    if (!call.method.equals("studyReconcile") && !call.method.equals("openSettings") && !call.method.startsWith("guide")) scheduler.failed();
                    main.post(() -> result.error("REMINDER_UNAVAILABLE", "Could not update local reminders", null));
                }
            });
        });
    }
    private void openSettings(String section) {
        if ("failed".equals(new PhoneSettings(scheduler.context).open(section))) throw new IllegalStateException("Phone settings unavailable");
    }
    @Override public boolean onNewIntent(Intent intent) { consume(intent); return false; }
    private void consume(Intent intent) {
        String raw = intent.getStringExtra(DeadlineScheduler.TAP);
        if (raw == null) return;
        intent.removeExtra(DeadlineScheduler.TAP);
        try {
            JSONObject data = new JSONObject(raw);
            tap = new HashMap<>();
            boolean study = "study".equals(data.optString("kind"));
            tap.put("kind", study ? "study" : "deadline");
            for (String key : Arrays.asList("accountId", study ? "alarmId" : "postId", "nonce")) tap.put(key, data.getString(key));
            channel.invokeMethod("tap", tap);
        } catch (Exception ignored) { tap = null; }
    }
    @Override public void onAttachedToActivity(ActivityPluginBinding binding) { activity = binding; binding.addOnNewIntentListener(this); consume(binding.getActivity().getIntent()); }
    @Override public void onDetachedFromActivity() { if (activity != null) activity.removeOnNewIntentListener(this); activity = null; }
    @Override public void onDetachedFromActivityForConfigChanges() { onDetachedFromActivity(); }
    @Override public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) { onAttachedToActivity(binding); }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) { channel.setMethodCallHandler(null); }
}
