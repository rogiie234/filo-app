package com.filo.reminders;

import java.util.Locale;
import java.util.function.BooleanSupplier;

final class PhoneGuidePolicy {
    static boolean xiaomi(String manufacturer, String brand) { return family(manufacturer) || family(brand); }
    private static boolean family(String value) {
        if (value == null) return false;
        String normalized=value.trim().toLowerCase(Locale.ROOT);
        return normalized.equals("xiaomi") || normalized.equals("redmi") || normalized.equals("poco");
    }
    static boolean exactStep(int sdk) { return sdk >= 31; }
    static String launch(BooleanSupplier direct, BooleanSupplier fallback) {
        if (direct.getAsBoolean()) return "direct";
        return fallback.getAsBoolean() ? "app_details" : "failed";
    }
}
