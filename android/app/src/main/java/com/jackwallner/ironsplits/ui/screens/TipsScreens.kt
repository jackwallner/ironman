package com.jackwallner.ironsplits.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.DownloadForOffline
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.OndemandVideo
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.QuestionAnswer
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.ironsplits.AppGraph
import com.jackwallner.ironsplits.R
import com.jackwallner.ironsplits.data.AskPattieGuide
import com.jackwallner.ironsplits.data.PattieMode
import com.jackwallner.ironsplits.data.PattiePetState
import com.jackwallner.ironsplits.data.Pointer
import com.jackwallner.ironsplits.data.PointerCatalog
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.components.LoadingState
import com.jackwallner.ironsplits.ui.components.RemoteImage
import com.jackwallner.ironsplits.ui.components.symbolIcon
import com.jackwallner.ironsplits.ui.nav.LocalNavigator
import com.jackwallner.ironsplits.ui.nav.Route
import com.jackwallner.ironsplits.ui.openExternal
import com.jackwallner.ironsplits.ui.theme.CardShape
import com.jackwallner.ironsplits.ui.theme.ChipRow
import com.jackwallner.ironsplits.ui.theme.Haptics
import com.jackwallner.ironsplits.ui.theme.InnerShape
import com.jackwallner.ironsplits.ui.theme.SegmentedControl
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriChip
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriPlaceholder
import com.jackwallner.ironsplits.ui.theme.TriScreen
import com.jackwallner.ironsplits.ui.theme.TriSectionHeader
import com.jackwallner.ironsplits.ui.theme.TriSheet
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriType
import com.jackwallner.ironsplits.ui.theme.bottomContentPadding
import com.jackwallner.ironsplits.ui.theme.triCard
import com.jackwallner.ironsplits.ui.theme.triOutlined
import com.jackwallner.ironsplits.ui.theme.triPress
import kotlinx.coroutines.launch

/** The loaded Ask Pattie tree, shared by the three screens that walk it. */
@Stable
class AskPattieModel(private val graph: AppGraph) {
    var guide by mutableStateOf(AskPattieGuide.empty)
        private set
    var isLoading by mutableStateOf(true)
        private set
    var catalog by mutableStateOf(PointerCatalog.empty)
        private set

    suspend fun load() {
        guide = graph.askLibrary.guide()
        catalog = graph.pointerLibrary.catalog()
        isLoading = false
        guide = graph.askLibrary.refresh()
    }

    suspend fun refresh() {
        guide = graph.askLibrary.refresh(force = true)
        catalog = graph.pointerLibrary.refresh(force = true)
    }
}

val LocalAskPattie = staticCompositionLocalOf<AskPattieModel> { error("No Ask Pattie model") }

@Composable
fun rememberAskPattieModel(graph: AppGraph): AskPattieModel = remember { AskPattieModel(graph) }

@Composable
fun ProvideAskPattie(model: AskPattieModel, content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalAskPattie provides model, content = content)
}

private enum class TipsMode(val rawValue: String, val title: String) {
    ASK("ask", "Ask Pattie"), LIBRARY("library", "All episodes")
}

