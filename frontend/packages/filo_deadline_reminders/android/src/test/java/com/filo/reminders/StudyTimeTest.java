package com.filo.reminders;

import org.junit.Test;
import static org.junit.Assert.*;
import java.time.*;

public class StudyTimeTest {
    @Test public void rebootRestoresOnlyFutureUnconsumedOneTimeOccurrences() {
        assertTrue(StudyTime.futureOnce(101,100,false));
        assertFalse(StudyTime.futureOnce(100,100,false));
        assertFalse(StudyTime.futureOnce(99,100,false));
        assertFalse(StudyTime.futureOnce(101,100,true));
    }
    @Test public void weekdaySlotsSkipPastAndAlreadyConsumedDates() {
        ZoneId z=ZoneId.of("Asia/Manila");
        long now=ZonedDateTime.of(2026,11,2,10,0,0,0,z).toInstant().toEpochMilli();
        assertEquals(2,Instant.ofEpochMilli(StudyTime.next(660,1,now,"",z)).atZone(z).getDayOfMonth());
        assertEquals(9,Instant.ofEpochMilli(StudyTime.next(660,1,now,"2026-11-02",z)).atZone(z).getDayOfMonth());
        assertEquals(9,Instant.ofEpochMilli(StudyTime.next(600,1,now,"",z)).atZone(z).getDayOfMonth());
    }
    @Test public void dstGapUsesFirstValidTimeAndOverlapUsesFirstOccurrence() {
        ZoneId z=ZoneId.of("America/New_York");
        assertEquals(LocalTime.of(3,0),StudyTime.at(LocalDate.of(2026,3,8),150,z).toLocalTime());
        ZonedDateTime overlap=StudyTime.at(LocalDate.of(2026,11,1),90,z);
        assertEquals(ZoneOffset.ofHours(-4),overlap.getOffset());
        assertEquals(8,Instant.ofEpochMilli(StudyTime.next(90,7,overlap.toInstant().toEpochMilli(),"2026-11-01",z)).atZone(z).getDayOfMonth());
    }
    @Test public void recurrenceFollowsLocalTimeAfterTimezoneChange() {
        long now=Instant.parse("2026-11-02T00:00:00Z").toEpochMilli();
        ZoneId manila=ZoneId.of("Asia/Manila"), tokyo=ZoneId.of("Asia/Tokyo");
        assertEquals(3600000L,StudyTime.next(600,1,now,"",manila)-StudyTime.next(600,1,now,"",tokyo));
    }
}
