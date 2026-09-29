package com.jackwallner.ironsplits.ui.screens

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.jackwallner.ironsplits.ui.components.LoadingState
import com.jackwallner.ironsplits.ui.shareFile
import com.jackwallner.ironsplits.ui.theme.ToolbarCircleButton
import com.jackwallner.ironsplits.ui.theme.ToolbarTextButton
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriScreen
import com.jackwallner.ironsplits.ui.theme.TriSheet
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.bottomContentPadding
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** A local viewer, so the PDF never has to leave the phone before it is checked. */
@Composable
fun RaceBookPdfPreviewSheet(visible: Boolean, file: File?, onClose: () -> Unit) {
    val context = LocalContext.current
    TriSheet(visible = visible && file != null, onDismiss = onClose) {
        val pdf = file ?: return@TriSheet
        var pages by remember(pdf) { mutableStateOf<List<Bitmap>?>(null) }
        LaunchedEffect(pdf) { pages = withContext(Dispatchers.IO) { render(pdf) } }
        TriScreen(
            title = "Race Book PDF",
            inSheet = true,
            leading = { ToolbarTextButton("Done", bold = true, onClick = onClose) },
            trailing = {
                ToolbarCircleButton(Icons.Filled.IosShare, "Share PDF") { context.shareFile(pdf, "application/pdf", "Share your Race Book") }
            },
        ) {
            val rendered = pages
            if (rendered == null) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { LoadingState(null) }
            } else {
                LazyColumn(
                    Modifier.fillMaxSize().background(Tri.colors.surfaceSunk),
                    contentPadding = PaddingValues(
                        start = TriSpace.x3, end = TriSpace.x3, top = TriSpace.x3,
                        bottom = TriSpace.x3 + bottomContentPadding(0.dp).calculateBottomPadding(),
                    ),
                    verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
                ) {
                    itemsIndexed(rendered) { _, page ->
                        Image(
                            page.asImageBitmap(),
                            null,
                            contentScale = ContentScale.FillWidth,
                            modifier = Modifier.fillMaxWidth().aspectRatio(page.width.toFloat() / page.height).shadow(2.dp),
                        )
                    }
                }
            }
        }
    }
}

private fun render(file: File): List<Bitmap> = runCatching {
    ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
        PdfRenderer(descriptor).use { renderer ->
            (0 until renderer.pageCount).map { index ->
                renderer.openPage(index).use { page ->
                    val scale = 2.5f
                    val bitmap = Bitmap.createBitmap((page.width * scale).toInt(), (page.height * scale).toInt(), Bitmap.Config.ARGB_8888)
                    bitmap.eraseColor(Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    bitmap
                }
            }
        }
    }
}.getOrDefault(emptyList())