/** The Tips tab: Ask Pattie and the full episode library behind one switch. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TipsScreen() {
    val graph = LocalGraph.current
    val navigator = LocalNavigator.current
    val ask = LocalAskPattie.current
    val scope = rememberCoroutineScope()
    val settings by graph.settings.state.collectAsState()
    val pattieEnabled by graph.pattie.enabled.collectAsState()
    val mode = TipsMode.entries.firstOrNull { it.rawValue == settings.tipsMode } ?: TipsMode.ASK
    var refreshing by remember { mutableStateOf(false) }
    var playing by remember { mutableStateOf<Pointer?>(null) }

    LaunchedEffect(Unit) {
        graph.pattie.fire(PattieMode.Moment.ASK_OPENED)
        ask.load()
    }

    TriScreen(
        title = "Tips",
        titleContent = {
            SegmentedControl(
                options = TipsMode.entries,
                selected = mode,
                label = { it.title },
                onDark = true,
                modifier = Modifier.width(240.dp),
            ) {
                graph.settings.tipsMode = it.rawValue
                graph.pattie.react(PattieMode.Action.SELECTION)
                navigator.popToRoot()
            }
        },
    ) {
        PullToRefreshBox(
            isRefreshing = refreshing,
            onRefresh = {
                refreshing = true
                graph.pattie.react(PattieMode.Action.REFRESH)
                scope.launch {
                    ask.refresh()
                    refreshing = false
                }
            },
            modifier = Modifier.fillMaxSize(),
        ) {
            when (mode) {
                TipsMode.ASK -> AskPattieGoalList(showInvite = !pattieEnabled) { graph.pattie.isEnabled = true }
                TipsMode.LIBRARY -> PointerLibraryList { playing = it }
            }
        }
    }

    PointerPlayerSheet(playing) { playing = null }
}

@Composable
private fun AskPattieGoalList(showInvite: Boolean, onEnablePattie: () -> Unit) {
    val graph = LocalGraph.current
    val navigator = LocalNavigator.current
    val ask = LocalAskPattie.current
    val colors = Tri.colors
    val guide = ask.guide
    when {
        guide.goals.isEmpty() && ask.isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { LoadingState(null) }
        guide.goals.isEmpty() -> Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), contentAlignment = Alignment.Center) {
            TriPlaceholder(Icons.Filled.QuestionAnswer, "Ask Pattie isn't loaded", message = "Pull down to fetch her pointers again.")
        }
        else -> Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(TriGeo.padPage).padding(bottomContentPadding(0.dp)),
            verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
        ) {
            if (showInvite) PattieModeInviteCard(onEnablePattie)
            PattieFeaturedHero()
            Text(guide.subtitle, style = TriType.small, color = colors.inkSecondary)
            TriSectionHeader(guide.goalQuestion)
            guide.goals.forEach { goal ->
                AskPattieOptionRow(symbolIcon(goal.symbol), goal.title, goal.subtitle) {
                    graph.pattie.react(PattieMode.Action.CHOICE)
                    navigator.push(Route.AskTopics(goal.id))
                }
            }
        }
    }
}

@Composable
fun AskTopicsScreen(goalId: String) {
    val graph = LocalGraph.current
    val navigator = LocalNavigator.current
    val guide = LocalAskPattie.current.guide
    val goal = guide.goal(goalId)
    DisposableEffect(Unit) { onDispose { if (navigator.lastWasPop) graph.pattie.react(PattieMode.Action.BACK) } }
    TriScreen(title = goal?.title ?: "Ask Pattie", onBack = { navigator.pop() }) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(TriGeo.padPage).padding(bottomContentPadding(0.dp)),
            verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
        ) {
            TriSectionHeader("What do you need help with?", trailing = goal?.title)
            goal?.let { guide.topics(it) }.orEmpty().forEach { topic ->
                val count = guide.answers(goalId, topic.id).size
                AskPattieOptionRow(symbolIcon(topic.symbol), topic.title, "$count pointer${if (count == 1) "" else "s"}") {
                    graph.pattie.react(PattieMode.Action.CHOICE)
                    navigator.push(Route.AskAnswers(goalId, topic.id))
                }
            }
        }
    }
}

@Composable
fun AskAnswersScreen(goalId: String, topicId: String) {
    val graph = LocalGraph.current
    val navigator = LocalNavigator.current
    val ask = LocalAskPattie.current
    var playing by remember { mutableStateOf<Pointer?>(null) }
    LaunchedEffect(Unit) { graph.pattie.fire(PattieMode.Moment.ASK_ANSWERED, PattiePetState.forTopicId(topicId)) }
    DisposableEffect(Unit) {
        onDispose {
            graph.voice.stop()
            if (navigator.lastWasPop) graph.pattie.react(PattieMode.Action.BACK)
        }
    }
    TriScreen(title = ask.guide.topic(topicId)?.title ?: "Pointers", onBack = { navigator.pop() }) {
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                start = TriGeo.padPage, end = TriGeo.padPage, top = TriGeo.padPage,
                bottom = TriGeo.padPage + bottomContentPadding(0.dp).calculateBottomPadding(),
            ),
            verticalArrangement = Arrangement.spacedBy(TriSpace.x4),
        ) {
            items(ask.guide.answers(goalId, topicId), key = { it.id }) { answer ->
                AskPattieAnswerCard(answer, ask.catalog.pointers.firstOrNull { it.id == answer.pointerId }) {
                    Haptics.tap()
                    graph.pattie.beginPointerPlayback()
                    playing = it
                }
            }
        }
    }
    PointerPlayerSheet(playing) { playing = null }
}

@Composable
private fun AskPattieOptionRow(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, subtitle: String, onClick: () -> Unit) {
    val colors = Tri.colors
    Row(
        Modifier.triPress(onClick = onClick).fillMaxWidth().heightIn(min = TriGeo.tapTarget + TriSpace.x4).triCard(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        Box(
            Modifier.size(TriGeo.tapTarget).background(colors.inkSecondary.copy(alpha = 0.14f), InnerShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, null, tint = colors.inkSecondary, modifier = Modifier.size(22.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text(title, style = TriType.cardTitle, color = colors.ink)
            Text(subtitle, style = TriType.small, color = colors.inkTertiary)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkTertiary)
    }
}

/** One answer: her setup, her fix, her voice, and the episode it came from. */
@Composable
private fun AskPattieAnswerCard(answer: AskPattieGuide.Answer, episode: Pointer?, onPlayEpisode: (Pointer) -> Unit) {
    val graph = LocalGraph.current
    val colors = Tri.colors
    val nowPlaying by graph.voice.nowPlaying.collectAsState()
    val speaking = nowPlaying != null && (nowPlaying == answer.solutionVoice || nowPlaying == answer.situationVoice)
    Column(Modifier.fillMaxWidth().triCard(), verticalArrangement = Arrangement.spacedBy(TriSpace.x3)) {
        Text(answer.headline, style = TriType.cardTitle, color = colors.ink)
        AnswerBlock("Here's the situation", answer.situation, nowPlaying != null && nowPlaying == answer.situationVoice)
        AnswerBlock("Here's the solution", answer.solution, nowPlaying != null && nowPlaying == answer.solutionVoice)
        Row(horizontalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
            Row(
                Modifier
                    .triPress(haptic = false) {
                        Haptics.tap()
                        graph.voice.toggle(answer.solutionVoice ?: answer.situationVoice)
                    }
                    .heightIn(min = TriGeo.tapTarget)
                    .clip(CircleShape)
                    .background(colors.sunrise)
                    .padding(horizontal = TriSpace.x4),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(TriSpace.x2),
            ) {
                Icon(if (speaking) Icons.Filled.Stop else Icons.Filled.PlayArrow, null, tint = colors.inkOnSunrise, modifier = Modifier.size(18.dp))
                Text(if (speaking) "Stop" else "Hear it from Pattie", style = TriType.smallBold, color = colors.inkOnSunrise)
            }
            if (episode != null) {
                Row(
                    Modifier
                        .triPress(haptic = false) { onPlayEpisode(episode) }
                        .heightIn(min = TriGeo.tapTarget)
                        .border(TriGeo.hairline, colors.hairline, CircleShape)
                        .padding(horizontal = TriSpace.x4),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(TriSpace.x2),
                ) {
                    Icon(Icons.Filled.OndemandVideo, null, tint = colors.ink, modifier = Modifier.size(18.dp))
                    Text("Full clip", style = TriType.smallBold, color = if (colors.isDark) colors.ink else colors.deep)
                }
            }
        }
    }
}

