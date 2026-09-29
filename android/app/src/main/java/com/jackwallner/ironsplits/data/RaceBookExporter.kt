package com.jackwallner.ironsplits.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.RaceAnalytics
import com.jackwallner.ironsplits.model.RaceBookAnalytics
import com.jackwallner.ironsplits.model.RaceBookOptions
import com.jackwallner.ironsplits.model.RaceBookProgressionPoint
import com.jackwallner.ironsplits.model.RaceDate
import com.jackwallner.ironsplits.model.RaceKind
import com.jackwallner.ironsplits.model.RaceResult
import com.jackwallner.ironsplits.model.TimeFormat
import java.io.File
import java.util.Locale

/**
 * Builds the Race Book on this device: a paginated PDF and a tall share image.
 * Mirrors `RaceBookPDFRenderer.swift` and `RaceBookBuilder.image` block for block.
 */
object RaceBookExporter {
    private const val MARGIN = 40f

    private object Palette {
        val deep = rgb(0.020, 0.094, 0.208)
        val deepLift = rgb(0.055, 0.165, 0.360)
        val coral = rgb(0.780, 0.200, 0.165)
        val aqua = rgb(0.122, 0.396, 0.729)
        val green = rgb(0.361, 0.706, 0.145)
        val canvas = rgb(0.949, 0.953, 0.961)
        val card = Color.WHITE
        val ink = rgb(0.075, 0.098, 0.129)
        val secondary = rgb(0.259, 0.290, 0.333)
        val muted = rgb(0.439, 0.471, 0.522)
        val line = rgb(0.827, 0.839, 0.859)
        val paleBlue = rgb(0.895, 0.932, 0.988)
        val paleCoral = rgb(0.988, 0.914, 0.902)
    }

    private fun rgb(r: Double, g: Double, b: Double) = Color.rgb((r * 255).toInt(), (g * 255).toInt(), (b * 255).toInt())

    private fun withAlpha(color: Int, alpha: Float) = Color.argb((alpha * 255).toInt(), Color.red(color), Color.green(color), Color.blue(color))

    private fun exportDir(context: Context) = File(context.cacheDir, "race-books").apply { mkdirs() }

    fun safeFileName(name: String): String {
        val safe = name.lowercase(Locale.ROOT).split(Regex("[^\\p{L}\\p{N}]+")).filter { it.isNotEmpty() }.joinToString("-")
        return safe.ifEmpty { "iron-splits" }
    }

    // region Text

    private enum class W { REGULAR, MEDIUM, SEMIBOLD, BOLD }

