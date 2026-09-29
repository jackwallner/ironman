package com.jackwallner.ironsplits

import android.content.Intent
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * End-to-end flows on a real device. The search and claim tests hit the live
 * timing feed on purpose: a mock would only prove the mock still matches.
 */
@RunWith(AndroidJUnit4::class)
class AppFlowTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    private var scenario: ActivityScenario<MainActivity>? = null

    private fun launch(seed: Boolean = false, forcePro: Boolean = false) {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val intent = Intent(context, MainActivity::class.java)
            .putExtra("resetLocker", true)
            .putExtra("uiTest", true)
            .putExtra("seedScreenshotData", seed)
            .putExtra("forcePro", forcePro)
            .putExtra("appearance", "light")
        scenario = ActivityScenario.launch(intent)
    }

    @After
    fun tearDown() {
        scenario?.close()
    }

    private fun waitForText(text: String, timeout: Long = 20_000, substring: Boolean = false) {
        compose.waitUntil(timeout) {
            compose.onAllNodes(hasText(text, substring = substring) or hasContentDescription(text, substring = substring))
                .fetchSemanticsNodes().isNotEmpty()
        }
    }

    private fun tap(text: String, substring: Boolean = false) {
        compose.onAllNodes(hasText(text, substring = substring) or hasContentDescription(text, substring = substring))
            .onFirst().performClick()
    }

    @Test
    fun firstLaunchShowsTheOneScreenOnboarding() {
        launch()
        waitForText("Find your races")
        compose.onNodeWithTag("athlete-search-field").assertExists()
        compose.onNodeWithText("Type your name").assertExists()
        compose.onNodeWithText("Privacy details").assertExists()
    }

    @Test
    fun liveSearchFindsAndClaimsAnAthlete() {
        launch()
        waitForText("Find your races")
        compose.onNodeWithTag("athlete-search-field").performTextInput("Pattie Wallner")
        compose.waitUntil(60_000) { compose.onAllNodesWithTag("athlete-choice").fetchSemanticsNodes().isNotEmpty() }
        compose.onAllNodesWithTag("athlete-choice").onFirst().performClick()
        compose.waitUntil(60_000) { compose.onAllNodesWithTag("locker-athlete-name").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("locker-athlete-name").assertExists()
        waitForText("IRONMAN", 30_000, substring = true)
    }

    @Test
    fun raceDetailShowsSplitsFieldAndSavesNotes() {
        launch(seed = true)
        waitForText("Alex Runner")
        tap("Riverbend Triathlon, Sep 7, 2025", substring = true)
        waitForText("SPLITS")
        waitForText("37 finishers")
        compose.onNodeWithTag("race-detail").performScrollToNode(hasText("Add notes for this race"))
        tap("Add notes for this race")
        waitForText("Heat, wind, water and course conditions")
        compose.onNodeWithTag("note-conditions").performTextInput("Hot and windy")
        tap("Save")
        waitForText("Hot and windy")
    }

    @Test
    fun rankingsStayScopedToOneDistance() {
        launch(seed = true)
        waitForText("Alex Runner")
        tap("Rankings")
        waitForText("FINISH RANKINGS")
        waitForText("Personal best")
        tap("Half distance")
        waitForText("Lakeside Half Triathlon", substring = true)
    }

    @Test
    fun askPattieWalksToHerAnswersOffline() {
        launch(seed = true)
        waitForText("Alex Runner")
        tap("Tips")
        waitForText("WHAT ARE YOU TRAINING FOR?")
        tap("A 70.3")
        waitForText("WHAT DO YOU NEED HELP WITH?")
        tap("Transitions")
        waitForText("HERE'S THE SITUATION")
        waitForText("Hear it from Pattie")
    }

    @Test
    fun exploreOpensAnotherCareerWithoutTouchingTheLocker() {
        launch(seed = true)
        waitForText("Alex Runner")
        tap("Explore")
        waitForText("RECENTLY EXPLORED")
        tap("Riley Example")
        waitForText("RACE HISTORY")
        tap("Locker")
        waitForText("Alex Runner")
    }

    @Test
    fun raceBookPaidActionsAreLockedUntilPurchase() {
        launch(seed = true)
        waitForText("Alex Runner")
        tap("Race Book")
        waitForText("Make your history tell a story")
        compose.onNodeWithTag("race-book").performScrollToNode(hasText("Unlock to export"))
        compose.onNodeWithText("Unlock race comparison").assertExists()
    }

    @Test
    fun forcedUnlockBuildsBothExportsAndCompares() {
        launch(seed = true, forcePro = true)
        waitForText("Alex Runner")
        tap("Race Book")
        waitForText("Race Book unlocked")
        compose.onNodeWithTag("race-book").performScrollToNode(hasText("Build PDF and image"))
        tap("Build PDF and image")
        waitForText("Share image", 30_000)
        compose.onNodeWithText("Share PDF").assertExists()
        compose.onNodeWithTag("race-book").performScrollToNode(hasText("Compare two races"))
        tap("Compare two races")
        waitForText("TIME BY LEG")
    }

    @Test
    fun revenueCatTestStorePurchaseUnlocksRaceBook() {
        launch(seed = true)
        waitForText("Alex Runner")
        tap("Race Book")
        waitForText("Make your history tell a story")
        compose.onNodeWithTag("race-book").performScrollToNode(hasText("Unlock to export"))
        tap("Unlock to export")
        compose.waitUntil(30_000) { compose.onAllNodesWithTag("buy-race-book").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("buy-race-book").performClick()
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        assertTrue(device.wait(Until.hasObject(By.text("TEST VALID PURCHASE")), 20_000))
        device.findObject(By.text("TEST VALID PURCHASE")).click()
        waitForText("Race Book unlocked", 30_000)
    }
}
