package com.filo.reminders;

import android.content.*;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
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
                        case "clear": scheduler.clear(); break;
                        case "status": response = scheduler.status(); break;
                        case "openSettings": openSettings(call.argument("section")); break;
                        default: main.post(result::notImplemented); return;
                    }
                    Object answer = response; main.post(() -> result.success(answer));
                } catch (Exception e) {
                    scheduler.failed(); main.post(() -> result.error("REMINDER_UNAVAILABLE", "Could not update deadline reminders", null));
                }
            });
        });
    }
    private void openSettings(String section) {
        Intent intent;
        if ("alarm".equals(section) && Build.VERSION.SDK_INT >= 31) intent = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:" + scheduler.context.getPackageName()));
        else if ("autostart".equals(section)) intent = new Intent().setComponent(new ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"));
        else intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + scheduler.context.getPackageName()));
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try { scheduler.context.startActivity(intent); }
        catch (Exception e) { scheduler.context.startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + scheduler.context.getPackageName())).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); }
    }
    @Override public boolean onNewIntent(Intent intent) { consume(intent); return false; }
    private void consume(Intent intent) {
        String raw = intent.getStringExtra(DeadlineScheduler.TAP);
        if (raw == null) return;
        intent.removeExtra(DeadlineScheduler.TAP);
        try {
            JSONObject data = new JSONObject(raw);
            tap = new HashMap<>();
            for (String key : Arrays.asList("accountId", "postId", "nonce")) tap.put(key, data.getString(key));
            channel.invokeMethod("tap", tap);
        } catch (Exception ignored) { tap = null; }
    }
    @Override public void onAttachedToActivity(ActivityPluginBinding binding) { activity = binding; binding.addOnNewIntentListener(this); consume(binding.getActivity().getIntent()); }
    @Override public void onDetachedFromActivity() { if (activity != null) activity.removeOnNewIntentListener(this); activity = null; }
    @Override public void onDetachedFromActivityForConfigChanges() { onDetachedFromActivity(); }
    @Override public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) { onAttachedToActivity(binding); }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) { channel.setMethodCallHandler(null); }
}
