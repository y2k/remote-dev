package io.y2k.remote_client

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class VoiceRecordingTest {
    @Test
    fun releaseAndFinalResultCommuteAndCancellationDiscardsText() {
        for (early in listOf(false, true)) {
            val events = mutableListOf<String>()
            val session = VoiceRecording({ events.add(it) }, { events.add("stop") }, { events.add("dispose") })
            if (early) {
                session.endOfSpeech()
                session.result("voice")
                assertEquals(emptyList<String>(), events)
                session.release()
            } else {
                session.release()
                assertEquals(listOf("stop"), events)
                session.result("voice")
            }
            assertEquals(if (early) listOf("dispose", "voice") else listOf("stop", "dispose", "voice"), events)
            session.result("duplicate")
            session.release()
            assertEquals(1, events.count { it == "voice" })
            assertFalse(session.active)
        }
        for (early in listOf(false, true)) {
            val events = mutableListOf<String>()
            val session = VoiceRecording({ events.add(it) }, {}, { events.add("dispose") })
            if (early) session.result("retained")
            session.cancel()
            session.result("late")
            session.release()
            assertEquals(listOf("dispose"), events)
        }
        val events = mutableListOf<String>()
        val empty = VoiceRecording({ events.add(it) }, {}, {})
        empty.result("  ")
        empty.release()
        assertFalse(empty.active)
        assertEquals(emptyList<String>(), events)
    }
}
