package com.jackwallner.ironsplits.ui.screens

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.PauseCircle
import androidx.compose.material.icons.filled.Pool
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.ironsplits.data.AthleteSearchResponse
import com.jackwallner.ironsplits.data.IronSplitsLegal
import com.jackwallner.ironsplits.data.PattieMode
import com.jackwallner.ironsplits.data.ResultsApi
import com.jackwallner.ironsplits.data.SearchDepth
import com.jackwallner.ironsplits.data.isCancellation
import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.components.LoadingState
import com.jackwallner.ironsplits.ui.components.SmallSpinner
import com.jackwallner.ironsplits.ui.openUrl
import com.jackwallner.ironsplits.ui.theme.CardShape
import com.jackwallner.ironsplits.ui.theme.Haptics
import com.jackwallner.ironsplits.ui.theme.ToolbarTextButton
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriAlert
import com.jackwallner.ironsplits.ui.theme.TriDivider
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriPlaceholder
import com.jackwallner.ironsplits.ui.theme.TriScreen
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriTextButton
import com.jackwallner.ironsplits.ui.theme.TriType
import com.jackwallner.ironsplits.ui.theme.bottomContentPadding
import com.jackwallner.ironsplits.ui.theme.triPress
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

enum class SearchPurpose { ONBOARDING, CHANGE, ADD_REGISTRATION, EXPLORE }

private enum class Phase { IDLE, QUICK, DEEP, DONE, STOPPED }

/**
 * Find yourself in the results feed and claim the record. The quick
 * `startswith` pass runs after a short typing pause; the slow `contains`
 * scan only runs when that finds nobody, and the screen says so.
 */
