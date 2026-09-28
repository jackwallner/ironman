package com.jackwallner.ironsplits.ui

import android.content.Intent
import android.net.Uri
import android.widget.MediaController
import android.widget.VideoView
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.jackwallner.ironsplits.data.PattieAnswer
import com.jackwallner.ironsplits.data.PattieGoal
import com.jackwallner.ironsplits.data.PattieTopic
import com.jackwallner.ironsplits.data.PointerEpisode

@Composable
fun TipsScreen(state: AppUiState, viewModel: IronSplitsViewModel) {
    val context = LocalContext.current
    BackHandler(enabled = state.selectedEpisode != null || state.selectedAnswerId != null || state.selectedTopicId != null || state.selectedGoalId != null) {
        if (state.selectedEpisode != null) viewModel.closeEpisode() else viewModel.backAskPattie()
    }
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = Space.page, vertical = Space.section),
        verticalArrangement = Arrangement.spacedBy(Space.section),
    ) {
        ScreenTitle("Tips", "Race-day guidance from Pattie, on demand.")
        Row(horizontalArrangement = Arrangement.spacedBy(Space.small)) {
            TipsSection.entries.forEach { section ->
                FilterChip(
                    selected = state.tipsSection == section,
                    onClick = { viewModel.chooseTipsSection(section) },
                    label = { Text(section.title) },
                    modifier = Modifier.height(Space.tapTarget),
                )
            }
            Spacer(Modifier.weight(1f))
            IconButton(onClick = viewModel::refreshTips, modifier = Modifier.height(Space.tapTarget).width(Space.tapTarget)) {
                Icon(Icons.Default.Refresh, contentDescription = "Refresh tips")
            }
        }

        MessageBanner(state.statusMessage, viewModel::dismissMessage)
        state.selectedEpisode?.let { episode ->
            EpisodePlayerCard(state, episode, viewModel)
        }

        if (state.tipsSection == TipsSection.ASK) {
            AskPattieFlow(state, viewModel)
        } else {
            if (state.loadingTips && state.episodes.isEmpty()) CircularProgressIndicator()
            SectionHeading("Episode library", "Download an episode to watch. It stays available on this device.")
            state.episodes.forEach { episode ->
                EpisodeCard(episode) {
                    val external = episode.linkUrl
                    if (external != null) {
                        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(external))) }
                            .onFailure { viewModel.dismissMessage() }
                    } else {
                        viewModel.playEpisode(episode)
                    }
                }
            }
            if (state.episodes.isEmpty() && !state.loadingTips) {
                ContentCard { Text("Episodes are unavailable right now.", style = MaterialTheme.typography.bodyLarge) }
            }
        }
    }
}

