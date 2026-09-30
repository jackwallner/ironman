package com.jackwallner.ironsplits

import com.jackwallner.ironsplits.data.ResultsApi
import com.jackwallner.ironsplits.data.ResultsApiException
import com.jackwallner.ironsplits.data.SearchDepth
import com.jackwallner.ironsplits.data.isCancellation
import com.jackwallner.ironsplits.data.runCancellable
import com.jackwallner.ironsplits.model.UnitPreference
import java.net.HttpURLConnection
import java.net.ServerSocket
import java.net.URL
import kotlin.system.measureTimeMillis
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SearchBehaviourTest {
    @Test
    fun nonBreakingSpacesSplitNameWords() {
        val plain = ResultsApi.nameFilter("wallner pattie")
        assertEquals(plain, ResultsApi.nameFilter("wallner pattie"))
        assertEquals(plain, ResultsApi.nameFilter("wallner pattie"))
        assertEquals(plain, ResultsApi.nameFilter("wallner pattie"))
        assertEquals(plain, ResultsApi.nameFilter(" wallner   pattie "))
        assertTrue(plain.contains("'wallner'") && plain.contains("'pattie'"))
        assertEquals(2, Regex("startswith\\(wtc_ContactId/firstname").findAll(plain).count())
    }

    @Test
    fun nonBreakingSpaceAroundLocationIsTrimmed() {
        val filter = ResultsApi.nameFilter("pattie, Lincoln ", SearchDepth.PREFIX)
        assertTrue(filter.contains("address1_city,'Lincoln')"))
    }

    @Test
    fun britainIsImperialLikeIos() {
        assertEquals(UnitPreference.IMPERIAL, UnitPreference.forCountry("GB"))
        assertEquals(UnitPreference.IMPERIAL, UnitPreference.forCountry("us"))
        assertEquals(UnitPreference.METRIC, UnitPreference.forCountry("DE"))
        assertEquals(UnitPreference.METRIC, UnitPreference.forCountry(""))
    }

    @Test
    fun undecodableBodyUsesTheGenericReachMessage() {
        val message = ResultsApi.userFacingMessage(ResultsApiException.Undecodable())
        assertEquals("Couldn't reach the results site. Please try again.", message)
    }

    @Test
    fun cancellingDisconnectsAnInFlightRequest() {
        ServerSocket(0).use { server ->
            val accepted = Thread { runCatching { server.accept().also { Thread.sleep(30_000) } } }
                .apply { isDaemon = true; start() }
            val connection = URL("http://127.0.0.1:${server.localPort}/").openConnection() as HttpURLConnection
            connection.readTimeout = 30_000
            var thrown: Throwable? = null
            val elapsed = runBlocking {
                val request = async(Dispatchers.IO) {
                    runCancellable(connection) { it.responseCode }
                }
                delay(500)
                measureTimeMillis {
                    request.cancel()
                    thrown = runCatching { request.await() }.exceptionOrNull()
                }
            }
            assertTrue("cancel took ${elapsed}ms", elapsed < 5_000)
            val error = checkNotNull(thrown)
            assertTrue("was $error", isCancellation(error))
            assertTrue(error is CancellationException)
            accepted.interrupt()
        }
    }
}