@Composable
private fun AnswerBlock(label: String, text: String, playing: Boolean) {
    val colors = Tri.colors
    Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text(label.uppercase(), style = TriType.micro.copy(letterSpacing = 0.6.sp), color = colors.sunrise)
            if (playing) Icon(Icons.Filled.GraphicEq, "Playing", tint = colors.sunrise, modifier = Modifier.size(12.dp))
        }
        Text(text, style = TriType.body, color = colors.inkSecondary)
    }
}

/** An app-owned profile moment for Pattie's coaching library. */
@Composable
fun PattieFeaturedHero() {
    val colors = Tri.colors
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
        Box(
            Modifier.fillMaxWidth().height(TriSpace.x10 * 4 + TriSpace.x4).clip(CardShape).background(colors.deep)
                .clearAndSetSemantics { contentDescription = "Pattie Wallner, sharing race stories and small fixes" },
        ) {
            Image(
                painterResource(R.drawable.pattie_finish),
                null,
                contentScale = ContentScale.Crop,
                alignment = Alignment.TopCenter,
                modifier = Modifier.fillMaxSize(),
            )
            Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(colors.deep.copy(alpha = 0f), colors.deep.copy(alpha = 0.92f)))))
            Column(Modifier.align(Alignment.BottomStart).padding(TriGeo.padCard), verticalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
                Text("PATTIE WALLNER", style = TriType.micro.copy(letterSpacing = 1.1.sp), color = colors.sunrise)
                Text("Small things save a whole day.", style = TriType.cardTitle, color = colors.inkOnDark)
            }
        }
        Text("Pattie's pointers", style = TriType.cardTitle, color = colors.ink)
        Text(
            "Pattie has finished 16 full-distance triathlons. Her race-day pointers come from years of experience.",
            style = TriType.small,
            color = colors.inkSecondary,
        )
    }
}

