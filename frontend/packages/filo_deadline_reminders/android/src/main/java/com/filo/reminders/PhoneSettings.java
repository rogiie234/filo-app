package com.filo.reminders;

import android.content.*;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import java.util.*;

final class PhoneSettings {
    private final Context context;
    PhoneSettings(Context context) { this.context=context; }
    Map<String,Object> capabilities() {
        Map<String,Object> result=new HashMap<>();
        result.put("sdk",Build.VERSION.SDK_INT);
        result.put("xiaomi",PhoneGuidePolicy.xiaomi(Build.MANUFACTURER,Build.BRAND));
        return result;
    }
    String open(String section) {
        Intent direct=null;
        if ("alarm".equals(section)) {
            if (PhoneGuidePolicy.exactStep(Build.VERSION.SDK_INT)) direct=new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,Uri.parse("package:"+context.getPackageName()));
        } else if ("autostart".equals(section) || "battery".equals(section)) {
            if (PhoneGuidePolicy.xiaomi(Build.MANUFACTURER,Build.BRAND)) {
                if ("autostart".equals(section)) direct=new Intent().setComponent(new ComponentName("com.miui.securitycenter","com.miui.permcenter.autostart.AutoStartManagementActivity"));
                else direct=new Intent().setComponent(new ComponentName("com.miui.powerkeeper","com.miui.powerkeeper.ui.HiddenAppsConfigActivity"))
                    .putExtra("package_name",context.getPackageName()).putExtra("package_label",context.getApplicationInfo().loadLabel(context.getPackageManager()).toString());
            }
        } else throw new IllegalArgumentException("Unknown phone guide step");
        // OEM activities are best-effort; the guide reports app-details fallback explicitly.
        Intent target=direct;
        return PhoneGuidePolicy.launch(()->target!=null && attempt(target),()->attempt(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:"+context.getPackageName()))));
    }
    private boolean attempt(Intent intent) {
        try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            if (intent.resolveActivity(context.getPackageManager())==null) return false;
            context.startActivity(intent);
            return true;
        } catch (RuntimeException e) { return false; }
    }
}
