package com.filo.reminders;

import org.junit.Test;
import static org.junit.Assert.*;

public class DeadlinePolicyTest {
    @Test public void rebootRestoresOnlyFutureUndeliveredTimes() {
        assertTrue(DeadlinePolicy.restore(200, 100, false));
        assertFalse(DeadlinePolicy.restore(100, 100, false));
        assertFalse(DeadlinePolicy.restore(90, 100, false));
        assertFalse(DeadlinePolicy.restore(200, 100, true));
    }
    @Test public void lateDeliveryMustStillPrecedeDueDate() {
        assertTrue(DeadlinePolicy.deliver(90, 200, 100));
        assertFalse(DeadlinePolicy.deliver(110, 200, 100));
        assertFalse(DeadlinePolicy.deliver(90, 100, 100));
    }
    @Test public void accountAndSessionMustMatchAfterRestartOrSignOut() {
        assertTrue(DeadlinePolicy.current("A", "session", "A", "session"));
        assertFalse(DeadlinePolicy.current("B", "session", "A", "session"));
        assertFalse(DeadlinePolicy.current("A", "new", "A", "old"));
        assertFalse(DeadlinePolicy.current("A", "", "A", ""));
    }
    @Test public void deniedAccessUsesApproximateSchedulingOnNewAndroid() {
        assertTrue(DeadlinePolicy.exact(30, false));
        assertFalse(DeadlinePolicy.exact(31, false));
        assertTrue(DeadlinePolicy.exact(31, true));
    }
    @Test public void deletionTargetsOnlyItsNativeAccountRegistry() {
        assertTrue(DeadlinePolicy.ownsAccount("A", "A"));
        assertFalse(DeadlinePolicy.ownsAccount("B", "A"));
        assertFalse(DeadlinePolicy.ownsAccount("", "A"));
        assertFalse(DeadlinePolicy.ownsAccount("B", ""));
    }
    @Test public void deletionCancelsOnlyMatchingReminderAndStudyTags() {
        assertTrue(DeadlinePolicy.accountNotification("deadline:A", "A"));
        assertTrue(DeadlinePolicy.accountNotification("study:A", "A"));
        assertFalse(DeadlinePolicy.accountNotification("deadline:B", "A"));
        assertFalse(DeadlinePolicy.accountNotification("study:B", "A"));
        assertFalse(DeadlinePolicy.accountNotification(null, "A"));
        assertFalse(DeadlinePolicy.accountNotification("deadline:A2", "A"));
    }
}