@Composable
private fun PattieModeInviteCard(onEnable: () -> Unit) {
    val colors = Tri.colors
    Row(
        Modifier.semantics { contentDescription = "Want Pattie along for the ride? Pattie Mode is optional and can be turned off in Settings" }
            .triPress(onClick = onEnable).fillMaxWidth().heightIn(min = TriGeo.tapTarget).triOutlined(TriSpace.x3),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        Icon(Icons.Filled.Forum, null, tint = colors.sunrise, modifier = Modifier.width(TriSpace.x8).size(22.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text("Want Pattie along for the ride?", style = TriType.bodyBold, color = colors.ink)
            Text("Turn on her optional tips and race-day reactions.", style = TriType.small, color = colors.inkSecondary)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkTertiary)
    }
}

/** Every episode with a thumbnail and an offline badge. */
@Composable
private fun PointerLibraryList(onPlay: (Pointer) -> Unit) {
    val graph = LocalGraph.current
    val context = LocalContext.current
    val colors = Tri.colors
    val scope = rememberCoroutineScope()
    var catalog by remember { mutableStateOf(graph.pointerLibrary.catalog()) }
    var isLoading by remember { mutableStateOf(catalog.pointers.isEmpty()) }
    var loadError by remember { mutableStateOf<String?>(null) }
    var filter by remember { mutableStateOf<Discipline?>(null) }
    val cacheVersion by graph.mediaCache.version.collectAsState()

    suspend fun load(force: Boolean) {
        loadError = null
        isLoading = catalog.pointers.isEmpty()
        catalog = graph.pointerLibrary.refresh(force)
        if (catalog.pointers.isEmpty()) loadError = graph.pointerLibrary.errorMessage
        isLoading = false
    }

    LaunchedEffect(Unit) {
        graph.pattie.fire(PattieMode.Moment.POINTERS)
        load(false)
    }
    // A pull to refresh on the tab reloads the shared catalog; pick it up here.
    val shared = LocalAskPattie.current.catalog
    LaunchedEffect(shared) { if (shared.pointers.isNotEmpty()) catalog = shared }

    fun open(pointer: Pointer) {
        val link = pointer.playableUrl
        if (pointer.opensExternally && link != null) {
            graph.pattie.dismiss()
            context.openExternal(link)
        } else {
            graph.pattie.beginPointerPlayback()
            onPlay(pointer)
        }
    }

    when {
        isLoading && catalog.pointers.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { LoadingState(null) }
        loadError != null && catalog.pointers.isEmpty() -> Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), contentAlignment = Alignment.Center) {
            TriPlaceholder(Icons.Filled.WifiOff, "Couldn't load episodes", message = loadError, actionTitle = "Try again") {
                scope.launch { load(true) }
            }
        }
        catalog.pointers.isEmpty() -> Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), contentAlignment = Alignment.Center) {
            TriPlaceholder(Icons.Filled.OndemandVideo, catalog.title, message = catalog.emptyMessage ?: PointerCatalog.empty.emptyMessage)
        }
        else -> {
            val disciplines = catalog.pointers.mapNotNull { it.discipline }.distinct()
            val visible = filter?.let { f -> catalog.pointers.filter { it.discipline == f } } ?: catalog.pointers
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    start = TriGeo.padPage, end = TriGeo.padPage, top = TriGeo.padPage,
                    bottom = TriGeo.padPage + bottomContentPadding(0.dp).calculateBottomPadding(),
                ),
                verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
            ) {
                item("hero") { PattieFeaturedHero() }
                catalog.subtitle?.let { subtitle ->
                    item("subtitle") { Text(subtitle, style = TriType.small, color = colors.inkSecondary) }
                }
                if (disciplines.size > 1) {
                    item("filters") {
                        ChipRow {
                            TriChip("All", filter == null) {
                                filter = null
                                graph.pattie.react(PattieMode.Action.FILTER)
                            }
                            disciplines.forEach { leg ->
                                TriChip(leg.title, filter == leg) {
                                    filter = leg
                                    graph.pattie.react(PattieMode.Action.FILTER)
                                }
                            }
                        }
                    }
                }
                items(visible, key = { it.id }) { pointer ->
                    PointerRow(pointer, downloaded = remember(cacheVersion) { graph.mediaCache.cachedFile(pointer) != null }) { open(pointer) }
                }
            }
        }
    }
}

