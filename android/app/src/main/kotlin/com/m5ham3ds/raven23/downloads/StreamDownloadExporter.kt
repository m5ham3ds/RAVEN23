package com.m5ham3ds.raven23.downloads

import android.content.Context
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.text.format.Formatter
import android.util.Log
import androidx.media3.common.Format
import androidx.media3.common.util.Clock
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSourceBitmapLoader
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.transformer.AssetLoader
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultAssetLoaderFactory
import androidx.media3.transformer.DefaultDecoderFactory
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.InAppMp4Muxer
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import java.io.File
import java.io.IOException
import java.util.Locale
import java.util.concurrent.CancellationException

internal const val OFFLINE_EXPORT_TIMEOUT_MS = 30L * 60L * 1000L

internal fun isOfflineExportTimedOut(
    startedAtMs: Long,
    nowMs: Long,
    timeoutMs: Long,
): Boolean =
    timeoutMs > 0L &&
        nowMs >= startedAtMs &&
        nowMs - startedAtMs >= timeoutMs

internal fun isOfflineExportDurationComplete(
    actualDurationMs: Long,
    expectedDurationMs: Long,
): Boolean {
    // A readable container cannot prove completeness without a trusted runtime.
    if (actualDurationMs <= 0L || expectedDurationMs <= 0L) return false
    val minimumDurationMs = maxOf(
        (expectedDurationMs * 0.90).toLong(),
        expectedDurationMs - 2L * 60L * 1000L,
    )
    return actualDurationMs >= minimumDurationMs
}

internal fun isOfflineExportTrackSetComplete(
    hasVideo: Boolean,
    hasAudio: Boolean,
): Boolean = hasVideo && hasAudio

