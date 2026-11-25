package com.m5ham3ds.raven23.downloads

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Binder
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.Executors
import org.json.JSONObject

/**
 * Read-only companion bridge for RAVEN23 Player.
 *
 * The Media3 download index remains the source of truth. Completed downloads
 * are exposed whether or not their validated MP4 export already exists. When
 * Player opens the returned video URI, an existing export is opened directly;
 * otherwise the existing RAVEN23 exporter prepares the MP4 from the private
 * Media3 cache and streams that same private export through a pipe.
 *
 * No download queue, cache namespace, download request, or primary-app UI is
 * changed by this provider. The only durable media remains RAVEN23's existing
 * private download/export data.
 */
@UnstableApi
class Raven23PlayerMediaProvider : ContentProvider() {
    private val appContext get() = checkNotNull(context).applicationContext
    private val store by lazy { StreamDownloadStore.get(appContext) }
    private val exporter by lazy { StreamDownloadExporter(appContext, store) }
    private val pipeExecutor by lazy {
        Executors.newCachedThreadPool { runnable ->
            Thread(runnable, "raven23-player-media-pipe").apply { isDaemon = true }
        }
    }

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
                val id = download.request.id
                val completed = download.state == Download.STATE_COMPLETED

                // An unexported completed Media3 item is still playable. The
                // exporter is invoked lazily only when Player opens this URI.
                val videoUri = if (completed) {
                    providerRoot.buildUpon().appendPath(id).appendPath("video").build()
                        .also(::grantPlayerRead)
                } else {
                    null
                }

                val subtitle = store.subtitleFileForExport(id, download.request)
                    ?.takeIf { it.isFile && it.length() > 0L }
                val subtitleUri = subtitle?.let {
                    providerRoot.buildUpon().appendPath(id).appendPath("subtitle").build()
                        .also(::grantPlayerRead)
                }

                val expectedDuration = metadata.optLong("expectedDurationMs", 0L)
                    .takeIf { it > 0L } ?: 0L
                val title = metadata.optString("title", "RAVEN23 video")
                    .trim().ifBlank { "RAVEN23 video" }

                downloadMap["isPlayable"] = videoUri != null
                downloadMap["videoUri"] = videoUri?.toString().orEmpty()
                downloadMap["subtitleUri"] = subtitleUri?.toString().orEmpty()
                downloadMap["subtitleName"] = subtitle?.name.orEmpty()
                downloadMap["durationMs"] = expectedDuration
                downloadMap["sizeBytes"] = download.bytesDownloaded

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
                        download.bytesDownloaded,
                        videoUri != null,
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
        return when (segments[2]) {
            "video" -> openVideo(id)
            "subtitle" -> {
                val download = store.getDownload(id)
                    ?: throw FileNotFoundException("RAVEN23 download no longer exists.")
                val file = store.subtitleFileForExport(id, download.request)
                    ?.takeIf { it.isFile && it.length() > 0L }
                    ?: throw FileNotFoundException("The downloaded subtitle is not available.")
                ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            }
            else -> throw FileNotFoundException("Unknown RAVEN23 media resource.")
        }
    }

    private fun openVideo(downloadId: String): ParcelFileDescriptor {
        val download = store.getDownload(downloadId)
            ?: throw FileNotFoundException("RAVEN23 download no longer exists.")
        if (download.state != Download.STATE_COMPLETED) {
            throw FileNotFoundException("The RAVEN23 download is not complete yet.")
        }

        exporter.existingExport(downloadId)?.let { export ->
            return ParcelFileDescriptor.open(export, ParcelFileDescriptor.MODE_READ_ONLY)
        }

        // Exporting HLS/DASH (or a progressive stream that has not yet been
        // materialized) can take time. Return a pipe immediately so the
        // ContentResolver/ExoPlayer reader never blocks the UI thread.
        val pipe = ParcelFileDescriptor.createPipe()
        try {
            exporter.export(downloadId) { outcome ->
                pipeExecutor.execute {
                    val output = ParcelFileDescriptor.AutoCloseOutputStream(pipe[1])
                    try {
                        val file = outcome.getOrThrow()
                        FileInputStream(file).use { input ->
                            input.copyTo(output, DEFAULT_PIPE_BUFFER_BYTES)
                            output.flush()
                        }
                    } catch (error: Exception) {
                        Log.w(TAG, "Could not prepare streamed offline download $downloadId", error)
                    } finally {
                        runCatching { output.close() }
                    }
                }
            }
        } catch (error: Exception) {
            runCatching { pipe[1].close() }
            runCatching { pipe[0].close() }
            throw FileNotFoundException(
                error.message ?: "Could not prepare this RAVEN23 download.",
            )
        }
        return pipe[0]
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
        private const val TAG = "Raven23PlayerMedia"
        private const val DEFAULT_PIPE_BUFFER_BYTES = 256 * 1024
    }
}
