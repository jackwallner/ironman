package com.jackwallner.ironsplits.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.RaceResult
import java.io.File
import java.io.FileOutputStream

class RaceBookExporter(context: Context) {
    private val directory = File(context.cacheDir, "race-books").apply { mkdirs() }

    fun pdf(athleteName: String, first: RaceResult, second: RaceResult): File {
        val document = PdfDocument()
        val page = document.startPage(PdfDocument.PageInfo.Builder(612, 792, 1).create())
        drawPage(page.canvas, athleteName, first, second)
        document.finishPage(page)
        val target = File(directory, "iron-splits-race-book.pdf")
        FileOutputStream(target).use(document::writeTo)
        document.close()
        return target
    }

    fun image(athleteName: String, first: RaceResult, second: RaceResult): File {
        val bitmap = Bitmap.createBitmap(1_080, 1_350, Bitmap.Config.ARGB_8888)
        drawPage(Canvas(bitmap), athleteName, first, second, scale = 1.75f)
        val target = File(directory, "iron-splits-race-book.png")
        FileOutputStream(target).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
        return target
    }

    private fun drawPage(canvas: Canvas, athleteName: String, first: RaceResult, second: RaceResult, scale: Float = 1f) {
        canvas.save()
        canvas.scale(scale, scale)
        canvas.drawColor(Color.rgb(244, 246, 248))
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Typeface.create("sans-serif", Typeface.NORMAL) }
        val heading = Paint(paint).apply { color = Color.rgb(17, 43, 67); textSize = 25f; typeface = Typeface.create("sans-serif", Typeface.BOLD) }
        val title = Paint(paint).apply { color = Color.rgb(23, 42, 58); textSize = 17f; typeface = Typeface.create("sans-serif", Typeface.BOLD) }
        val body = Paint(paint).apply { color = Color.rgb(23, 42, 58); textSize = 13f }
        val muted = Paint(paint).apply { color = Color.rgb(80, 98, 116); textSize = 11f }
        val divider = Paint(paint).apply { color = Color.rgb(212, 221, 229); strokeWidth = 1f }

        canvas.drawText("IM TRI TRACKER", 42f, 56f, muted)
        canvas.drawText("Race Book", 42f, 91f, heading)
        canvas.drawText(athleteName.take(56), 42f, 121f, body)
        val kind = first.kind.fullLabel
        canvas.drawText(kind, 42f, 145f, muted)
        canvas.drawLine(42f, 165f, 570f, 165f, divider)

        val firstTitle = "${first.year} ${first.raceName}".take(52)
        val secondTitle = "${second.year} ${second.raceName}".take(52)
        canvas.drawText(firstTitle, 42f, 202f, title)
        canvas.drawText(formatTime(first.finish), 360f, 202f, body)
        canvas.drawText(secondTitle, 42f, 231f, title)
        canvas.drawText(formatTime(second.finish), 360f, 231f, body)
        canvas.drawLine(42f, 250f, 570f, 250f, divider)

        var y = 283f
        canvas.drawText("Split", 42f, y, muted)
        canvas.drawText("First race", 290f, y, muted)
        canvas.drawText("Second race", 430f, y, muted)
        y += 28f
        val rows = listOf(Discipline.SWIM, Discipline.T1, Discipline.BIKE, Discipline.T2, Discipline.RUN, Discipline.FINISH)
        rows.forEach { discipline ->
            val firstTime = first.seconds(discipline)
            val secondTime = second.seconds(discipline)
            canvas.drawText(discipline.label, 42f, y, body)
            canvas.drawText(formatTime(firstTime), 290f, y, body)
            canvas.drawText(formatTime(secondTime), 430f, y, body)
            y += 29f
        }
        canvas.drawLine(42f, y + 5f, 570f, y + 5f, divider)
        y += 36f
        val delta = (second.finish ?: 0) - (first.finish ?: 0)
        canvas.drawText("Finish change", 42f, y, title)
        canvas.drawText(if (delta < 0) "${formatTime(-delta)} faster" else "${formatTime(delta)} slower", 290f, y, body)
        y += 44f
        canvas.drawText("Published results. IM Tri Tracker is independent and unaffiliated with race organizers or timing companies.", 42f, y, muted)
        canvas.restore()
    }

    private fun formatTime(seconds: Int?): String {
        if (seconds == null || seconds <= 0) return "—"
        val h = seconds / 3_600
        val m = seconds % 3_600 / 60
        val s = seconds % 60
        return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
    }
}
