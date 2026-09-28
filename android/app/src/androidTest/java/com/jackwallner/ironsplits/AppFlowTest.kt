package com.jackwallner.ironsplits

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AppFlowTest {
    @get:Rule
    val compose = createAndroidComposeRule<MainActivity>()

    @Test
    fun firstLaunchShowsPublishedResultsSearch() {
        compose.onNodeWithText("Find your race history").assertIsDisplayed()
        compose.onNodeWithTag("athlete-search-field").assertIsDisplayed()
        compose.onNodeWithText("Search sends your name and any optional city or state filter to the public timing service. Your Locker and notes stay on this device.").assertIsDisplayed()
        compose.onNodeWithTag("search-button").assertIsDisplayed()
    }

    @Test
    fun tipsTabOpensOfflineAskPattieTree() {
        compose.onNodeWithText("Tips").performClick()
        compose.onNodeWithText("What are you training for?").assertIsDisplayed()
        compose.onNodeWithText("My first triathlon").assertIsDisplayed()
        compose.onNodeWithText("A 70.3").assertIsDisplayed()
    }

    @Test
    fun liveResultsSearchCanClaimAnAthlete() {
        compose.onNodeWithTag("athlete-search-field").performTextInput("Pattie Wallner")
        compose.onNodeWithTag("search-button").performClick()
        compose.waitUntil(timeoutMillis = 60_000) {
            compose.onAllNodesWithTag("athlete-choice").fetchSemanticsNodes().isNotEmpty()
        }
        assertEquals(1, compose.onAllNodesWithTag("athlete-choice").fetchSemanticsNodes().size)
        compose.onNodeWithTag("athlete-choice").performClick()
        compose.waitUntil(timeoutMillis = 60_000) {
            compose.onAllNodesWithText("Split rankings").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText("Split rankings").assertIsDisplayed()
        compose.onNodeWithTag("locker-athlete-name").assertIsDisplayed()
    }

    @Test
    fun revenueCatTestStorePurchaseUnlocksRaceBook() {
        compose.onNodeWithText("Race Book").performClick()
        compose.waitUntil(timeoutMillis = 30_000) {
            compose.onAllNodesWithText("Unlock Race Book").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("buy-race-book").performClick()
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        assertTrue(device.wait(Until.hasObject(By.text("TEST VALID PURCHASE")), 15_000))
        device.findObject(By.text("TEST VALID PURCHASE")).click()
        val unlockedEmptyState = "The Race Book compares matching distances only, so every split stays meaningful."
        compose.waitUntil(timeoutMillis = 30_000) {
            compose.onAllNodesWithText(unlockedEmptyState).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText(unlockedEmptyState).assertIsDisplayed()
    }
}
