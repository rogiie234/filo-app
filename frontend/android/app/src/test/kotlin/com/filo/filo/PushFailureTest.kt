package com.filo.filo

import org.junit.Assert.*
import org.junit.Test
import java.io.IOException
import java.util.concurrent.ExecutionException

class PushFailureTest {
    @Test fun extractsNestedMarkerWithoutPrivateMessage() {
        val error = IOException("FCM Registration failed!",
            ExecutionException(IOException("AUTHENTICATION_FAILED synthetic-private-token")))
        val summary = pushFailureSummary(error)
        assertTrue(summary.contains("IOException > ExecutionException > IOException"))
        assertTrue(summary.contains("AUTHENTICATION_FAILED"))
        assertFalse(summary.contains("synthetic-private-token"))
        assertFalse(summary.contains("FCM Registration failed!"))
    }
    @Test fun unknownMessageIsNotReturned() {
        val summary = pushFailureSummary(IllegalStateException("synthetic-private-config"))
        assertTrue(summary.contains("codes=unspecified"))
        assertFalse(summary.contains("synthetic-private-config"))
    }
    @Test fun missingCauseIsSafe() {
        assertEquals("types=; codes=unspecified", pushFailureSummary(null))
    }
}
