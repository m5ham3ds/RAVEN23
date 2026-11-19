package com.m5ham3ds.raven23.downloads

import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadHelper
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MessageCodec
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

@UnstableApi
class StreamOfflinePlayerFactory(
    private val store: StreamDownloadStore,
    private val messenger: BinaryMessenger,
    codec: MessageCodec<Any?> = StandardMessageCodec.INSTANCE,
) : PlatformViewFactory(codec) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val id = (args as? Map<*, *>)?.get("id") as? String
            ?: throw IllegalArgumentException("An offline download id is required.")
        return StreamOfflinePlayerView(context, id, viewId, store, messenger)
    }
}

@UnstableApi
private class StreamOfflinePlayerView(
    context: Context,
    downloadId: String,
    viewId: Int,
    store: StreamDownloadStore,
    messenger: BinaryMessenger,
) : PlatformView {
    private val eventChannel = EventChannel(
        messenger,
        "raven23/offline_player_events/$viewId",
    )
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private val playerView = PlayerView(context).apply {
        setBackgroundColor(Color.BLACK)
        setShowBuffering(PlayerView.SHOW_BUFFERING_ALWAYS)
        setUseController(true)
        setShowSubtitleButton(true)
        controllerShowTimeoutMs = 3_500
    }
    private val player = ExoPlayer.Builder(context).build().apply {
        setAudioAttributes(
            AudioAttributes.Builder()
                .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                .setUsage(C.USAGE_MEDIA)
                .build(),
            true,
        )
    }
    private val progressUpdates = object : Runnable {
        override fun run() {
            emit("progress")
            if (!released) mainHandler.postDelayed(this, 1_000L)
        }
    }
    private var released = false

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                Player.STATE_BUFFERING -> emit("buffering")
                Player.STATE_READY -> emit("ready")
                Player.STATE_ENDED -> emit("ended")
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            emit(if (isPlaying) "playing" else "paused")
        }

        override fun onPlayerError(error: PlaybackException) {
            emit("error", error.message ?: error.errorCodeName)
        }
    }

    init {
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                emit("snapshot")
                mainHandler.removeCallbacks(progressUpdates)
                mainHandler.post(progressUpdates)
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                mainHandler.removeCallbacks(progressUpdates)
            }
        })
        player.addListener(playerListener)
        try {
            val download = store.getDownload(downloadId)
                ?: throw IllegalArgumentException("Download not found: $downloadId")
            check(download.state == Download.STATE_COMPLETED) {
                "The download must complete before offline playback."
            }
            val mediaSource = DownloadHelper.createMediaSource(
                download.request,
                store.readOnlyCacheFactory(download.request),
            )
            playerView.player = player
            player.setMediaSource(mediaSource)
            player.prepare()
            player.playWhenReady = true
        } catch (error: Exception) {
            emit("error", error.message ?: "The downloaded video could not be opened.")
            throw error
        }
    }

    private fun emit(event: String, error: String? = null) {
        if (released) return
        val duration = player.duration.takeIf { it >= 0L } ?: 0L
        eventSink?.success(
            mapOf(
                "event" to event,
                "durationMs" to duration,
                "positionMs" to player.currentPosition.coerceAtLeast(0L),
                "isPlaying" to player.isPlaying,
                "error" to error,
            ),
        )
    }

    override fun getView(): View = playerView

    override fun onFlutterViewAttached(flutterView: View) {
        playerView.onResume()
    }

    override fun onFlutterViewDetached() {
        playerView.onPause()
    }

    override fun dispose() {
        if (released) return
        released = true
        mainHandler.removeCallbacks(progressUpdates)
        eventChannel.setStreamHandler(null)
        eventSink = null
        player.removeListener(playerListener)
        playerView.player = null
        player.release()
    }
}