    private fun paint(size: Float, weight: W, color: Int, mono: Boolean = false, tracking: Float = 0f): TextPaint =
        TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = size
            this.color = color
            typeface = when {
                Build.VERSION.SDK_INT >= 28 -> Typeface.create(
                    Typeface.DEFAULT,
                    when (weight) { W.REGULAR -> 400; W.MEDIUM -> 500; W.SEMIBOLD -> 600; W.BOLD -> 700 },
                    false,
                )
                weight == W.BOLD || weight == W.SEMIBOLD -> Typeface.DEFAULT_BOLD
                else -> Typeface.DEFAULT
            }
            if (mono) fontFeatureSettings = "tnum"
            if (tracking != 0f) letterSpacing = tracking / size
        }

    private fun layout(text: String, paint: TextPaint, width: Float, align: Layout.Alignment, spacing: Float): StaticLayout =
        StaticLayout.Builder.obtain(text, 0, text.length, paint, maxOf(1, width.toInt()))
            .setAlignment(align)
            .setLineSpacing(spacing, 1f)
            .setIncludePad(false)
            .build()

    private fun textHeight(text: String, paint: TextPaint, width: Float, spacing: Float = 1.5f): Float {
        if (text.isEmpty() || width <= 0) return 0f
        val lineHeight = paint.fontMetrics.let { it.descent - it.ascent }
        return maxOf(lineHeight, layout(text, paint, width, Layout.Alignment.ALIGN_NORMAL, spacing).height.toFloat())
    }

    private fun Canvas.text(
        value: String,
        rect: RectF,
        paint: TextPaint,
        align: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL,
        spacing: Float = 1.5f,
    ): Float {
        if (value.isEmpty() || rect.width() <= 0) return 0f
        val staticLayout = layout(value, paint, rect.width(), align, spacing)
        save()
        clipRect(rect)
        translate(rect.left, rect.top)
        staticLayout.draw(this)
        restore()
        return textHeight(value, paint, rect.width(), spacing)
    }

    private fun Canvas.fill(rect: RectF, color: Int) {
        drawRect(rect, Paint().apply { this.color = color; style = Paint.Style.FILL })
    }

    private fun Canvas.card(rect: RectF, fill: Int = Palette.card, stroke: Int = Palette.line, radius: Float = 12f) {
        drawRoundRect(rect, radius, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = fill; style = Paint.Style.FILL })
        drawRoundRect(rect, radius, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = stroke; style = Paint.Style.STROKE; strokeWidth = 0.7f })
    }

    private fun Canvas.line(x1: Float, y1: Float, x2: Float, y2: Float, color: Int, width: Float) {
        drawLine(x1, y1, x2, y2, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color; strokeWidth = width })
    }

    private fun rect(x: Float, y: Float, w: Float, h: Float) = RectF(x, y, x + w, y + h)

    // endregion

    private fun dateText(result: RaceResult) = RaceDate.text(result)

    private fun singleLine(value: String, limit: Int): String {
        val normalized = value.replace("\\n", " ").split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
        if (normalized.length <= limit) return normalized
        return normalized.take(maxOf(limit - 1, 1)) + "…"
    }

    private fun color(discipline: Discipline) = when (discipline) {
        Discipline.SWIM -> Palette.aqua
        Discipline.BIKE -> Palette.green
        Discipline.RUN -> Palette.coral
        Discipline.T1, Discipline.T2, Discipline.TRANSITIONS -> Palette.muted
        Discipline.FINISH -> Palette.deep
    }

    // region PDF

    private class Doc(val pdf: PdfDocument, val width: Float, val height: Float) {
        var page: PdfDocument.Page? = null
        var pageNumber = 0
        val canvas: Canvas get() = page!!.canvas
        val contentBottom: Float get() = height - 56f
    }

    fun pdf(context: Context, athlete: Athlete, results: List<RaceResult>, notes: Map<String, RaceNote>, options: RaceBookOptions): File? {
        val scoped = RaceBookAnalytics.filteredResults(results, options)
        val region = Locale.getDefault().country.uppercase(Locale.ROOT)
        val (width, height) = if (region == "US" || region == "CA") 612f to 792f else 595f to 842f
        val pdf = PdfDocument()
        val doc = Doc(pdf, width, height)
        return try {
            if (options.onePage) {
                renderOnePage(doc, athlete, scoped, options)
            } else {
                renderCover(doc, athlete, scoped, options)
                if (options.includePersonalBests || options.includePodiumHighlights || options.includeProgression) {
                    renderHighlights(doc, scoped, options)
                }
                if (options.includeRaceHistory) renderHistory(doc, scoped, notes, options)
            }
            val file = File(exportDir(context), "${safeFileName(athlete.name)}-race-book.pdf")
            file.outputStream().use { pdf.writeTo(it) }
            file
        } catch (_: Throwable) {
            null
        } finally {
            pdf.close()
        }
    }

    private fun beginPage(doc: Doc) {
        doc.pageNumber++
        doc.page = doc.pdf.startPage(PdfDocument.PageInfo.Builder(doc.width.toInt(), doc.height.toInt(), doc.pageNumber).create())
        doc.canvas.fill(rect(0f, 0f, doc.width, doc.height), Palette.canvas)
    }

    private fun beginContentPage(doc: Doc, kicker: String, title: String): Float {
        beginPage(doc)
        val c = doc.canvas
        c.fill(rect(0f, 0f, doc.width, 8f), Palette.deep)
        c.text(kicker.uppercase(), rect(MARGIN, 34f, doc.width - MARGIN * 2, 14f), paint(8f, W.BOLD, Palette.coral, tracking = 1.1f))
        c.text(title, rect(MARGIN, 52f, doc.width - MARGIN * 2, 34f), paint(25f, W.BOLD, Palette.deep))
        c.line(MARGIN, 100f, doc.width - MARGIN, 100f, Palette.line, 0.7f)
        return 120f
    }

    private fun endPage(doc: Doc) {
        val c = doc.canvas
        c.line(MARGIN, doc.height - 38, doc.width - MARGIN, doc.height - 38, Palette.line, 0.7f)
        c.text(
            "IM TRI TRACKER  |  OFFICIAL RESULTS, PRIVATE NOTES",
            rect(MARGIN, doc.height - 30, 420f, 12f),
            paint(7.5f, W.SEMIBOLD, Palette.muted, tracking = 0.3f),
        )
        c.text(
            "${doc.pageNumber}",
            rect(doc.width - MARGIN - 36, doc.height - 30, 36f, 12f),
            paint(8f, W.SEMIBOLD, Palette.muted, mono = true),
            Layout.Alignment.ALIGN_OPPOSITE,
        )
        doc.pdf.finishPage(doc.page)
        doc.page = null
    }

    private fun ensureSpace(doc: Doc, y: Float, height: Float, title: String): Float {
        if (y + height <= doc.contentBottom) return y
        endPage(doc)
        return beginContentPage(doc, "CONTINUED", title)
    }

    private fun drawStat(doc: Doc, value: String, label: String, x: Float, width: Float, y: Float, accent: Boolean = false) {
        doc.canvas.text(value, rect(x, y, width, 30f), paint(23f, W.BOLD, if (accent) Palette.coral else Palette.deep, mono = true), Layout.Alignment.ALIGN_CENTER, 0f)
        doc.canvas.text(label, rect(x + 4, y + 38, width - 8, 16f), paint(7.5f, W.BOLD, Palette.muted, tracking = 0.6f), Layout.Alignment.ALIGN_CENTER)
    }

    private fun renderOnePage(doc: Doc, athlete: Athlete, results: List<RaceResult>, options: RaceBookOptions) {
        beginPage(doc)
        val c = doc.canvas
        val w = doc.width
        val heroHeight = 164f
        c.fill(rect(0f, 0f, w, heroHeight), Palette.deep)
        c.fill(rect(0f, 0f, 12f, heroHeight), Palette.coral)
        c.text("IM TRI TRACKER  |  ONE-PAGE RACE BOOK", rect(MARGIN, 32f, w - MARGIN * 2, 14f), paint(8.5f, W.BOLD, Palette.coral, tracking = 1f))
        c.text(athlete.name, rect(MARGIN, 58f, w - MARGIN * 2, 42f), paint(30f, W.BOLD, Color.WHITE), spacing = 0f)
        athlete.location?.takeIf { it.isNotEmpty() }?.let {
            c.text(it, rect(MARGIN, 108f, w - MARGIN * 2, 16f), paint(10f, W.REGULAR, withAlpha(Color.WHITE, 0.72f)))
        }
        val summary = RaceAnalytics.summary(results)
        var y = 184f
        if (options.includeCareerSummary) {
            val stats = rect(MARGIN, y, w - MARGIN * 2, 82f)
            c.card(stats, Palette.card, Palette.card)
            val statWidth = stats.width() / 3
            drawStat(doc, "${summary.starts}", "STARTS", stats.left, statWidth, stats.top + 14)
            drawStat(doc, "${summary.finishes}", "FINISHES", stats.left + statWidth, statWidth, stats.top + 14)
            drawStat(doc, "${summary.podiums}", "PODIUMS", stats.left + statWidth * 2, statWidth, stats.top + 14, accent = true)
            y = stats.bottom + 22
        }
        if (options.includePersonalBests) {
            val rows = RaceAnalytics.availableKinds(results).flatMap { RaceBookAnalytics.bests(results, it).take(2) }.take(4)
            val card = rect(MARGIN, y, w - MARGIN * 2, maxOf(rows.size, 1) * 24f + 36)
            c.card(card, Palette.paleBlue, Palette.paleBlue)
            c.text("PERSONAL BESTS", rect(card.left + 18, card.top + 12, card.width() - 36, 14f), paint(8f, W.BOLD, Palette.aqua, tracking = 0.8f))
            if (rows.isEmpty()) {
                c.text("No complete splits are available yet.", rect(card.left + 18, card.top + 30, card.width() - 36, 16f), paint(9f, W.REGULAR, Palette.secondary))
            } else {
                rows.forEachIndexed { index, best ->
                    val rowY = card.top + 32 + index * 24
                    c.fill(rect(card.left + 18, rowY + 4, 7f, 7f), color(best.discipline))
                    c.text(
                        "${best.discipline.title}  ·  ${singleLine(best.result.raceName, 42)}",
                        rect(card.left + 32, rowY, card.width() - 172, 16f),
                        paint(8.5f, W.REGULAR, Palette.secondary),
                    )
                    c.text(TimeFormat.hms(best.seconds), rect(card.right - 128, rowY, 110f, 16f), paint(8.5f, W.SEMIBOLD, Palette.deep, mono = true), Layout.Alignment.ALIGN_OPPOSITE, 0f)
                }
            }
            y = card.bottom + 14
        }
        if (options.includePodiumHighlights) {
            val rows = results.filter { it.isComplete && (it.finishRankGroup ?: Int.MAX_VALUE) <= 3 }.take(2)
            val card = rect(MARGIN, y, w - MARGIN * 2, maxOf(rows.size, 1) * 24f + 36)
            c.card(card, Palette.paleCoral, Palette.paleCoral)
            c.text("PODIUM MOMENTS", rect(card.left + 18, card.top + 12, card.width() - 36, 14f), paint(8f, W.BOLD, Palette.coral, tracking = 0.8f))
            if (rows.isEmpty()) {
                c.text("No podium finishes recorded yet.", rect(card.left + 18, card.top + 30, card.width() - 36, 16f), paint(9f, W.REGULAR, Palette.secondary))
            } else {
                rows.forEachIndexed { index, result ->
                    val rowY = card.top + 32 + index * 24
                    c.text("#${result.finishRankGroup ?: 0}  ${singleLine(result.raceName, 44)}", rect(card.left + 18, rowY, card.width() - 174, 16f), paint(8.5f, W.REGULAR, Palette.secondary))
                    c.text(dateText(result), rect(card.right - 140, rowY, 122f, 16f), paint(8f, W.REGULAR, Palette.muted), Layout.Alignment.ALIGN_OPPOSITE)
                }
            }
            y = card.bottom + 14
        }
        if (options.includeRaceHistory) {
            val rows = results.take(5)
            val card = rect(MARGIN, y, w - MARGIN * 2, maxOf(rows.size, 1) * 26f + 36)
            c.card(card, Palette.card)
            c.text("RECENT RACE HISTORY", rect(card.left + 18, card.top + 12, card.width() - 36, 14f), paint(8f, W.BOLD, Palette.coral, tracking = 0.8f))
            if (rows.isEmpty()) {
                c.text("No races match these choices.", rect(card.left + 18, card.top + 30, card.width() - 36, 16f), paint(9f, W.REGULAR, Palette.muted))
            } else {
                rows.forEachIndexed { index, result ->
                    val rowY = card.top + 32 + index * 26
                    c.text(dateText(result), rect(card.left + 18, rowY, 76f, 16f), paint(7.5f, W.BOLD, Palette.coral))
                    c.text(singleLine(result.raceName, 44), rect(card.left + 100, rowY, card.width() - 226, 16f), paint(8.5f, W.SEMIBOLD, Palette.ink))
                    val status = if (result.isComplete) TimeFormat.hms(result.finish) else result.statusLabel ?: "Incomplete"
                    c.text(status, rect(card.right - 110, rowY, 92f, 16f), paint(8f, W.SEMIBOLD, if (result.isComplete) Palette.deep else Palette.coral, mono = true), Layout.Alignment.ALIGN_OPPOSITE, 0f)
                }
            }
            if (results.size > rows.size) {
                c.text("+${results.size - rows.size} more races in the full report", rect(card.left + 18, card.bottom - 18, card.width() - 36, 12f), paint(7.5f, W.REGULAR, Palette.muted), Layout.Alignment.ALIGN_OPPOSITE)
            }
        }
        endPage(doc)
    }

    private fun renderCover(doc: Doc, athlete: Athlete, results: List<RaceResult>, options: RaceBookOptions) {
        beginPage(doc)
        val c = doc.canvas
        val w = doc.width
        val heroHeight = 286f
        c.fill(rect(0f, 0f, w, heroHeight), Palette.deep)
        c.fill(rect(0f, 0f, 12f, heroHeight), Palette.coral)
        c.fill(rect(462f, -34f, 210f, 210f), Palette.deepLift)
        c.drawOval(rect(492f, 24f, 110f, 110f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = withAlpha(Palette.deepLift, 0.7f) })
        c.text("IM TRI TRACKER  |  RACE BOOK", rect(MARGIN, 42f, 400f, 16f), paint(9f, W.BOLD, Palette.coral, tracking = 1.2f))
        c.text("A career in motion", rect(MARGIN, 70f, 430f, 24f), paint(15f, W.SEMIBOLD, withAlpha(Color.WHITE, 0.75f)))

        var nameSize = 34f
        var namePaint = paint(nameSize, W.BOLD, Color.WHITE)
        var nameHeight = textHeight(athlete.name, namePaint, 410f, 0f)
        while (nameHeight > 78 && nameSize > 22) {
            nameSize -= 2
            namePaint = paint(nameSize, W.BOLD, Color.WHITE)
            nameHeight = textHeight(athlete.name, namePaint, 410f, 0f)
        }
        c.text(athlete.name, rect(MARGIN, 108f, 410f, nameHeight), namePaint, spacing = 0f)
        val location = athlete.location?.takeIf { it.isNotEmpty() }
        location?.let {
            c.text(singleLine(it, 45), rect(MARGIN, 108 + nameHeight + 8, 390f, 18f), paint(11f, W.REGULAR, withAlpha(Color.WHITE, 0.72f)))
        }
        val summary = RaceAnalytics.summary(results)
        summary.years?.let { years ->
            val locationBottom = if (location == null) 0f else 108 + nameHeight + 30
            c.text(
                if (years.first == years.last) "RACING SINCE ${years.first}" else "RACING ${years.first} TO ${years.last}",
                rect(MARGIN, maxOf(226f, locationBottom), 300f, 16f),
                paint(8.5f, W.BOLD, withAlpha(Color.WHITE, 0.66f), tracking = 1f),
            )
        }
        c.text("01", rect(w - MARGIN - 80, 220f, 80f, 40f), paint(30f, W.BOLD, withAlpha(Color.WHITE, 0.2f), mono = true), Layout.Alignment.ALIGN_OPPOSITE)

        val statsTop = maxOf(244f, 108 + nameHeight + (if (location == null) 0f else 38f) + 30)
        if (options.includeCareerSummary) {
            val stats = rect(MARGIN, statsTop, w - MARGIN * 2, 116f)
            c.card(stats, Palette.card, Palette.card)
            val statWidth = stats.width() / 3
            drawStat(doc, "${summary.starts}", "STARTS", stats.left, statWidth, stats.top + 23)
            drawStat(doc, "${summary.finishes}", "FINISHES", stats.left + statWidth, statWidth, stats.top + 23)
            drawStat(doc, "${summary.podiums}", "PODIUMS", stats.left + statWidth * 2, statWidth, stats.top + 23, accent = true)
        }
        var y = if (options.includeCareerSummary) 398 + maxOf(0f, statsTop - 244) else 398f
        c.text("THE DISTANCE STORY", rect(MARGIN, y, 300f, 16f), paint(9f, W.BOLD, Palette.coral, tracking = 1f))
        y += 28
        val total = maxOf(summary.fullDistance + summary.halfDistance, 1)
        val trackWidth = w - MARGIN * 2
        val fullWidth = trackWidth * summary.fullDistance / total
        val track = rect(MARGIN, y, trackWidth, 14f)
        c.card(track, Palette.line, Palette.line, 7f)
        if (summary.fullDistance > 0) c.fill(rect(track.left, track.top, maxOf(14f, fullWidth), track.height()), Palette.deep)
        if (summary.halfDistance > 0) c.fill(rect(track.left + fullWidth, track.top, maxOf(14f, track.width() - fullWidth), track.height()), Palette.aqua)
        drawDistanceLabel(doc, "FULL DISTANCE", "${summary.fullDistance}", Palette.deep, MARGIN, y + 34)
        drawDistanceLabel(doc, "HALF DISTANCE", "${summary.halfDistance}", Palette.aqua, w / 2 + 8, y + 34)

        results.firstOrNull { it.isComplete }?.let { latest ->
            val milestoneY = 560f
            c.text("LATEST MILESTONE", rect(MARGIN, milestoneY, 300f, 16f), paint(9f, W.BOLD, Palette.coral, tracking = 1f))
            val card = rect(MARGIN, milestoneY + 26, w - MARGIN * 2, 100f)
            c.card(card, Palette.paleCoral, Palette.paleCoral)
            c.text(dateText(latest).uppercase(), rect(card.left + 18, card.top + 16, 260f, 14f), paint(8f, W.BOLD, Palette.coral, tracking = 0.7f))
            c.text(latest.raceName, rect(card.left + 18, card.top + 36, 330f, 36f), paint(14f, W.SEMIBOLD, Palette.ink))
            c.text(TimeFormat.hms(latest.finish), rect(card.right - 165, card.top + 30, 145f, 24f), paint(19f, W.BOLD, Palette.deep, mono = true), Layout.Alignment.ALIGN_OPPOSITE, 0f)
            c.text(latest.kind.longTitle.uppercase(), rect(card.right - 165, card.top + 60, 145f, 14f), paint(8f, W.SEMIBOLD, Palette.secondary, tracking = 0.5f), Layout.Alignment.ALIGN_OPPOSITE)
        }
        endPage(doc)
    }

    private fun drawDistanceLabel(doc: Doc, title: String, value: String, color: Int, x: Float, y: Float) {
        val c = doc.canvas
        c.fill(rect(x, y + 3, 8f, 8f), color)
        c.text(value, rect(x + 16, y - 2, 38f, 24f), paint(18f, W.BOLD, Palette.ink, mono = true), spacing = 0f)
        c.text(title, rect(x + 58, y + 2, 150f, 16f), paint(8f, W.BOLD, Palette.muted, tracking = 0.5f))
    }

    private fun renderHighlights(doc: Doc, results: List<RaceResult>, options: RaceBookOptions) {
        val title = "The work behind the finish"
        var y = beginContentPage(doc, "THE NUMBERS", title)
        val kinds = RaceAnalytics.availableKinds(results)
        if (options.includePersonalBests) {
            for (kind in kinds) {
                y = ensureSpace(doc, y, 164f, title)
                drawBestCard(doc, RaceBookAnalytics.bests(results, kind), kind, y)
                y += 164 + 14
            }
        }
        if (options.includePodiumHighlights) {
            val podiums = results.filter { it.isComplete && (it.finishRankGroup ?: Int.MAX_VALUE) <= 3 }
            y = ensureSpace(doc, y, 64f, title)
            doc.canvas.text("PODIUM MOMENTS", rect(MARGIN, y, 300f, 16f), paint(9f, W.BOLD, Palette.coral, tracking = 1f))
            y += 24
            if (podiums.isEmpty()) {
                doc.canvas.text("No podium finishes recorded yet.", rect(MARGIN, y, doc.width - MARGIN * 2, 20f), paint(10f, W.REGULAR, Palette.muted))
                y += 32
            } else {
                for (result in podiums) {
                    y = ensureSpace(doc, y, 48f, title)
                    drawPodiumRow(doc, result, y)
                    y += 48
                }
            }
        }
        if (options.includeProgression) {
            val progressionKinds = kinds.filter { RaceBookAnalytics.progression(results, Discipline.FINISH, it).size >= 2 }
            if (progressionKinds.isNotEmpty()) {
                y = ensureSpace(doc, y, 190f, title)
                doc.canvas.text("PROGRESSION", rect(MARGIN, y, 300f, 16f), paint(9f, W.BOLD, Palette.coral, tracking = 1f))
                y += 24
                for (kind in progressionKinds) {
                    y = ensureSpace(doc, y, 136f, title)
                    drawProgression(doc, RaceBookAnalytics.progression(results, Discipline.FINISH, kind), kind, y)
                    y += 150
                }
            }
        }
        endPage(doc)
    }

    private fun drawBestCard(doc: Doc, bests: List<com.jackwallner.ironsplits.model.PersonalBest>, kind: RaceKind, y: Float) {
        val c = doc.canvas
        val card = rect(MARGIN, y, doc.width - MARGIN * 2, 164f)
        c.card(card, Palette.card)
        c.text(kind.longTitle.uppercase(), rect(card.left + 18, card.top + 16, 180f, 16f), paint(8.5f, W.BOLD, Palette.coral, tracking = 0.8f))
        c.text("PERSONAL BESTS", rect(card.right - 180, card.top + 16, 162f, 16f), paint(8f, W.SEMIBOLD, Palette.muted, tracking = 0.4f), Layout.Alignment.ALIGN_OPPOSITE)
        if (bests.isEmpty()) {
            c.text("No complete splits are available at this distance yet.", rect(card.left + 18, card.top + 56, card.width() - 36, 24f), paint(10f, W.REGULAR, Palette.muted))
            return
        }
        val positions = listOf(
            card.left + 18 to card.top + 48, card.left + 190 to card.top + 48, card.left + 362 to card.top + 48,
            card.left + 18 to card.top + 98, card.left + 190 to card.top + 98,
        )
        positions.forEachIndexed { index, (x, py) ->
            val discipline = Discipline.rankable[index]
            val best = bests.firstOrNull { it.discipline == discipline }
            c.fill(rect(x, py + 3, 7f, 7f), color(discipline))
            c.text(discipline.title.uppercase(), rect(x + 13, py, 140f, 12f), paint(7.5f, W.BOLD, Palette.muted, tracking = 0.4f))
            c.text(best?.let { TimeFormat.hms(it.seconds) } ?: "-", rect(x, py + 14, 150f, 20f), paint(15f, W.BOLD, Palette.ink, mono = true), spacing = 0f)
            c.text(best?.result?.raceName ?: "No recorded split", rect(x, py + 36, 150f, 18f), paint(7.5f, W.REGULAR, Palette.secondary), spacing = 0.5f)
        }
    }

    private fun drawPodiumRow(doc: Doc, result: RaceResult, y: Float) {
        val c = doc.canvas
        c.fill(rect(MARGIN, y + 8, 28f, 28f), Palette.coral)
        c.text("#${result.finishRankGroup ?: 0}", rect(MARGIN, y + 14, 28f, 16f), paint(9f, W.BOLD, Color.WHITE, mono = true), Layout.Alignment.ALIGN_CENTER, 0f)
        c.text(result.raceName, rect(MARGIN + 42, y + 7, 300f, 18f), paint(10.5f, W.SEMIBOLD, Palette.ink))
        c.text("${dateText(result)}  |  ${result.ageGroup ?: "Division"}", rect(MARGIN + 42, y + 27, 300f, 14f), paint(8f, W.REGULAR, Palette.muted))
        c.text(TimeFormat.hms(result.finish), rect(doc.width - MARGIN - 150, y + 11, 150f, 20f), paint(13f, W.SEMIBOLD, Palette.deep, mono = true), Layout.Alignment.ALIGN_OPPOSITE, 0f)
    }

    private fun drawProgression(doc: Doc, points: List<RaceBookProgressionPoint>, kind: RaceKind, y: Float) {
        val c = doc.canvas
        val card = rect(MARGIN, y, doc.width - MARGIN * 2, 126f)
        c.card(card, Palette.paleBlue, Palette.paleBlue)
        c.text(kind.longTitle.uppercase(), rect(card.left + 18, card.top + 14, 180f, 14f), paint(8f, W.BOLD, Palette.aqua, tracking = 0.7f))
        val chart = rect(card.left + 22, card.top + 42, card.width() - 44, 54f)
        val values = points.map { it.seconds }
        val min = values.minOrNull() ?: return
        val max = values.maxOrNull() ?: return
        for (step in 0..2) {
            val gy = chart.top + step * chart.height() / 2
            c.line(chart.left, gy, chart.right, gy, withAlpha(Palette.line, 0.7f), 0.6f)
        }
        val spread = maxOf(max - min, 1)
        val onChart = points.mapIndexed { index, point ->
            val x = chart.left + chart.width() * index / maxOf(points.size - 1, 1)
            val normalized = (point.seconds - min).toFloat() / spread
            x to (chart.bottom - normalized * chart.height())
        }
        if (onChart.size > 1) {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Palette.aqua; strokeWidth = 2f; style = Paint.Style.STROKE }
            val path = android.graphics.Path().apply {
                moveTo(onChart[0].first, onChart[0].second)
                onChart.drop(1).forEach { lineTo(it.first, it.second) }
            }
            c.drawPath(path, paint)
        }
        val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Palette.coral }
        onChart.forEach { c.drawOval(RectF(it.first - 3, it.second - 3, it.first + 3, it.second + 3), dot) }
        val first = points.first()
        val latest = points.last()
        c.text("FIRST  ${TimeFormat.hms(first.seconds)}", rect(chart.left, card.bottom - 22, 180f, 14f), paint(7.5f, W.SEMIBOLD, Palette.secondary, mono = true))
        c.text("LATEST  ${TimeFormat.hms(latest.seconds)}", rect(chart.right - 180, card.bottom - 22, 180f, 14f), paint(7.5f, W.SEMIBOLD, Palette.secondary, mono = true), Layout.Alignment.ALIGN_OPPOSITE)
    }

    private fun renderHistory(doc: Doc, results: List<RaceResult>, notes: Map<String, RaceNote>, options: RaceBookOptions) {
        val title = "Race history"
        var y = beginContentPage(doc, "THE ARCHIVE", title)
        if (results.isEmpty()) {
            doc.canvas.text("No races match these choices.", rect(MARGIN, y, doc.width - MARGIN * 2, 24f), paint(11f, W.REGULAR, Palette.muted))
            endPage(doc)
            return
        }
        for (kind in listOf(RaceKind.FULL_DISTANCE, RaceKind.HALF_DISTANCE)) {
            val kindResults = results.filter { it.kind == kind }
            if (kindResults.isEmpty()) continue
            y = ensureSpace(doc, y, 38f, title)
            if (y > 120) y += 8
            doc.canvas.text(kind.longTitle.uppercase(), rect(MARGIN, y, 260f, 16f), paint(9f, W.BOLD, Palette.coral, tracking = 1f))
            y += 24
            for (result in kindResults) {
                val note = notes[result.id]
                val height = historyCardHeight(doc, result, note, options)
                y = ensureSpace(doc, y, height, title)
                drawHistoryCard(doc, result, note, options, y, height)
                y += height + 12
            }
        }
        endPage(doc)
    }

    private fun historyCardHeight(doc: Doc, result: RaceResult, note: RaceNote?, options: RaceBookOptions): Float {
        val nameWidth = doc.width - MARGIN * 2 - 200
        val nameHeight = maxOf(18f, textHeight(result.raceName, paint(12.5f, W.SEMIBOLD, Palette.ink), nameWidth, 1f))
        var height = 20 + nameHeight + 14
        if (result.isComplete && options.includeSplits) height += 32
        val noteText = note?.labelledText
        if (options.includeRaceNotes && noteText != null) {
            height += 16 + textHeight(noteText, paint(8.5f, W.REGULAR, Palette.secondary), doc.width - MARGIN * 2 - 52) + 8
        }
        return maxOf(86f, height + 30)
    }

    private fun drawHistoryCard(doc: Doc, result: RaceResult, note: RaceNote?, options: RaceBookOptions, y: Float, height: Float) {
        val c = doc.canvas
        val card = rect(MARGIN, y, doc.width - MARGIN * 2, height)
        c.card(card, Palette.card)
        c.text(dateText(result).uppercase(), rect(card.left + 18, card.top + 14, 180f, 14f), paint(7.5f, W.BOLD, Palette.coral, tracking = 0.6f))
        c.text(result.kind.title.uppercase(), rect(card.right - 100, card.top + 14, 82f, 14f), paint(7.5f, W.BOLD, Palette.muted, tracking = 0.5f), Layout.Alignment.ALIGN_OPPOSITE)
        val namePaint = paint(12.5f, W.SEMIBOLD, Palette.ink)
        val nameWidth = card.width() - 200
        val nameHeight = maxOf(18f, textHeight(result.raceName, namePaint, nameWidth, 1f))
        c.text(result.raceName, rect(card.left + 18, card.top + 34, nameWidth, nameHeight), namePaint, spacing = 1f)
        val status = if (result.isComplete) TimeFormat.hms(result.finish) else result.statusLabel ?: "Incomplete"
        c.text(status, rect(card.right - 170, card.top + 34, 152f, 22f), paint(15f, W.BOLD, if (result.isComplete) Palette.deep else Palette.coral, mono = true), Layout.Alignment.ALIGN_OPPOSITE, 0f)

        var currentY = maxOf(card.top + 34 + nameHeight, card.top + 58) + 8
        val placement = mutableListOf<String>()
        result.bib?.let { placement += "Bib $it" }
        if (options.includePlacements) {
            val group = result.ageGroup
            val place = result.finishRankGroup
            if (group != null && place != null) placement += "$group #$place" else if (place != null) placement += "Division #$place"
            result.finishRankOverall?.let { placement += "$it overall" }
        }
        if (placement.isNotEmpty()) {
            c.text(placement.joinToString("  |  "), rect(card.left + 18, currentY, card.width() - 36, 14f), paint(8f, W.REGULAR, Palette.muted))
            currentY += 18
        }
        if (result.isComplete && options.includeSplits) {
            drawSplitBar(doc, result, card.left + 18, currentY, card.width() - 36)
            currentY += 25
        }
        val noteText = note?.labelledText
        if (options.includeRaceNotes && noteText != null) {
            val notePaint = paint(8.5f, W.REGULAR, Palette.secondary)
            c.fill(rect(card.left + 18, currentY + 1, 3f, maxOf(14f, textHeight(noteText, notePaint, card.width() - 52))), Palette.coral)
            c.text(noteText, rect(card.left + 30, currentY, card.width() - 52, card.bottom - currentY - 10), notePaint)
        }
    }

    private fun drawSplitBar(doc: Doc, result: RaceResult, x: Float, y: Float, width: Float) {
        val c = doc.canvas
        c.card(rect(x, y, width, 8f), Palette.line, Palette.line, 4f)
        val shares = RaceAnalytics.legShares(result)
        if (shares.isEmpty()) return
        var currentX = x
        shares.forEach { share ->
            val segment = maxOf(2f, width * share.share.toFloat())
            c.fill(rect(currentX, y, segment, 8f), color(share.discipline))
            currentX += segment
        }
        val labels = shares.joinToString("  |  ") { "${it.discipline.shortTitle} ${TimeFormat.hms(it.seconds)}" }
        c.text(labels, rect(x, y + 12, width, 14f), paint(6.8f, W.REGULAR, Palette.muted, mono = true), spacing = 0f)
    }

    // endregion

    // region Image

    /** A 1080 x 1920 career card. Private notes are never drawn into it. */
    fun image(context: Context, athlete: Athlete, results: List<RaceResult>, options: RaceBookOptions): File? = try {
        val bitmap = Bitmap.createBitmap(1080, 1920, Bitmap.Config.ARGB_8888)
        val c = Canvas(bitmap)
        c.fill(rect(0f, 0f, 1080f, 1920f), Palette.canvas)
        c.fill(rect(0f, 0f, 1080f, 520f), Palette.deep)
        val scoped = RaceBookAnalytics.filteredResults(results, options)
        val summary = RaceAnalytics.summary(scoped)
        val spacing = 5f
        c.text("IM TRI TRACKER  ·  RACE BOOK", rect(64f, 72f, 952f, 44f), paint(28f, W.SEMIBOLD, Palette.coral), spacing = spacing)
        val nameSize = if (athlete.name.length > 28) 46f else 56f
        c.text(athlete.name, rect(64f, 150f, 952f, 170f), paint(nameSize, W.BOLD, Color.WHITE), spacing = spacing)
        athlete.location?.takeIf { it.isNotEmpty() }?.let {
            c.text(it, rect(64f, 326f, 952f, 44f), paint(24f, W.REGULAR, withAlpha(Color.WHITE, 0.78f)), spacing = spacing)
        }
        if (options.includeCareerSummary || options.includePodiumHighlights) {
            c.text("CAREER AT A GLANCE", rect(64f, 408f, 952f, 26f), paint(18f, W.SEMIBOLD, withAlpha(Color.WHITE, 0.72f)), spacing = spacing)
            val stats = mutableListOf<String>()
            if (options.includeCareerSummary) stats += "${summary.finishes} finishes"
            if (options.includePodiumHighlights) stats += "${summary.podiums} podiums"
            if (options.includeCareerSummary) summary.years?.let {
                stats += if (it.first == it.last) "${it.first}" else "${it.first} to ${it.last}"
            }
            c.text(stats.joinToString("    ·    "), rect(64f, 446f, 952f, 40f), paint(25f, W.MEDIUM, Color.WHITE), spacing = spacing)
        }
        c.fill(rect(48f, 560f, 984f, 1184f), Color.WHITE)
        var y = 610f
        if (options.includePersonalBests) {
            c.text("PERSONAL BESTS BY DISTANCE", rect(88f, y, 904f, 34f), paint(23f, W.BOLD, Palette.deep), spacing = spacing)
            y += 56
            for (kind in RaceKind.supported.filter { it in options.kinds }) {
                val bests = RaceAnalytics.personalBests(scoped, kind).take(3)
                if (bests.isEmpty()) continue
                c.text(kind.longTitle.uppercase(), rect(88f, y, 904f, 28f), paint(17f, W.SEMIBOLD, Palette.coral), spacing = spacing)
                y += 38
                for (best in bests) {
                    c.text("${best.discipline.title}  ${TimeFormat.hms(best.seconds)}", rect(88f, y, 904f, 30f), paint(22f, W.SEMIBOLD, Palette.ink), spacing = spacing)
                    c.text("${best.result.year}  ·  ${best.result.raceName}", rect(88f, y + 30, 904f, 32f), paint(17f, W.REGULAR, Palette.muted), spacing = spacing)
                    y += 72
                }
                y += 8
            }
        }
        if (options.includeRaceHistory) {
            val history = scoped.filter { it.isComplete }.take(3)
            if (history.isNotEmpty() && y < 1550) {
                if (options.includePersonalBests) y += 12
                c.text("RECENT FINISHES", rect(88f, y, 904f, 30f), paint(21f, W.BOLD, Palette.deep), spacing = spacing)
                y += 42
                for (result in history) {
                    if (y >= 1660) break
                    c.text(
                        TextUtils.ellipsize("${result.year}  ·  ${result.raceName}", paint(18f, W.MEDIUM, Palette.secondary), 640f, TextUtils.TruncateAt.END).toString(),
                        rect(88f, y, 640f, 36f), paint(18f, W.MEDIUM, Palette.secondary), spacing = spacing,
                    )
                    c.text(TimeFormat.hms(result.finish), rect(748f, y, 244f, 36f), paint(20f, W.SEMIBOLD, Palette.ink, mono = true), spacing = spacing)
                    y += 46
                }
            }
        }
        c.text("Official results as published by each event timer.", rect(64f, 1810f, 952f, 36f), paint(18f, W.REGULAR, Palette.muted), spacing = spacing)
        c.text("IM Tri Tracker", rect(64f, 1850f, 952f, 32f), paint(18f, W.SEMIBOLD, Palette.deep), spacing = spacing)
        val file = File(exportDir(context), "${safeFileName(athlete.name)}-race-book.png")
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
        file
    } catch (_: Throwable) {
        null
    }

    // endregion
}
