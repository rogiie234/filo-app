package com.filo.reminders;

import org.junit.Test;
import static org.junit.Assert.*;
import java.util.concurrent.atomic.AtomicInteger;

public class PhoneGuidePolicyTest {
    @Test public void recognizesOnlyXiaomiFamilyAndApi31ExactStep() {
        assertTrue(PhoneGuidePolicy.xiaomi(" Xiaomi ","other"));
        assertTrue(PhoneGuidePolicy.xiaomi("other","REDMI"));
        assertTrue(PhoneGuidePolicy.xiaomi(null,"POCO"));
        assertFalse(PhoneGuidePolicy.xiaomi("Samsung","samsung"));
        assertFalse(PhoneGuidePolicy.xiaomi("Google",null));
        assertFalse(PhoneGuidePolicy.xiaomi("not-xiaomi","other"));
        assertFalse(PhoneGuidePolicy.exactStep(30));
        assertTrue(PhoneGuidePolicy.exactStep(31));
    }
    @Test public void launchReportsDirectFallbackAndTotalFailure() {
        AtomicInteger fallback=new AtomicInteger();
        assertEquals("direct",PhoneGuidePolicy.launch(()->true,()->{fallback.incrementAndGet();return true;}));
        assertEquals(0,fallback.get());
        assertEquals("app_details",PhoneGuidePolicy.launch(()->false,()->true));
        assertEquals("failed",PhoneGuidePolicy.launch(()->false,()->false));
    }
}
