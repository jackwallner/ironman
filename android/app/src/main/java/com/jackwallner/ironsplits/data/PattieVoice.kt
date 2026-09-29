package com.jackwallner.ironsplits.data

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Plays Pattie's bundled clips and says which one is playing. One player for
 * the whole app, so two takes never talk over each other. Every clip is cut
 * from her own episodes; nothing is synthesised.
 */
class PattieVoice(private val context: Context) {
    private val _nowPlaying = MutableStateFlow<String?>(null)
    val nowPlaying: StateFlow<String?> = _nowPlaying.asStateFlow()

    private var player: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())

    val isSpeaking: Boolean get() = _nowPlaying.value != null

    fun isPlaying(name: String?): Boolean = name != null && _nowPlaying.value == name

    fun play(name: String?): Boolean = start(name)

    /**
     * Companion reactions behave like iOS ambient audio: a phone set to silent
     * or vibrate keeps Pattie quiet.
     */
    fun playCompanion(name: String?): Boolean {
        val audio = context.getSystemService(AudioManager::class.java)
        if (audio != null && audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return false
        return start(name)
    }

    fun playIfQuiet(name: String?): Boolean = if (isSpeaking) false else play(name)

    fun playCompanionIfQuiet(name: String?): Boolean = if (isSpeaking) false else playCompanion(name)

    /** Tapping the clip that is playing stops it. */
    fun toggle(name: String?) {
        if (name == null) return
        if (_nowPlaying.value == name) stop() else play(name)
    }

    fun stop() {
        val old = player ?: run {
            _nowPlaying.value = null
            return
        }
        player = null
        _nowPlaying.value = null
        runCatching { old.setVolume(0f, 0f) }
        handler.postDelayed({ runCatching { old.stop() }; old.release() }, 60)
    }

    private fun start(name: String?): Boolean {
        if (name == null) return false
        val descriptor = runCatching { context.assets.openFd("pattie-voice/$name.m4a") }.getOrNull() ?: return false
        stop()
        val next = MediaPlayer()
        return runCatching {
            next.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            descriptor.use { next.setDataSource(it.fileDescriptor, it.startOffset, it.length) }
            next.setOnPreparedListener { if (player === it) it.start() }
            next.setOnCompletionListener { finished ->
                if (player === finished) {
                    player = null
                    _nowPlaying.value = null
                }
                finished.release()
            }
            next.setOnErrorListener { failed, _, _ ->
                if (player === failed) {
                    player = null
                    _nowPlaying.value = null
                }
                failed.release()
                true
            }
            player = next
            _nowPlaying.value = name
            next.prepareAsync()
            true
        }.getOrElse {
            next.release()
            if (player === next) player = null
            _nowPlaying.value = null
            false
        }
    }
}

/**
 * The real tips Pattie Mode can say, taken from the same answer tree as Ask
 * Pattie so the bubble never shows one tip while speaking another.
 */
object PattieVoiceLibrary {
    data class ModeTip(val id: String, val topic: String, val text: String, val voice: String)
    data class Catchphrase(val text: String, val voice: String)

    val catchphrases = listOf(
        Catchphrase("Away you go!", "pattie-away-you-go"),
        Catchphrase("Good!", "pattie-good"),
        Catchphrase("Great idea!", "pattie-great-idea"),
        Catchphrase("Nice!", "pattie-nice"),
        Catchphrase("Now that's a great idea!", "pattie-now-that-s-a-great-idea"),
        Catchphrase("That's a great idea!", "pattie-that-s-a-great-idea"),
    )

    fun modeTips(guide: AskPattieGuide?): List<ModeTip> = guide?.answers.orEmpty().mapNotNull { answer ->
        val voice = answer.solutionVoice ?: return@mapNotNull null
        if (answer.solution.isEmpty()) return@mapNotNull null
        ModeTip(answer.id, answer.topic, answer.solution, voice)
    }

    fun nextModeTip(tips: List<ModeTip>, played: Set<String>, avoiding: String?): ModeTip? {
        if (tips.isEmpty()) return null
        val ids = tips.map { it.id }.toSet()
        val started = played.intersect(ids)
        val source = if (started.size >= ids.size) tips else tips.filter { it.id !in started }
        var candidates = source
        if (candidates.size > 1 && avoiding != null) candidates = candidates.filter { it.id != avoiding }
        if (candidates.isEmpty()) candidates = source
        return candidates.randomOrNull()
    }
}