@Composable
private fun AskPattieFlow(state: AppUiState, viewModel: IronSplitsViewModel) {
    val goal = viewModel.pattieGoal(state.selectedGoalId)
    val topic = viewModel.pattieTopic(state.selectedTopicId)
    val answer = viewModel.pattieAnswers.firstOrNull { it.id == state.selectedAnswerId }
    when {
        answer != null -> AnswerCard(state, answer, viewModel)
        goal == null -> {
            SectionHeading("What are you training for?", "Choose a goal to see Pattie's own pointers for it.")
            viewModel.pattieGoals.forEach { item -> GoalCard(item) { viewModel.chooseGoal(item.id) } }
        }
        topic == null -> {
            BackChoiceHeader(goal.title, viewModel::backAskPattie)
            Text(goal.subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            val goalTopics = viewModel.pattieTopics.filter { it.id in goal.topicIds }
            goalTopics.forEach { item -> TopicCard(item) { viewModel.chooseTopic(item.id) } }
        }
        else -> {
            BackChoiceHeader(topic.title, viewModel::backAskPattie)
            Text(topic.question, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            val answers = viewModel.pattieAnswers.filter { it.topicId == topic.id && goal.id in it.goalIds }
            answers.forEach { item -> AnswerChoiceCard(item) { viewModel.chooseAnswer(item.id) } }
            if (answers.isEmpty()) {
                ContentCard {
                    Text("No matching pointer is available yet.", style = MaterialTheme.typography.titleMedium)
                    Text("Try another topic or training goal.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
private fun BackChoiceHeader(title: String, onBack: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.small)) {
        IconButton(onClick = onBack, modifier = Modifier.height(Space.tapTarget).width(Space.tapTarget)) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
        }
        Text(title, style = MaterialTheme.typography.titleLarge)
    }
}

@Composable
private fun GoalCard(goal: PattieGoal, onClick: () -> Unit) = ChoiceCard(goal.title, goal.subtitle, onClick)

@Composable
private fun TopicCard(topic: PattieTopic, onClick: () -> Unit) = ChoiceCard(topic.title, topic.question, onClick)

@Composable
private fun AnswerChoiceCard(answer: PattieAnswer, onClick: () -> Unit) = ChoiceCard(answer.headline, answer.situation, onClick)

@Composable
private fun ChoiceCard(title: String, subtitle: String, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().heightIn(min = Space.tapTarget),
        shape = RoundedCornerShape(Space.cardRadius),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(Modifier.fillMaxWidth().padding(Space.card), verticalArrangement = Arrangement.spacedBy(Space.small)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 3)
        }
    }
}

@Composable
private fun AnswerCard(state: AppUiState, answer: PattieAnswer, viewModel: IronSplitsViewModel) {
    Column(verticalArrangement = Arrangement.spacedBy(Space.section)) {
        BackChoiceHeader(answer.headline, viewModel::backAskPattie)
        ContentCard {
            Text("THE SITUATION", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(answer.situation, style = MaterialTheme.typography.bodyLarge)
            VoiceButton(state, answer.situationVoice, viewModel)
        }
        ContentCard {
            Text("PATTIE'S POINTER", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(answer.solution, style = MaterialTheme.typography.bodyLarge)
            VoiceButton(state, answer.solutionVoice, viewModel)
        }
        val episode = state.episodes.firstOrNull { it.id == answer.pointerId }
        if (episode != null) {
            OutlinedButton(
                onClick = { viewModel.playEpisode(episode) },
                modifier = Modifier.fillMaxWidth().height(Space.tapTarget),
            ) { Text("Watch episode ${episode.episode}: ${episode.title}") }
        }
        Text(
            "Ask Pattie is a guided library of advice from her recorded race pointers, not an automated chat.",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun VoiceButton(state: AppUiState, clip: String?, viewModel: IronSplitsViewModel) {
    if (clip.isNullOrBlank()) return
    val playing = state.playingVoiceClip == clip
    OutlinedButton(
        onClick = { viewModel.toggleVoiceClip(clip) },
        modifier = Modifier.height(Space.tapTarget),
    ) {
        Icon(if (playing) Icons.Default.Stop else Icons.Default.PlayArrow, contentDescription = null)
        Spacer(Modifier.width(Space.small))
        Text(if (playing) "Stop Pattie's voice" else "Hear Pattie say this")
    }
}

@Composable
private fun EpisodeCard(episode: PointerEpisode, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().heightIn(min = Space.tapTarget).testTag("episode-${episode.id}"),
        shape = RoundedCornerShape(Space.cardRadius),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(Space.card),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Space.row),
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Space.small)) {
                Text("Episode ${episode.episode}: ${episode.title}", style = MaterialTheme.typography.titleMedium)
                Text(episode.summary, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 3)
                formatEpisodeDuration(episode.durationSeconds)?.let { duration ->
                    Text(duration, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Icon(Icons.Default.PlayArrow, contentDescription = "Download and play")
        }
    }
}

internal fun formatEpisodeDuration(seconds: Int): String? {
    if (seconds <= 0) return null
    val minutes = seconds / 60
    val remainingSeconds = seconds % 60
    return when {
        minutes == 0 -> "$seconds sec"
        remainingSeconds == 0 -> "$minutes min"
        else -> "$minutes min $remainingSeconds sec"
    }
}

@Composable
private fun EpisodePlayerCard(state: AppUiState, episode: PointerEpisode, viewModel: IronSplitsViewModel) {
    ContentCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionHeading("Episode ${episode.episode}", episode.title)
            Spacer(Modifier.weight(1f))
            TextButton(onClick = viewModel::closeEpisode) { Text("Close") }
        }
        Text(episode.summary, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (state.loadingVideo) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.row)) {
                CircularProgressIndicator()
                Text("Downloading for offline playback")
            }
        } else if (state.videoPath != null) {
            LocalVideoPlayer(state.videoPath)
        } else {
            Text("Download this episode to play it. The video is cached on this device.", style = MaterialTheme.typography.bodyMedium)
            Button(onClick = { viewModel.playEpisode(episode) }, modifier = Modifier.height(Space.tapTarget)) {
                Text("Download and play")
            }
        }
    }
}

@Composable
private fun LocalVideoPlayer(path: String) {
    val context = LocalContext.current
    val player = remember(path) { VideoView(context) }
    DisposableEffect(player) {
        onDispose { player.stopPlayback() }
    }
    AndroidView(
        factory = {
            val controller = MediaController(context)
            controller.setAnchorView(player)
            player.setMediaController(controller)
            player.setVideoPath(path)
            player.setOnPreparedListener { media -> media.start() }
            player
        },
        modifier = Modifier.fillMaxWidth().height(220.dp),
    )
}
