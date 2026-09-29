package com.jackwallner.ironsplits.ui

import android.app.Activity
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Inbox
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SmartDisplay
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.google.android.play.core.review.ReviewManagerFactory
import com.jackwallner.ironsplits.data.PattieMode
import com.jackwallner.ironsplits.data.ReviewPromptTracker
import com.jackwallner.ironsplits.ui.nav.NavStack
import com.jackwallner.ironsplits.ui.nav.Navigator
import com.jackwallner.ironsplits.ui.nav.Route
import com.jackwallner.ironsplits.ui.screens.AskAnswersScreen
import com.jackwallner.ironsplits.ui.screens.AskTopicsScreen
import com.jackwallner.ironsplits.ui.screens.AthleteSearchScreen
import com.jackwallner.ironsplits.ui.screens.ExploreAthleteScreen
import com.jackwallner.ironsplits.ui.screens.ExploreScreen
import com.jackwallner.ironsplits.ui.screens.LockerScreen
import com.jackwallner.ironsplits.ui.screens.PattieCompanion
import com.jackwallner.ironsplits.ui.screens.ProvideAskPattie
import com.jackwallner.ironsplits.ui.screens.RaceBookScreen
import com.jackwallner.ironsplits.ui.screens.RaceCompareScreen
import com.jackwallner.ironsplits.ui.screens.RaceDetailScreen
import com.jackwallner.ironsplits.ui.screens.ReviewOutcome
import com.jackwallner.ironsplits.ui.screens.ReviewPromptSheet
import com.jackwallner.ironsplits.ui.screens.SearchPurpose
import com.jackwallner.ironsplits.ui.screens.SettingsScreen
import com.jackwallner.ironsplits.ui.screens.TipsScreen
import com.jackwallner.ironsplits.ui.screens.rememberAskPattieModel
import com.jackwallner.ironsplits.ui.theme.Haptics
import com.jackwallner.ironsplits.ui.theme.LocalBottomInset
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriType
import kotlinx.coroutines.delay

enum class AppTab(val title: String, val icon: ImageVector) {
    LOCKER("Locker", Icons.Filled.Inbox),
    EXPLORE("Explore", Icons.Filled.People),
    TIPS("Tips", Icons.Filled.SmartDisplay),
    RACE_BOOK("Race Book", Icons.AutoMirrored.Filled.MenuBook),
    SETTINGS("Settings", Icons.Filled.Settings),
}

@Composable
fun RootScreen() {
    val graph = LocalGraph.current
    val locker by graph.locker.state.collectAsState()
    val pattieEnabled by graph.pattie.enabled.collectAsState()
    val context = LocalContext.current
    var reviewPresentation by remember { mutableStateOf<ReviewPromptTracker.Presentation?>(null) }
    var wasClaimed by remember { mutableStateOf(locker.hasClaimedAthlete) }

    LaunchedEffect(locker.hasClaimedAthlete) {
        if (locker.hasClaimedAthlete && !wasClaimed) {
            graph.settings.hasCompletedOnboarding = true
            graph.pattie.fire(PattieMode.Moment.CLAIMED)
        }
        wasClaimed = locker.hasClaimedAthlete
    }
    LaunchedEffect(Unit) {
        if (graph.locker.current.results.size >= 10) graph.pattie.fire(PattieMode.Moment.VETERAN)
    }
    LaunchedEffect(Unit) {
        graph.review.positiveMoments.collect {
            if (graph.review.shouldShowAfterPositiveMoment(graph.settings.hasCompletedOnboarding)) {
                delay(600)
                reviewPresentation = ReviewPromptTracker.Presentation.ENJOYMENT
            }
        }
    }
    LaunchedEffect(Unit) { graph.review.requests.collect { reviewPresentation = it } }

    Box(Modifier.fillMaxSize().background(Tri.colors.canvas)) {
        if (locker.hasClaimedAthlete) Tabs() else {
            CompositionLocalProvider(LocalBottomInset provides WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()) {
                AthleteSearchScreen(SearchPurpose.ONBOARDING)
            }
        }
        if (pattieEnabled) {
            val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() +
                (if (locker.hasClaimedAthlete) TriGeo.tabBarHeight + TriSpace.x3 else TriSpace.x3)
            PattieCompanion(Modifier.align(Alignment.BottomStart).padding(bottom = bottom))
        }
    }

    ReviewPromptSheet(reviewPresentation) { outcome ->
        reviewPresentation = null
        if (outcome == ReviewOutcome.ENJOYED) {
            graph.review.markSoftDeferred()
            val activity = context as? Activity ?: return@ReviewPromptSheet
            val manager = ReviewManagerFactory.create(activity)
            manager.requestReviewFlow().addOnCompleteListener { request ->
                if (request.isSuccessful) manager.launchReviewFlow(activity, request.result)
            }
        }
    }
}