@Composable
fun AthleteSearchScreen(purpose: SearchPurpose, onClose: () -> Unit = {}, onSelect: ((Athlete) -> Unit)? = null) {
    val graph = LocalGraph.current
    val colors = Tri.colors
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val locker = graph.locker

    var field by remember { mutableStateOf(TextFieldValue("")) }
    val query = field.text
    var matches by remember { mutableStateOf<List<Athlete>>(emptyList()) }
    var phase by remember { mutableStateOf(Phase.IDLE) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var claiming by remember { mutableStateOf<Athlete?>(null) }
    var pendingClaim by remember { mutableStateOf<Athlete?>(null) }
    var hasUnsupported by remember { mutableStateOf(false) }
    var truncated by remember { mutableStateOf(false) }
    var searchJob by remember { mutableStateOf<Job?>(null) }
    var generation by remember { mutableIntStateOf(0) }
    var lastSearchTerm by remember { mutableStateOf<String?>(null) }
    var focused by remember { mutableStateOf(false) }
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        graph.pattie.fire(PattieMode.Moment.SEARCHING)
        graph.feedConfig.refreshIfStale()
    }
    DisposableEffect(Unit) { onDispose { searchJob?.cancel() } }

    fun resetResults() {
        matches = emptyList()
        errorMessage = null
        hasUnsupported = false
        truncated = false
    }

    fun isCurrent(term: String, gen: Int) = gen == generation && field.text.trim() == term

    fun runSearch(term: String) {
        searchJob?.cancel()
        generation++
        val gen = generation
        lastSearchTerm = term
        resetResults()
        graph.pattie.react(PattieMode.Action.SEARCH)
        phase = Phase.QUICK
        searchJob = scope.launch {
            try {
                var response: AthleteSearchResponse = graph.api.searchAthletes(term, SearchDepth.PREFIX)
                if (response.athletes.isEmpty() && !response.hasOnlyUnsupportedResults) {
                    if (!isCurrent(term, gen)) return@launch
                    phase = Phase.DEEP
                    val deep = graph.api.searchAthletes(term, SearchDepth.SUBSTRING)
                    response = AthleteSearchResponse(
                        deep.athletes,
                        deep.hasUnsupportedResults || response.hasUnsupportedResults,
                        deep.wasTruncated || response.wasTruncated,
                    )
                }
                if (!isCurrent(term, gen)) return@launch
                matches = response.athletes
                hasUnsupported = response.hasOnlyUnsupportedResults
                truncated = response.wasTruncated
                phase = Phase.DONE
                if (response.athletes.isNotEmpty()) Haptics.success()
            } catch (error: Throwable) {
                if (isCancellation(error) || !isCurrent(term, gen)) return@launch
                errorMessage = ResultsApi.userFacingMessage(error)
                phase = Phase.DONE
            }
        }
    }

    fun runSearchNow() {
        val term = field.text.trim()
        if (term.length < 2) {
            searchJob?.cancel()
            resetResults()
            phase = Phase.IDLE
            lastSearchTerm = null
            return
        }
        runSearch(term)
    }

    fun stopSearch() {
        searchJob?.cancel()
        generation++
        resetResults()
        lastSearchTerm = null
        phase = Phase.STOPPED
    }

    // Debounced: every search is a real request to somebody else's service.
    LaunchedEffect(query) {
        val term = query.trim()
        if (term.length < 2) {
            matches = emptyList()
            phase = Phase.IDLE
            errorMessage = null
            lastSearchTerm = null
            return@LaunchedEffect
        }
        delay(400)
        if (lastSearchTerm != term) runSearch(term)
    }

    fun performClaim(athlete: Athlete) {
        if (claiming != null) return
        pendingClaim = null
        Haptics.medium()
        claiming = athlete
        if (onSelect != null) {
            onSelect(athlete)
            claiming = null
            Haptics.success()
            onClose()
            return
        }
        scope.launch {
            (if (purpose == SearchPurpose.ADD_REGISTRATION) locker.addContact(athlete) else locker.claim(athlete)).join()
            claiming = null
            Haptics.success()
            if (purpose != SearchPurpose.ONBOARDING) onClose()
        }
    }

    fun claim(athlete: Athlete) {
        if (claiming != null) return
        if (onSelect == null && purpose == SearchPurpose.CHANGE && locker.current.athlete != null) {
            pendingClaim = athlete
            return
        }
        performClaim(athlete)
    }

    val title = when (purpose) {
        SearchPurpose.ONBOARDING -> "Find your races"
        SearchPurpose.ADD_REGISTRATION -> "Find another registration"
        SearchPurpose.EXPLORE -> "Find a racer"
        SearchPurpose.CHANGE -> "Change athlete"
    }
    val introText = when (purpose) {
        SearchPurpose.ADD_REGISTRATION -> "Search the official results feed for another name you raced under. Choose the right person and those published races will be added to this profile."
        SearchPurpose.EXPLORE -> "Search the official results feed, then open a racer’s career without changing the athlete in your Locker."
        else -> "Find published full and half-distance triathlon results under the name you registered with. Try your full legal first name, surname first, or add a city after a comma to narrow common names."
    }

    TriScreen(
        title = title,
        inSheet = purpose != SearchPurpose.ONBOARDING,
        leading = if (purpose != SearchPurpose.ONBOARDING) {
            { ToolbarTextButton("Cancel", onClick = onClose) }
        } else null,
    ) {
        Column(Modifier.fillMaxSize()) {
            SearchField(
                value = field,
                focused = focused,
                focusRequester = focusRequester,
                onFocus = { focused = it },
                onValueChange = { next ->
                    if (next.text != field.text) {
                        searchJob?.cancel()
                        generation++
                        resetResults()
                        lastSearchTerm = null
                        phase = Phase.IDLE
                    }
                    field = next
                },
                onSubmit = { runSearchNow() },
                onClear = {
                    Haptics.tap()
                    graph.pattie.react(PattieMode.Action.SELECTION)
                    searchJob?.cancel()
                    generation++
                    field = TextFieldValue("")
                    resetResults()
                    phase = Phase.IDLE
                    lastSearchTerm = null
                },
            )
            val searching = phase == Phase.QUICK || phase == Phase.DEEP
            when {
                searching -> CenteredBox {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(TriSpace.x3)) {
                        LoadingState(null)
                        Text(
                            if (phase == Phase.DEEP) "No quick match yet. This broader search can take around 30 seconds. Your name stays here."
                            else "Searching published results…",
                            style = TriType.small,
                            color = colors.inkTertiary,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.padding(horizontal = TriSpace.x8),
                        )
                        TriTextButton("Stop search", style = TriType.smallBold, haptic = false) { stopSearch() }
                    }
                }
                phase == Phase.STOPPED -> CenteredBox {
                    TriPlaceholder(
                        Icons.Filled.PauseCircle, "Search stopped",
                        message = "Your name is still here. Search again when you're ready.",
                        actionTitle = "Search again",
                    ) { runSearchNow() }
                }
                errorMessage != null -> CenteredBox {
                    TriPlaceholder(Icons.Filled.WifiOff, "Couldn't search", message = errorMessage, actionTitle = "Try again") { runSearchNow() }
                }
                matches.isEmpty() && phase == Phase.DONE -> CenteredBox {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        val message = when {
                            hasUnsupported -> "We found published results for this name, but none were full or half-distance triathlons. Try another registration if you raced under a different name."
                            truncated -> "There are many matches for this name. Add a city or state after a comma, such as John Smith, Madison, to narrow the search."
                            else -> "Search published full and half-distance triathlon results. Try your full registered first name, surname first, or add a city after a comma."
                        }
                        TriPlaceholder(
                            Icons.Filled.Search,
                            if (hasUnsupported) "No supported races found" else "No athletes found",
                            message = message,
                            actionTitle = "Try another name",
                        ) {
                            phase = Phase.IDLE
                            focusRequester.requestFocus()
                        }
                        if (hasUnsupported) {
                            TriTextButton("About supported results", style = TriType.smallBold) { context.openUrl(IronSplitsLegal.SUPPORT_URL) }
                        }
                    }
                }
                matches.isEmpty() -> Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(vertical = TriSpace.x8).padding(bottomContentPadding()),
                ) {
                    IntroBlurb(introText) { context.openUrl(IronSplitsLegal.PRIVACY_URL) }
                }
                else -> Column(Modifier.fillMaxSize()) {
                    if (truncated) {
                        Text(
                            "Many racers share this name. Add a city or state after a comma, for example John Smith, Madison.",
                            style = TriType.small,
                            color = colors.inkSecondary,
                            modifier = Modifier.fillMaxWidth().background(colors.surfaceAlt)
                                .padding(horizontal = TriGeo.padPage, vertical = TriSpace.x3),
                        )
                    }
                    LazyColumn(contentPadding = bottomContentPadding(), modifier = Modifier.fillMaxSize()) {
                        items(matches, key = { it.id }) { athlete ->
                            Column(Modifier.background(colors.surface)) {
                                AthleteRow(athlete, isClaiming = claiming?.id == athlete.id, enabled = claiming == null) { claim(athlete) }
                                TriDivider(Modifier.padding(start = TriGeo.padPage))
                            }
                        }
                    }
                }
            }
        }
    }

    pendingClaim?.let { athlete ->
        TriAlert(
            title = "Replace the athlete in your Locker?",
            message = "Replace ${locker.current.athlete?.name ?: "your current athlete"} with ${athlete.name}? Your saved race notes stay on this phone.",
            confirmTitle = "Replace",
            destructive = true,
            onConfirm = { performClaim(athlete) },
            onDismiss = { pendingClaim = null },
        )
    }
}

