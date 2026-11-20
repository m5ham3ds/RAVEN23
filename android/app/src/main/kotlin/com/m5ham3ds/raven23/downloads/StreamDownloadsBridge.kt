package com.m5ham3ds.raven23.downloads

import android.app.Activity
import android.content.ContentValues
import android.content.ClipData
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.core.content.FileProvider
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadService
import androidx.media3.transformer.ExportException
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.Locale
import java.util.concurrent.Executors

@UnstableApi
class StreamDownloadsBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
    DownloadManager.Listener {
    private val appContext = activity.applicationContext
    val store: StreamDownloadStore = StreamDownloadStore.get(appContext)
    private val exporter = StreamDownloadExporter(appContext, store)
    private val fileExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var polling = false
    private var pendingSave: PendingSave? = null
    private val pendingEnqueues = mutableMapOf<String, Any>()

    init {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
        store.downloadManager.addListener(this)
        DownloadService.start(appContext, StreamDownloadService::class.java)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDownloads" -> runResult(result) { downloadMaps() }
            "getStorageSnapshot" -> runResult(result) {
                mapOf("availableBytes" to appContext.filesDir.usableSpace, "totalBytes" to appContext.filesDir.totalSpace)
            }
            "getAudioTracks" -> {
                val arguments = call.arguments as? Map<*, *>
                if (arguments == null) {
                    result.error("INVALID_ARGUMENTS", "Stream arguments are required.", null)
                } else {
                    store.getAudioTracks(arguments) { tracks ->
                        mainHandler.post {
                            tracks.fold(
                                onSuccess = { result.success(it) },
                                onFailure = { result.error("PREPARE_FAILED", it.message, null) },
                            )
                        }
                    }
                }
            }
            "enqueue" -> enqueue(call, result)
            "pause" -> withId(call, result) { id ->
                DownloadService.sendSetStopReason(
                    appContext,
                    StreamDownloadService::class.java,
                    id,
                    USER_PAUSED,
                    false,
                )
            }
            "resume" -> resumeDownload(call, result)
            "retry" -> retryDownload(call, result)
            "getExportProgress" -> exportProgress(call, result)
            "prepareForPlayback" -> withExportedFile(call, result) { file ->
                result.success(file.absolutePath)
            }
            "openExternal" -> exportForExternalPlayer(call, result)
            "saveCopy" -> saveIntoRaven23Folder(call, result)
            "remove" -> withId(call, result) { id ->
                pendingEnqueues.remove(id)
                exporter.deleteExport(id)
                store.deleteSubtitle(id)
                DownloadService.sendRemoveDownload(
                    appContext,
                    StreamDownloadService::class.java,
                    id,
                    false,
                )
            }
            else -> result.notImplemented()
        }
    }

    // Retained for MainActivity compatibility; RAVEN23 export no longer launches a picker.
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean = false

    /** Saves a validated MP4 directly into the public Documents/RAVEN23 tree. */
    private fun saveIntoRaven23Folder(call: MethodCall, result: MethodChannel.Result) {
        val downloadId = call.argument<String>("id")
        if (downloadId.isNullOrBlank()) {
            result.error("INVALID_ID", "A download id is required.", null)
            return
        }
        val download = store.getDownload(downloadId)
        if (download == null || download.state != Download.STATE_COMPLETED) {
            result.error("DOWNLOAD_NOT_COMPLETE", "Wait until this download finishes before saving it.", null)
            return
        }
        fileExecutor.execute {
            var videoTemp: File? = null
            try {
                val metadata = StreamDownloadStore.requestMetadata(download.request)
                val isMovie = metadata.optString("mediaType").equals("movie", true)
                val rawTitle = metadata.optString("exportTitle")
                    .ifBlank { metadata.optString("title", "RAVEN23 video") }
                val baseStem = sanitizeOfflineExportTitle(rawTitle)
                val fileStem = buildOfflineExportStem(
                    baseStem,
                    isMovie,
                    metadata.optInt("seasonNumber", -1),
                    metadata.optInt("episodeNumber", -1),
                    metadata.optString("subtitle"),
                )
                val videoFolder = if (isMovie) "RAVEN23/MOVIES" else "RAVEN23/$baseStem"
                videoTemp = File(appContext.cacheDir, "raven23-export-$downloadId.mp4")
                videoTemp.delete()
                val directCopy = store.copyCompletedProgressiveMp4To(download, videoTemp)
                val videoSource = if (directCopy) {
                    videoTemp
                } else {
                    exporter.existingExport(downloadId)
                        ?: throw IllegalStateException(
                            "This source needs MP4 preparation before it can be saved as one file. " +
                                "Try Open with another player first, then save again.",
                        )
                }
                val videoUri = savePublicFile(videoSource, fileStem, "video/mp4", videoFolder)
                val subtitle = store.subtitleFileForExport(downloadId)
                val subtitleUri = subtitle?.let {
                    val subtitleFolder = if (isMovie) {
                        "RAVEN23/MOVIES/SUBTITLE"
                    } else {
                        "RAVEN23/$baseStem/SUBTITLE"
                    }
                    val mime = if (it.extension.equals("srt", true)) {
                        "application/x-subrip"
                    } else {
                        "text/vtt"
                    }
                    savePublicFile(
                        it,
                        fileStem,
                        mime,
                        subtitleFolder,
                        it.extension.lowercase(Locale.ROOT),
                    )
                }
                mainHandler.post {
                    result.success(
                        mapOf(
                            "saved" to true,
                            "videoUri" to videoUri,
                            "subtitleSaved" to (subtitleUri != null),
                            "subtitleUri" to subtitleUri,
                            "copiedDirectlyFromCache" to directCopy,
                        ),
                    )
                }
            } catch (error: Exception) {
                mainHandler.post { result.error("SAVE_COPY_FAILED", error.message, null) }
            } finally {
                videoTemp?.delete()
            }
        }
    }

    internal fun buildOfflineExportStem(
        title: String,
        isMovie: Boolean,
        season: Int,
        episode: Int,
        episodeLabel: String = "",
    ): String {
        val seasonEpisode = if (season >= 0 && episode >= 0) {
            "S${season.toString().padStart(2, '0')}E${episode.toString().padStart(2, '0')}"
        } else {
            ""
        }
        if (isMovie || seasonEpisode.isEmpty()) return title
        val label = episodeLabel
            .substringAfter(" • ", "")
            .substringBefore(" • ")
            .trim()
            .takeIf { it.isNotEmpty() && !it.startsWith("From ", true) }
        return listOf(title, seasonEpisode, label)
            .filterNotNull()
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString(" - ")
    }

    internal fun sanitizeOfflineExportTitle(value: String): String =
        value.trim()
            .replace(Regex("[\\\\/:*?\\\"<>|\\\\p{Cntrl}]"), "_")
            .replace(Regex("\\\\s+"), " ")
            .trim(' ', '.')
            .take(120)
            .ifBlank { "RAVEN23 video" }

    private fun savePublicFile(
        source: File,
        stem: String,
        mimeType: String,
        relativeFolder: String,
        extensionOverride: String? = null,
    ): String {
        val extension = extensionOverride ?: if (mimeType == "video/mp4") "mp4" else "vtt"
        val fileName = "$stem.$extension"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = if (mimeType.startsWith("video/")) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val resolver = appContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, "Documents/$relativeFolder")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("Could not create Documents/$relativeFolder/$fileName")
            try {
                val output = resolver.openOutputStream(uri, "w")
                    ?: throw IllegalStateException("Could not open $fileName for writing")
                source.inputStream().use { input -> output.use { input.copyTo(it, COPY_BUFFER_BYTES) } }
                val ready = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                resolver.update(uri, ready, null, null)
            } catch (error: Exception) {
                resolver.delete(uri, null, null)
                throw error
            }
            return uri.toString()
        }
        @Suppress("DEPRECATION")
        val documents = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
        val directory = File(documents, relativeFolder)
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("Could not create Documents/$relativeFolder")
        }
        val destination = File(directory, fileName)
        source.inputStream().use { input ->
            FileOutputStream(destination).use { output -> input.copyTo(output, COPY_BUFFER_BYTES) }
        }
        return destination.absolutePath
    }

    /** Reuses an already validated remux; only legacy/unprepared streams need conversion. */
    private fun withValidatedExport(
        call: MethodCall,
        result: MethodChannel.Result,
        operation: (File) -> Unit,
    ) {
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.error("INVALID_ID", "A download id is required.", null)
            return
        }
        val existing = exporter.existingExport(id)
        if (existing != null) {
            try { operation(existing) } catch (error: Exception) {
                result.error("EXPORT_ACTION_FAILED", error.message, null)
            }
            return
        }
        exporter.exportValidated(id) { exported ->
            mainHandler.post {
                exported.fold(
                    onSuccess = { file -> try { operation(file) } catch (error: Exception) {
                        result.error("EXPORT_ACTION_FAILED", error.message, null)
                    } },
                    onFailure = { error -> result.error(
                        (error as? StreamDownloadExportException)?.code ?: "EXPORT_FAILED",
                        error.message,
                        causeSummary(error),
                    ) },
                )
            }
        }
    }

    private fun exportForExternalPlayer(call: MethodCall, result: MethodChannel.Result) {
        withExportedFile(call, result) { file ->
            val uri = FileProvider.getUriForFile(
                appContext,
                "${appContext.packageName}.offline_files",
                file,
            )
            val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "video/mp4")
                clipData = ClipData.newRawUri("Offline video", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            check(viewIntent.resolveActivity(activity.packageManager) != null) {
                "No installed application can open this video."
            }
            activity.startActivity(Intent.createChooser(viewIntent, "Open video with"))
            result.success(null)
        }
    }

    private fun exportProgress(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.error("INVALID_ID", "A download id is required.", null)
            return
        }
        runResult(result) { exporter.progress(id) }
    }

    private fun exportForDocument(call: MethodCall, result: MethodChannel.Result) {
        if (pendingSave != null) {
            result.error("SAVE_IN_PROGRESS", "A save location is already being selected.", null)
            return
        }
        withExportedFile(call, result) { file ->
            pendingSave = PendingSave(file, result)
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "video/mp4"
                putExtra(Intent.EXTRA_TITLE, file.name)
            }
            try {
                activity.startActivityForResult(intent, SAVE_COPY_REQUEST)
            } catch (error: Exception) {
                pendingSave = null
                result.error("FILE_PICKER_UNAVAILABLE", error.message, null)
            }
        }
    }

    private fun withExportedFile(
        call: MethodCall,
        result: MethodChannel.Result,
        operation: (File) -> Unit,
    ) {
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.error("INVALID_ID", "A download id is required.", null)
            return
        }
        exporter.export(id) { exported ->
            mainHandler.post {
                exported.fold(
                    onSuccess = { file ->
                        try {
                            operation(file)
                        } catch (error: Exception) {
                            result.error("EXPORT_ACTION_FAILED", error.message, null)
                        }
                    },
                    onFailure = { error ->
                        result.error(
                            (error as? StreamDownloadExportException)?.code ?: "EXPORT_FAILED",
                            error.message,
                            causeSummary(error),
                        )
                    },
                )
            }
        }
    }

    private fun enqueue(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *> ?: run {
            result.error("INVALID_ARGUMENTS", "Download arguments are required.", null)
            return
        }
        val id = arguments["id"] as? String
        val existing = id?.takeIf { it.isNotBlank() }?.let(store::getDownload)
        if (existing?.state == Download.STATE_COMPLETED) {
            result.error("ALREADY_DOWNLOADED", "This title is already downloaded.", null)
            return
        }
        if (id.isNullOrBlank()) {
            result.error("INVALID_ID", "A download id is required.", null)
            return
        }
        if (pendingEnqueues.containsKey(id)) {
            result.error("ENQUEUE_IN_PROGRESS", "This download is already being prepared.", null)
            return
        }
        if (existing != null) {
            val stored = StreamDownloadStore.requestMetadata(existing.request)
            val storedTrack = stored.optJSONObject("audioTrack")?.let(DownloadSourceResolver::jsonMap)
            if (storedTrack != arguments["audioTrack"]) {
                result.error("DOWNLOAD_AUDIO_CONFLICT", "Remove the existing download before changing its audio.", null)
                return
            }
            val source = arguments["source"] as? Map<*, *>
            val oldSource = stored.optJSONObject("source")
            val sameSource = if (source != null && oldSource != null) {
                listOf("providerId", "server", "quality", "apiBaseUrl").all {
                    oldSource.optString(it) == source[it]?.toString().orEmpty()
                }
            } else source == null && oldSource == null && existing.request.uri.toString() == arguments["url"]
            if (!sameSource || stored.optString("quality") != arguments["quality"] || stored.optString("format") != arguments["format"]) {
                result.error("DOWNLOAD_SOURCE_CONFLICT", "This title already has a different download source or quality.", null)
                return
            }
            // Resume the original Media3 job. Never merge stream keys from a
            // refreshed manifest, or overwrite its recovery/cache history.
            val existingEstimate = stored.optLong("estimatedDownloadBytes").takeIf { it > 0L }
            val available = appContext.filesDir.usableSpace
            if (!hasEnoughStorageToResume(available, existingEstimate, existing.bytesDownloaded)) {
                result.error("STORAGE_LOW", storageMessage(available, existingEstimate, existing.bytesDownloaded), null)
                return
            }
            runResult(result) {
                DownloadService.sendAddDownload(appContext, StreamDownloadService::class.java,
                    checkNotNull(store.originalRequest(id)), true)
                null
            }
            return
        }
        val requestedEstimate = (arguments["estimatedDownloadBytes"] as? Number)?.toLong()
        val availableBeforePrepare = appContext.filesDir.usableSpace
        if (!hasEnoughStorageToStart(availableBeforePrepare, requestedEstimate)) {
            result.error(
                "STORAGE_LOW",
                storageMessage(availableBeforePrepare, requestedEstimate),
                null,
            )
            return
        }
        val token = Any()
        pendingEnqueues[id] = token
        store.prepareRequest(arguments) { prepared ->
            mainHandler.post {
                if (pendingEnqueues[id] !== token) {
                    result.error("ENQUEUE_CANCELLED", "The download was removed while preparing.", null)
                    return@post
                }
                pendingEnqueues.remove(id)
                prepared.fold(
                    onSuccess = { request ->
                        try {
                            val metadata = StreamDownloadStore.requestMetadata(request)
                            val estimate = metadata.optLong("estimatedDownloadBytes").takeIf { it > 0L }
                            val available = appContext.filesDir.usableSpace
                            if (!hasEnoughStorageToStart(available, estimate)) {
                                result.error("STORAGE_LOW", storageMessage(available, estimate), null)
                                return@fold
                            }
                            DownloadService.sendAddDownload(
                                appContext,
                                StreamDownloadService::class.java,
                                request,
                                true,
                            )
                            result.success(null)
                            emitDownloads()
                        } catch (error: Exception) {
                            result.error("ENQUEUE_FAILED", error.message, null)
                        }
                    },
                    onFailure = { error ->
                        result.error("PREPARE_FAILED", error.message, null)
                    },
                )
            }
        }
    }

    private fun resumeDownload(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.error("INVALID_ID", "A download id is required.", null)
            return
        }
        val download = store.getDownload(id)
        if (download == null) {
            result.error("DOWNLOAD_ERROR", "Download not found: $id", null)
            return
        }
        val metadata = StreamDownloadStore.requestMetadata(download.request)
        val estimate = metadata.optLong("estimatedDownloadBytes").takeIf { it > 0L }
        val available = appContext.filesDir.usableSpace
        if (!hasEnoughStorageToResume(available, estimate, download.bytesDownloaded)) {
            result.error("STORAGE_LOW", storageMessage(available, estimate, download.bytesDownloaded), null)
            return
        }
        runResult(result) {
            DownloadService.sendSetStopReason(
                appContext,
                StreamDownloadService::class.java,
                id,
                Download.STOP_REASON_NONE,
                false,
            )
            null
        }
    }

    private fun retryDownload(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.error("INVALID_ID", "A download id is required.", null)
            return
        }
        val download = store.getDownload(id)
        val request = store.originalRequest(id)
        if (download == null || request == null) {
            result.error("DOWNLOAD_ERROR", "Download not found: $id", null)
            return
        }
        val metadata = StreamDownloadStore.requestMetadata(request)
        val estimate = metadata.optLong("estimatedDownloadBytes").takeIf { it > 0L }
        val available = appContext.filesDir.usableSpace
        if (!hasEnoughStorageToResume(available, estimate, download.bytesDownloaded)) {
            result.error("STORAGE_LOW", storageMessage(available, estimate, download.bytesDownloaded), null)
            return
        }
        runResult(result) {
            DownloadService.sendAddDownload(
                appContext,
                StreamDownloadService::class.java,
                request,
                true,
            )
            null
        }
    }

    private fun storageMessage(
        available: Long,
        estimate: Long?,
        alreadyDownloaded: Long = 0L,
    ): String {
        val remainingEstimate = estimate?.let {
            (it - alreadyDownloaded.coerceAtLeast(0L)).coerceAtLeast(0L)
        } ?: 0L
        val required = OFFLINE_STORAGE_RESERVE_BYTES + remainingEstimate
        val shortfall = (required - available).coerceAtLeast(1L)
        return "Not enough free storage. Available: " +
            android.text.format.Formatter.formatShortFileSize(appContext, available) +
            "; required for the remaining download and the 200 MB safety reserve: " +
            android.text.format.Formatter.formatShortFileSize(appContext, required) +
            ". Free about " +
            android.text.format.Formatter.formatShortFileSize(appContext, shortfall) +
            " and tap Resume or Recheck."
    }

    private fun withId(
        call: MethodCall,
        result: MethodChannel.Result,
        operation: (String) -> Unit,
    ) {
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.error("INVALID_ID", "A download id is required.", null)
            return
        }
        runResult(result) {
            operation(id)
            null
        }
    }

    private fun runResult(result: MethodChannel.Result, operation: () -> Any?) {
        try {
            result.success(operation())
        } catch (error: Exception) {
            result.error("DOWNLOAD_ERROR", error.message, null)
        }
    }

    /** The cause chain, so error reports say why an export failed. */
    private fun causeSummary(error: Throwable): String? =
        error.causes().drop(1).joinToString(" <- ") { cause ->
            val code = (cause as? ExportException)?.let { "[${it.errorCodeName}]" }.orEmpty()
            "${cause.javaClass.simpleName}$code: ${cause.message}"
        }.ifEmpty { null }

    private fun downloadMaps(): List<Map<String, Any?>> =
        store.getDownloads().map(store::downloadToMap)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        emitDownloads()
        if (!polling) {
            polling = true
            mainHandler.post(progressPoller)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        polling = false
        mainHandler.removeCallbacks(progressPoller)
    }

    private val progressPoller = object : Runnable {
        override fun run() {
            if (!polling) return
            emitDownloads()
            mainHandler.postDelayed(this, 750L)
        }
    }

    private fun emitDownloads() {
        val sink = eventSink ?: return
        try {
            sink.success(downloadMaps())
        } catch (error: Exception) {
            sink.error("DOWNLOAD_QUERY_FAILED", error.message, null)
        }
    }

    override fun onInitialized(downloadManager: DownloadManager) = emitDownloads()

    override fun onDownloadChanged(
        downloadManager: DownloadManager,
        download: Download,
        finalException: Exception?,
    ) = emitDownloads()

    override fun onDownloadRemoved(downloadManager: DownloadManager, download: Download) =
        emitDownloads()

    companion object {
        private const val METHOD_CHANNEL = "com.m5ham3ds.raven23/stream_downloads"
        private const val EVENT_CHANNEL = "com.m5ham3ds.raven23/stream_download_events"
        private const val USER_PAUSED = 1
        private const val COPY_BUFFER_BYTES = 1024 * 1024
    }

    private data class PendingSave(
        val file: File,
        val result: MethodChannel.Result,
    )
}
