package com.m5ham3ds.raven23.downloads

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Binder
import android.os.ParcelFileDescriptor
import androidx.media3.common.util.UnstableApi
import java.io.File
import java.io.FileNotFoundException
import org.json.JSONObject

/**
 * Read-only bridge for RAVEN23 Player.
 *
 * Completed private downloads are exposed through temporary content URIs.
 * The MP4 remains in RAVEN23's private filesDir/offline_exports directory;
 * no public MediaStore copy is created. Every URI grant is restricted to the
 * companion package and every call checks the Binder caller again.
 */
@UnstableApi
class Raven23PlayerMediaProvider : ContentProvider() {
    private val appContext get() = checkNotNull(context).applicationContext
    private val store by lazy { StreamDownloadStore.get(appContext) }
    private val exporter by lazy { StreamDownloadExporter(appContext, store) }

    override fun onCreate(): Boolean = context != null

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        enforcePlayerCaller()
        require(uri.pathSegments.size == 1 && uri.pathSegments[0] == "downloads") {
            "Unsupported RAVEN23 media query."
        }

        val columns = arrayOf(
            "id", "title", "mediaType", "quality", "state", "progress",
            "bytesDownloaded", "contentLength", "createdAt", "contentId",
            "seasonNumber", "episodeNumber", "posterUrl", "seriesPosterPath",
            "seriesBackdropPath", "expectedDurationMs", "subtitleStatus",
            "subtitleUri", "subtitleName", "videoUri", "durationMs",
            "sizeBytes", "isPlayable", "downloadDataJson",
        )
        val result = MatrixCursor(columns)
        val providerRoot = Uri.parse("content://$AUTHORITY/downloads")

        store.getDownloads()
            .sortedByDescending { it.startTimeMs }
            .forEach { download ->
                val metadata = StreamDownloadStore.requestMetadata(download.request)
                val downloadMap = store.downloadToMap(download).toMutableMap()
                val export = if (download.state == androidx.media3.exoplayer.offline.Download.STATE_COMPLETED) {
                    exporter.existingExport(download.request.id)
                } else {
                    null
                }
                val subtitle = store.subtitleFileForExport(download.request.id, download.request)
                val id = download.request.id
                val videoUri = if (export != null) {
                    providerRoot.buildUpon().appendPath(id).appendPath("video").build()
                        .also { grantPlayerRead(it) }
                } else {
                    null
                }
                val subtitleUri = subtitle?.takeIf { it.isFile && it.length() > 0L }?.let {
                    providerRoot.buildUpon().appendPath(id).appendPath("subtitle").build()
                        .also { grantPlayerRead(it) }
                }

                val expectedDuration = metadata.optLong("expectedDurationMs", 0L)
                    .takeIf { it > 0L } ?: 0L
                val title = metadata.optString("title", "RAVEN23 video")
                    .trim().ifBlank { "RAVEN23 video" }
                downloadMap["isPlayable"] = export != null
                downloadMap["videoUri"] = videoUri?.toString().orEmpty()
                downloadMap["subtitleUri"] = subtitleUri?.toString().orEmpty()
                downloadMap["subtitleName"] = subtitle?.name.orEmpty()
                downloadMap["durationMs"] = expectedDuration
                downloadMap["sizeBytes"] = export?.length() ?: download.bytesDownloaded

                result.addRow(
                    arrayOf<Any?>(
                        id,
                        title,
                        metadata.optString("mediaType", "video"),
                        metadata.optString("quality", "Auto"),
                        downloadMap["state"],
                        downloadMap["progress"],
                        download.bytesDownloaded,
                        download.contentLength,
                        download.startTimeMs,
                        downloadMap["contentId"],
                        downloadMap["seasonNumber"],
                        downloadMap["episodeNumber"],
                        metadata.optString("posterUrl").ifBlank { null },
                        metadata.optString("seriesPosterPath").ifBlank { null },
                        metadata.optString("seriesBackdropPath").ifBlank { null },
                        expectedDuration,
                        metadata.optString("subtitleStatus", "none"),
                        subtitleUri?.toString().orEmpty(),
                        subtitle?.name.orEmpty(),
                        videoUri?.toString().orEmpty(),
                        expectedDuration,
                        export?.length() ?: download.bytesDownloaded,
                        export != null,
                        JSONObject(downloadMap).toString(),
                    ),
                )
            }

        return result
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        enforcePlayerCaller()
        if (mode != "r") throw SecurityException("RAVEN23 Player media is read-only.")
        val segments = uri.pathSegments
        if (segments.size != 3 || segments[0] != "downloads") {
            throw FileNotFoundException("Unknown RAVEN23 media URI.")
        }
        val id = segments[1]
        val file = when (segments[2]) {
            "video" -> exporter.existingExport(id)
            "subtitle" -> {
                val download = store.getDownload(id)
                    ?: throw FileNotFoundException("RAVEN23 download no longer exists.")
                store.subtitleFileForExport(id, download.request)
            }
            else -> null
        }?.takeIf { it.isFile && it.length() > 0L }
            ?: throw FileNotFoundException("The requested RAVEN23 offline file is not ready.")
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun getType(uri: Uri): String? {
        enforcePlayerCaller()
        return when (uri.pathSegments.lastOrNull()) {
            "video" -> "video/mp4"
            "subtitle" -> when (uri.lastPathSegment?.substringAfterLast('.', "")?.lowercase()) {
                "srt" -> "application/x-subrip"
                else -> "text/vtt"
            }
            else -> null
        }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? =
        throw UnsupportedOperationException("RAVEN23 Player media is read-only.")

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = throw UnsupportedOperationException("RAVEN23 Player media is read-only.")

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = throw UnsupportedOperationException("RAVEN23 Player media is read-only.")

    private fun grantPlayerRead(uri: Uri) {
        appContext.grantUriPermission(
            PLAYER_PACKAGE,
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )
    }

    private fun enforcePlayerCaller() {
        val packages = appContext.packageManager.getPackagesForUid(Binder.getCallingUid())
            .orEmpty()
        if (PLAYER_PACKAGE !in packages) {
            throw SecurityException("Only RAVEN23 Player may read this media library.")
        }
    }

    companion object {
        const val AUTHORITY = "com.m5ham3d.raven23.offline-library"
        private const val PLAYER_PACKAGE = "com.m5ham3ds.raven23.player"
    }
}