@Composable
private fun CenteredBox(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize().padding(bottomContentPadding()), contentAlignment = Alignment.Center) { content() }
}

@Composable
private fun SearchField(
    value: TextFieldValue,
    focused: Boolean,
    focusRequester: FocusRequester,
    onFocus: (Boolean) -> Unit,
    onValueChange: (TextFieldValue) -> Unit,
    onSubmit: () -> Unit,
    onClear: () -> Unit,
) {
    val colors = Tri.colors
    val border by animateColorAsState(if (focused) colors.sunrise else colors.hairline, label = "border")
    Row(
        Modifier
            .padding(TriGeo.padPage)
            .fillMaxWidth()
            .height(TriGeo.tapTarget + TriSpace.x2)
            .background(colors.surface, CardShape)
            .border(if (focused) 1.5.dp else TriGeo.hairline, border, CardShape)
            .padding(start = TriSpace.x3),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Search, null, tint = if (focused) colors.sunrise else colors.inkTertiary, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(TriSpace.x2))
        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            if (value.text.isEmpty()) {
                Text("Your name as you registered", style = TriType.field, color = colors.inkTertiary.copy(alpha = 0.7f), maxLines = 1)
            }
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                singleLine = true,
                textStyle = TriType.field.copy(color = colors.ink),
                cursorBrush = SolidColor(colors.sunrise),
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Words,
                    autoCorrectEnabled = false,
                    imeAction = ImeAction.Search,
                ),
                keyboardActions = KeyboardActions(onSearch = { onSubmit() }),
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester)
                    .onFocusChanged { onFocus(it.isFocused) }
                    .testTag("athlete-search-field")
                    .semantics { contentDescription = "Your name as you registered" },
            )
        }
        if (value.text.isNotEmpty()) {
            Box(
                Modifier.size(TriGeo.tapTarget).triPress(haptic = false, label = "Clear", onClick = onClear),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Cancel, "Clear search", tint = colors.inkTertiary, modifier = Modifier.size(20.dp))
            }
        } else {
            Spacer(Modifier.width(TriSpace.x3))
        }
    }
}

