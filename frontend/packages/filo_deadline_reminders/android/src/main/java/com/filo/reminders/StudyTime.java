package com.filo.reminders;

import java.time.*;
import java.time.zone.ZoneOffsetTransition;

final class StudyTime {
    static boolean futureOnce(long at, long now, boolean consumed) { return at > now && !consumed; }
    static ZonedDateTime at(LocalDate date, int minute, ZoneId zone) {
        LocalDateTime local = date.atTime(minute / 60, minute % 60);
        ZoneOffsetTransition gap = zone.getRules().getTransition(local);
        if (gap != null && gap.isGap()) local = gap.getDateTimeAfter();
        return local.atZone(zone).withEarlierOffsetAtOverlap();
    }
    static long next(int minute, int weekday, long now, String consumedDate, ZoneId zone) {
        LocalDate start = Instant.ofEpochMilli(now).atZone(zone).toLocalDate();
        for (int d=0; d<=7; d++) {
            LocalDate date = start.plusDays(d);
            long time = at(date, minute, zone).toInstant().toEpochMilli();
            if (date.getDayOfWeek().getValue() == weekday && time > now && !date.toString().equals(consumedDate)) return time;
        }
        throw new IllegalStateException("No future study occurrence");
    }
}