@Composable
private fun Tabs() {
    val graph = LocalGraph.current
    var selected by rememberSaveable { mutableStateOf(AppTab.LOCKER) }
    val navigators = remember { AppTab.entries.associateWith { Navigator() } }
    val holder = rememberSaveableStateHolder()
    val askModel = rememberAskPattieModel(graph)
    val navInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    LaunchedEffect(Unit) { graph.locker.refresh() }

    Box(Modifier.fillMaxSize()) {
        CompositionLocalProvider(LocalBottomInset provides navInset + TriGeo.tabBarHeight + TriSpace.x3) {
            ProvideAskPattie(askModel) {
                holder.SaveableStateProvider(selected.name) {
                    val navigator = navigators.getValue(selected)
                    NavStack(navigator) { route -> TabRoute(selected, route) }
                }
            }
        }
        FloatingTabBar(
            selected = selected,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = navInset + TriSpace.x1),
        ) { tab ->
            if (tab == selected) {
                navigators.getValue(tab).popToRoot()
            } else {
                Haptics.selection()
                selected = tab
                graph.pattie.react(PattieMode.Action.TAB)
            }
        }
    }
}

@Composable
private fun TabRoute(tab: AppTab, route: Route) {
    when (route) {
        Route.Root -> when (tab) {
            AppTab.LOCKER -> LockerScreen()
            AppTab.EXPLORE -> ExploreScreen()
            AppTab.TIPS -> TipsScreen()
            AppTab.RACE_BOOK -> RaceBookScreen()
            AppTab.SETTINGS -> SettingsScreen()
        }
        is Route.RaceDetail -> RaceDetailScreen(route.result, route.context, route.readOnly)
        is Route.ExploreAthlete -> ExploreAthleteScreen(route.athlete)
        is Route.AskTopics -> AskTopicsScreen(route.goalId)
        is Route.AskAnswers -> AskAnswersScreen(route.goalId, route.topicId)
        is Route.RaceCompare -> RaceCompareScreen(route.kind)
    }
}

/** The iOS 26 style floating tab bar: a capsule over the content, one pill for the selection. */
@Composable
private fun FloatingTabBar(selected: AppTab, modifier: Modifier = Modifier, onSelect: (AppTab) -> Unit) {
    val colors = Tri.colors
    Row(
        modifier
            .padding(horizontal = TriSpace.x5)
            .fillMaxWidth()
            .height(TriGeo.tabBarHeight)
            .shadow(12.dp, CircleShape, ambientColor = colors.shadow, spotColor = colors.shadow)
            .clip(CircleShape)
            .background(colors.tabBar)
            .border(TriGeo.hairline, colors.hairline.copy(alpha = 0.6f), CircleShape)
            .padding(4.dp)
            .testTag("tab-bar"),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        AppTab.entries.forEach { tab ->
            val isSelected = tab == selected
            val background by animateColorAsState(if (isSelected) colors.tabSelection else colors.tabSelection.copy(alpha = 0f), label = "tab")
            val tint = if (isSelected) colors.sunrise else colors.ink
            Column(
                Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .clip(CircleShape)
                    .background(background)
                    .semantics {
                        role = Role.Tab
                        this.selected = isSelected
                        contentDescription = tab.title
                    }
                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onSelect(tab) },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Icon(tab.icon, null, tint = tint, modifier = Modifier.size(26.dp))
                Text(tab.title, style = TriType.tab, color = tint, maxLines = 1)
            }
        }
    }
}