@Composable
private fun IntroBlurb(introText: String, onPrivacy: () -> Unit) {
    val colors = Tri.colors
    Column(
        Modifier.fillMaxWidth().padding(horizontal = TriSpace.x8),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(TriSpace.x4),
    ) {
        Icon(Icons.Filled.Pool, null, tint = colors.inkSecondary, modifier = Modifier.size(48.dp))
        Text("Type your name", style = TriType.cardTitle, color = colors.inkSecondary, textAlign = TextAlign.Center)
        Text(introText, style = TriType.small, color = colors.inkTertiary, textAlign = TextAlign.Center)
        Text(
            "Name searches go to the event results service. No account is created, and race notes stay on this phone.",
            style = TriType.micro,
            color = colors.inkTertiary,
            textAlign = TextAlign.Center,
        )
        TriTextButton("Privacy details", style = TriType.smallBold, onClick = onPrivacy)
    }
}

@Composable
private fun AthleteRow(athlete: Athlete, isClaiming: Boolean, enabled: Boolean, onClick: () -> Unit) {
    val colors = Tri.colors
    Row(
        Modifier
            .testTag("athlete-choice")
            .triPress(enabled = enabled || isClaiming, onClick = onClick)
            .fillMaxWidth()
            .heightIn(min = TriGeo.tapTarget + TriSpace.x2)
            .padding(horizontal = TriGeo.padPage, vertical = TriSpace.x2),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text(athlete.name, style = TriType.cardTitle, color = colors.ink)
            if (athlete.subtitle.isNotEmpty()) Text(athlete.subtitle, style = TriType.small, color = colors.inkTertiary)
        }
        Spacer(Modifier.width(TriSpace.x2))
        if (isClaiming) {
            SmallSpinner()
        } else {
            // "At least": search reads capped pages, claiming pulls the whole history.
            Text("${athlete.knownRaceCount}+ races", style = TriType.statSmall, color = colors.inkTertiary, maxLines = 1)
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkTertiary, modifier = Modifier.size(20.dp))
        }
    }
}