@UnstableApi
class StreamDownloadExporter(
    context: Context,
    private val store: StreamDownloadStore,
) {
    private val appContext = context.applicationContext
    // Exported files are user-visible artifacts and must survive app restarts
    // and Android cache cleanup. The download cache itself remains private,
    // while this directory keeps completed conversion work reusable.
    private val exportDirectory = File(appContext.filesDir, "offline_exports")
    private var activeExportId: String? = null
    private var activeTransformer: Transformer? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val callbacks = mutableListOf<(Result<File>) -> Unit>()
    private var exportStartedAtMs = 0L
    private var exportTimeoutRunnable: Runnable? = null

    fun export(downloadId: String, callback: (Result<File>) -> Unit) {
        val download = store.getDownload(downloadId)
        if (download == null || download.state != Download.STATE_COMPLETED) {
            callback(Result.failure(IllegalStateException("The download must finish before it can be exported.")))
            return
        }

        val output = outputFile(download)
        val marker = validationMarker(output)
        val hasCurrentMarker = runCatching {
            marker.isFile && marker.readText().trim() == EXPORT_VALIDATION_VERSION
        }.getOrDefault(false)
        // Exports produced before the validation marker existed are discarded
        // and regenerated from the completed Media3 cache, rather than trusting
        // an old short MP4 merely because the container can be opened.
        if (output.isFile && hasCurrentMarker && isValidExport(download, output)) {
            callback(Result.success(output))
            return
        }
        if (activeExportId == downloadId) {
            callbacks.add(callback)
            return
        }
        if (output.exists()) output.delete()
        marker.delete()
        val temporary = temporaryFile(output)
        temporary.delete()
        if (activeExportId != null) {
            callback(Result.failure(IllegalStateException("Another video is already being prepared.")))
            return
        }
        if (!exportDirectory.exists() && !exportDirectory.mkdirs()) {
            callback(Result.failure(IllegalStateException("Could not create the video export directory.")))
            return
        }

        if (!hasSpaceFor(download)) {
            callback(Result.failure(notEnoughStorage(download, cause = null)))
            return
        }

        activeExportId = downloadId
        callbacks.add(callback)
        exportStartedAtMs = SystemClock.elapsedRealtime()
        scheduleExportTimeout(downloadId, temporary)
        startTransformer(download, temporary, output, inAppMuxer = false)
    }

    /**
     * Remuxes [download] into [output]. Android's MediaMuxer rejects some
     * HLS/DASH sample streams (it fails while writing or finalising the file),
     * so a muxing failure is retried once with Media3's own MP4 muxer.
     */
    private fun startTransformer(
        download: Download,
        temporary: File,
        output: File,
        inAppMuxer: Boolean,
    ) {
        val downloadId = download.request.id
        val mediaSourceFactory = DefaultMediaSourceFactory(store.readOnlyCacheFactory(download.request))
        val assetLoaderFactory = DefaultAssetLoaderFactory(
            appContext,
            DefaultDecoderFactory.Builder(appContext).build(),
            Clock.DEFAULT,
            mediaSourceFactory,
            DataSourceBitmapLoader(appContext),
        )
        val listener = object : Transformer.Listener {
            override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                if (activeExportId != downloadId) return
                val validationError = validateExport(download, temporary)
                if (validationError != null) {
                    temporary.delete()
                    finish(Result.failure(validationError))
                    return
                }
                if (output.exists() && !output.delete()) {
                    temporary.delete()
                    finish(Result.failure(IOException("Could not replace the previous offline video.")))
                    return
                }
                if (!temporary.renameTo(output)) {
                    temporary.delete()
                    finish(Result.failure(IOException("Could not finalize the offline video file.")))
                    return
                }
                // A missing marker forces one safe regeneration on the next
                // app version instead of silently reusing an older export.
                runCatching { validationMarker(output).writeText(EXPORT_VALIDATION_VERSION) }
                finish(Result.success(output))
            }

            override fun onError(
                composition: Composition,
                exportResult: ExportResult,
                exportException: ExportException,
            ) {
                if (activeExportId != downloadId) return
                temporary.delete()
                Log.e(
                    TAG,
                    "Export of $downloadId failed with the " +
                        "${if (inAppMuxer) "in-app" else "framework"} muxer " +
                        "(${exportException.errorCodeName})",
                    exportException,
                )
                if (!inAppMuxer && exportException.isMuxingError() && hasSpaceFor(download)) {
                    // Start the retry outside the failed Transformer's callback.
                    mainHandler.post {
                        if (activeExportId == downloadId) {
                            startTransformer(download, temporary, output, inAppMuxer = true)
                        }
                    }
                    return
                }
                finish(Result.failure(describeFailure(download, exportException)))
            }
        }
        try {
            activeTransformer = Transformer.Builder(appContext)
                .setAssetLoaderFactory(
                    SquarePixelAspectAssetLoaderFactory(assetLoaderFactory),
                )
                .apply { if (inAppMuxer) setMuxerFactory(InAppMp4Muxer.Factory()) }
                .addListener(listener)
                .build()
                .also { it.start(download.request.toMediaItem(), temporary.absolutePath) }
        } catch (error: Exception) {
            temporary.delete()
            if (activeExportId == downloadId) {
                finish(Result.failure(describeFailure(download, error)))
            }
        }
    }

    private fun scheduleExportTimeout(downloadId: String, temporary: File) {
        val timeout = Runnable {
            if (activeExportId != downloadId) return@Runnable
            if (!isOfflineExportTimedOut(
                    exportStartedAtMs,
                    SystemClock.elapsedRealtime(),
                    OFFLINE_EXPORT_TIMEOUT_MS,
                )
            ) {
                return@Runnable
            }
            val transformer = activeTransformer
            temporary.delete()
            finish(
                Result.failure(
                    StreamDownloadExportException(
                        code = "EXPORT_TIMEOUT",
                        message = "Preparing this downloaded video took too long. " +
                            "The original download is still saved; try again.",
                        cause = null,
                    ),
                ),
            )
            transformer?.cancel()
        }
        exportTimeoutRunnable = timeout
        mainHandler.postDelayed(timeout, OFFLINE_EXPORT_TIMEOUT_MS)
    }

    fun deleteExport(downloadId: String) {
        if (activeExportId == downloadId) {
            activeTransformer?.cancel()
            finish(Result.failure(CancellationException("Video export was cancelled.")))
        }
        val suffix = "-${Integer.toHexString(downloadId.hashCode())}.mp4"
        exportDirectory.listFiles()
            ?.filter {
                it.name.endsWith(suffix) ||
                    it.name.endsWith(suffix.removeSuffix(".mp4") + ".part.mp4") ||
                    it.name.endsWith("$suffix.validated")
            }
            ?.forEach(File::delete)
    }

    /** Returns the remuxer's real progress when the current export exposes it. */
    fun progress(downloadId: String): Map<String, Any?> {
        if (activeExportId != downloadId) {
            return mapOf("state" to "idle", "progress" to null)
        }
        val transformer = activeTransformer
            ?: return mapOf("state" to "starting", "progress" to null)
        val holder = ProgressHolder()
        return when (transformer.getProgress(holder)) {
            Transformer.PROGRESS_STATE_AVAILABLE -> mapOf(
                "state" to "available",
                "progress" to holder.progress,
            )
            Transformer.PROGRESS_STATE_WAITING_FOR_AVAILABILITY ->
                mapOf("state" to "starting", "progress" to null)
            Transformer.PROGRESS_STATE_UNAVAILABLE ->
                mapOf("state" to "unavailable", "progress" to null)
            else -> mapOf("state" to "starting", "progress" to null)
        }
    }

    private fun finish(result: Result<File>) {
        exportTimeoutRunnable?.let(mainHandler::removeCallbacks)
        exportTimeoutRunnable = null
        exportStartedAtMs = 0L
        val completedCallbacks = callbacks.toList()
        callbacks.clear()
        activeTransformer = null
        activeExportId = null
        completedCallbacks.forEach { it(result) }
    }

    /** The remuxed MP4 is about the size of the cached segments, plus headroom. */
    private fun requiredBytes(download: Download): Long =
        download.bytesDownloaded + EXPORT_HEADROOM_BYTES

    private fun hasSpaceFor(download: Download): Boolean =
        exportDirectory.usableSpace >= requiredBytes(download)

    private fun notEnoughStorage(download: Download, cause: Throwable?): Exception {
        val shortfall = (requiredBytes(download) - exportDirectory.usableSpace)
            .coerceAtLeast(EXPORT_HEADROOM_BYTES)
        return StreamDownloadExportException(
            code = "EXPORT_NO_SPACE",
            message = "There isn't enough free storage to prepare this video. " +
                "Free up about ${Formatter.formatShortFileSize(appContext, shortfall)} " +
                "and try again.",
            cause = cause,
        )
    }

    private fun describeFailure(download: Download, error: Throwable): Exception {
        val outOfSpace = error.causes().any {
            val message = it.message.orEmpty()
            message.contains("ENOSPC") || message.contains("No space left", ignoreCase = true)
        }
        if (outOfSpace) return notEnoughStorage(download, error)
        if (error is ExportException && error.isMuxingError()) {
            return StreamDownloadExportException(
                code = "EXPORT_UNSUPPORTED",
                message = "This video can't be converted for other players. " +
                    "You can still watch it in RAVEN23.",
                cause = error,
            )
        }
        return StreamDownloadExportException(
            code = "EXPORT_FAILED",
            message = "Could not prepare this video. You can still watch it in RAVEN23.",
            cause = error,
        )
    }

    private fun ExportException.isMuxingError(): Boolean =
        errorCode == ExportException.ERROR_CODE_MUXING_FAILED ||
            errorCode == ExportException.ERROR_CODE_MUXING_TIMEOUT

    private fun temporaryFile(output: File): File =
        File(output.parentFile, output.name.removeSuffix(".mp4") + ".part.mp4")

    private fun validationMarker(output: File): File =
        File(output.parentFile, output.name + ".validated")

    private fun validateExport(download: Download, file: File): Exception? {
        if (isValidExport(download, file)) return null
        val expectedMs = StreamDownloadStore.requestMetadata(download.request)
            .optLong("expectedDurationMs", 0L)
        val message = if (expectedMs > 0L) {
            "The offline video is incomplete. Expected about ${expectedMs / 60000L} minutes; " +
                "the exported file is shorter or unreadable. Retry the download before playing it."
        } else {
            "This saved download has no trusted source duration, so RAVEN23 cannot verify that it is complete. " +
                "Refresh the title details and download it again before offline playback."
        }
        return StreamDownloadExportException("EXPORT_INCOMPLETE", message, null)
    }

    private fun isValidExport(download: Download, file: File): Boolean {
        if (!file.isFile || file.length() < MIN_VALID_MP4_BYTES) return false
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.absolutePath)
            val durationMs = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION,
            )?.toLongOrNull() ?: return false
            val width = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH,
            )?.toIntOrNull() ?: 0
            val height = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT,
            )?.toIntOrNull() ?: 0
            val hasVideo = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO,
            ) == "yes"
            val hasAudio = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO,
            ) == "yes"
            if (
                durationMs <= 0L ||
                width <= 0 ||
                height <= 0 ||
                !isOfflineExportTrackSetComplete(hasVideo, hasAudio)
            ) {
                false
            } else {
                val expectedMs = StreamDownloadStore.requestMetadata(download.request)
                    .optLong("expectedDurationMs", 0L)
                isOfflineExportDurationComplete(durationMs, expectedMs)
            }
        } catch (_: Exception) {
            false
        } finally {
            runCatching { retriever.release() }
        }
    }

    private fun outputFile(download: Download): File {
        val metadata = StreamDownloadStore.requestMetadata(download.request)
        val rawTitle = metadata.optString("title", "RAVEN23 video")
            .trim()
            .ifBlank { "RAVEN23 video" }
        val title = rawTitle
            .replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"), "_")
            .replace(Regex("\\s+"), " ")
            .trim(' ', '.')
            .take(96)
            .ifBlank { "RAVEN23 video" }
        val suffix = Integer.toHexString(download.request.id.hashCode())
        return File(exportDirectory, "$title-$suffix.mp4")
    }

    /** Reuses a validated MP4 when available, otherwise creates one from the
     * completed Media3 cache. This is the only path that needs a remux. */
    fun exportValidated(downloadId: String, callback: (Result<File>) -> Unit) =
        export(downloadId, callback)

    fun existingExport(downloadId: String): File? {
        val download = store.getDownload(downloadId) ?: return null
        if (download.state != Download.STATE_COMPLETED) return null
        val output = outputFile(download)
        val marker = validationMarker(output)
        val validMarker = runCatching {
            marker.isFile && marker.readText().trim() == EXPORT_VALIDATION_VERSION
        }.getOrDefault(false)
        return output.takeIf { validMarker && isValidExport(download, it) }
    }
    private companion object {
        const val TAG = "StreamDownloadExporter"
        const val EXPORT_HEADROOM_BYTES = 64L * 1024 * 1024
        const val MIN_VALID_MP4_BYTES = 16L * 1024
        const val EXPORT_VALIDATION_VERSION = "2"
    }
}