@Composable
private fun PointerRow(pointer: Pointer, downloaded: Boolean, onClick: () -> Unit) {
    val context = LocalContext.current
    val colors = Tri.colors
    Row(
        Modifier.semantics { contentDescription = "${pointer.title}. Opens episode" }
            .triPress(onClick = onClick).fillMaxWidth().heightIn(min = TriGeo.tapTarget + TriSpace.x4).triCard(TriSpace.x3),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        Box(
            Modifier.size(width = 76.dp, height = 52.dp).clip(InnerShape).background(colors.deep.copy(alpha = 0.10f)),
            contentAlignment = Alignment.Center,
        ) {
            pointer.thumbnailUrl?.let { RemoteImage(it, Modifier.fillMaxSize()) }
            Icon(Icons.Filled.PlayArrow, null, tint = Color.White, modifier = Modifier.size(20.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
                pointer.episode?.let { Text("EP $it", style = TriType.micro, color = colors.inkTertiary) }
                if (downloaded) Icon(Icons.Filled.DownloadForOffline, "Saved for offline", tint = colors.positive, modifier = Modifier.size(12.dp))
            }
            Text(pointer.title, style = TriType.bodyBold, color = colors.ink)
            pointer.summary?.let { Text(it, style = TriType.small, color = colors.inkTertiary) }
        }
        val metadata = listOfNotNull(pointer.durationText, pointer.fileSizeText(context))
        if (metadata.isNotEmpty()) {
            Text(metadata.joinToString(" · "), style = TriType.statSmall, color = colors.inkTertiary, maxLines = 1, modifier = Modifier.widthIn(max = 110.dp))
        }
    }
}