/** An export failure carrying the method-channel error code Dart receives. */
class StreamDownloadExportException(
    val code: String,
    message: String,
    cause: Throwable?,
) : Exception(message, cause)

/** This throwable and its causes, outermost first. */
internal fun Throwable.causes(): Sequence<Throwable> =
    generateSequence(this) { it.cause?.takeIf { cause -> cause !== it } }.take(8)

/**
 * Some HLS/DASH manifests report a negligible non-square pixel ratio (for
 * example 1.001565). Transformer then needlessly decodes and re-encodes an
 * otherwise MP4-compatible stream. Normalizing that metadata keeps exports on
 * the encoded remux path and avoids a codec surface altogether.
 */
@UnstableApi
private class SquarePixelAspectAssetLoaderFactory(
    private val delegate: AssetLoader.Factory,
) : AssetLoader.Factory {
    override fun createAssetLoader(
        editedMediaItem: androidx.media3.transformer.EditedMediaItem,
        looper: Looper,
        listener: AssetLoader.Listener,
        compositionSettings: AssetLoader.CompositionSettings,
    ): AssetLoader {
        return delegate.createAssetLoader(
            editedMediaItem,
            looper,
            object : AssetLoader.Listener {
                override fun onDurationUs(durationUs: Long) = listener.onDurationUs(durationUs)

                override fun onTrackCount(trackCount: Int) = listener.onTrackCount(trackCount)

                override fun onTrackAdded(
                    inputFormat: Format,
                    supportedOutputTypes: Int,
                ): Boolean = listener.onTrackAdded(
                    normalizePixelAspect(inputFormat),
                    supportedOutputTypes,
                )

                override fun onOutputFormat(
                    format: Format,
                ): androidx.media3.transformer.SampleConsumer? =
                    listener.onOutputFormat(normalizePixelAspect(format))

                override fun onError(exportException: ExportException) =
                    listener.onError(exportException)
            },
            compositionSettings,
        )
    }

    private fun normalizePixelAspect(format: Format): Format {
        val ratio = format.pixelWidthHeightRatio
        return if (ratio.isFinite() && kotlin.math.abs(ratio - 1f) < 0.01f) {
            format.buildUpon().setPixelWidthHeightRatio(1f).build()
        } else {
            format
        }
    }
}
