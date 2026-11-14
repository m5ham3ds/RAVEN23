package com.m5ham3ds.raven23

import android.app.UiModeManager
import android.content.Context
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Bundle
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.KeyEvent
import android.webkit.WebView
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.m5ham3ds.raven23.downloads.StreamDownloadsBridge
import com.m5ham3ds.raven23.downloads.StreamOfflinePlayerFactory
import com.m5ham3ds.raven23.links.MediaLinkBridge
import com.m5ham3ds.raven23.ads.PlaybackAdInputBridge
import com.m5ham3ds.raven23.ads.PlaybackAdBrowserBridge
import com.m5ham3ds.raven23.playback.StreamingDndBridge
import com.m5ham3ds.raven23.streaming.OpenStreamWebEmbedBridge
import com.m5ham3ds.raven23.streaming.EmbeddedWebPlaybackViewFactory
import io.flutter.plugins.webviewflutter.WebViewFlutterPlugin
import com.m5ham3ds.raven23.mihon.MihonBridge
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

class MainActivity: FlutterActivity() {
    private var downloadsBridge: StreamDownloadsBridge? = null
    private var linkBridge: MediaLinkBridge? = null
    private var playbackAdInputBridge: PlaybackAdInputBridge? = null
    private var playbackAdBrowserBridge: PlaybackAdBrowserBridge? = null
    private var streamingDndBridge: StreamingDndBridge? = null
    private var openStreamWebEmbedBridge: OpenStreamWebEmbedBridge? = null
    private var mihonBridge: MihonBridge? = null
    private var mihonScope: CoroutineScope? = null
    private var mihonChannel: MethodChannel? = null
    private var mangaTranslationBridge: MangaTranslationBridge? = null
    private var mangaTranslationChannel: MethodChannel? = null
    private var mangaReaderComfortChannel: MethodChannel? = null
    private var mangaReaderVolumeChannel: MethodChannel? = null
    private var mangaVolumeKeyPaging = false

    // Starting an activity of our own (a file picker, an external player, a full-screen ad) also
    // reports the user as leaving, which would send a playing video into picture in picture.
    private var launchingOwnActivity = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        streamingDndBridge = StreamingDndBridge(this, flutterEngine.dartExecutor.binaryMessenger)

        // Mihon manga extensions are loaded lazily when Sources/Manga asks for them.
        // Keep their native work on an IO scope so extension constructors and network
        // calls never block Flutter's platform thread.
        mihonScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        mihonBridge = MihonBridge(this, mihonScope!!)
        mihonChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "raven23/mihon")
        mihonBridge!!.attach(mihonChannel!!)

        val translationBridge = MangaTranslationBridge(this)
        mangaTranslationBridge = translationBridge
        mangaTranslationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "raven23/manga_translation",
        ).also { it.setMethodCallHandler(translationBridge) }

        mangaReaderComfortChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "raven23/reader_comfort",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setBrightness" -> {
                        val value = call.argument<Number>("value")?.toFloat()
                        if (value == null || !value.isFinite() || value > 1f) {
                            result.error("invalid_brightness", "Brightness must be -1 or between 0 and 1.", null)
                        } else {
                            val attributes = window.attributes
                            attributes.screenBrightness = if (value < 0f) {
                                android.view.WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                            } else {
                                value.coerceIn(0.05f, 1f)
                            }
                            window.attributes = attributes
                            result.success(null)
                        }
                    }
                    "saveImageToGallery" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("empty_image", "No image bytes were supplied.", null)
                        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            result.error("unsupported_android", "Gallery saving requires Android 10 or newer.", null)
                        } else {
                            val resolver = contentResolver
                            var imageUri: Uri? = null
                            try {
                                val name = call.argument<String>("name")?.takeIf { it.isNotBlank() }
                                    ?: "RAVEN23_Manga_Page_${System.currentTimeMillis()}"
                                val mimeType = call.argument<String>("mimeType")?.takeIf { it.startsWith("image/") }
                                    ?: "image/jpeg"
                                val values = ContentValues().apply {
                                    put(MediaStore.Images.Media.DISPLAY_NAME, "$name.${mimeType.substringAfter('/')}")
                                    put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                                    put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/RAVEN23")
                                    put(MediaStore.Images.Media.IS_PENDING, 1)
                                }
                                imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                                val createdUri = imageUri
                                if (createdUri == null) {
                                    result.error("gallery_insert_failed", "Could not create a gallery image.", null)
                                } else {
                                    val wrote = resolver.openOutputStream(createdUri)?.use { stream ->
                                        stream.write(bytes)
                                        true
                                    } ?: false
                                    if (wrote) {
                                        val ready = ContentValues().apply {
                                            put(MediaStore.Images.Media.IS_PENDING, 0)
                                        }
                                        resolver.update(createdUri, ready, null, null)
                                        result.success(createdUri.toString())
                                    } else {
                                        resolver.delete(createdUri, null, null)
                                        result.error("gallery_write_failed", "Could not write the image to the gallery.", null)
                                    }
                                }
                            } catch (error: Exception) {
                                imageUri?.let { resolver.delete(it, null, null) }
                                result.error("gallery_save_failed", error.message ?: "Could not save image.", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        mangaReaderVolumeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "raven23/reader_volume_keys",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        mangaVolumeKeyPaging = call.argument<Boolean>("enabled") == true
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        openStreamWebEmbedBridge = OpenStreamWebEmbedBridge(this)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.m5ham3ds.raven23/embedded_web_player",
            EmbeddedWebPlaybackViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "raven23/openstream_web_embed",
        ).setMethodCallHandler { call, result ->
            val handled = openStreamWebEmbedBridge?.handle(call, result) ?: false
            if (!handled) result.notImplemented()
        }

        playbackAdBrowserBridge = PlaybackAdBrowserBridge(
            this, flutterEngine.dartExecutor.binaryMessenger,
        )

        playbackAdInputBridge = PlaybackAdInputBridge(
            flutterEngine.dartExecutor.binaryMessenger,
        ) { identifier ->
            val plugin = flutterEngine.plugins.get(WebViewFlutterPlugin::class.java)
                as? WebViewFlutterPlugin
            plugin?.instanceManager?.getInstance<WebView>(identifier)
        }

        val bridge = StreamDownloadsBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        downloadsBridge = bridge
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "com.m5ham3ds.raven23/offline_player",
                StreamOfflinePlayerFactory(bridge.store),
            )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_PRESENTATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTelevision" -> result.success(isTelevision())
                // Full-screen ads run in their own activity, above anything
                // Flutter can draw; a toast still shows on top of them.
                "showHint" -> {
                    val text = call.arguments as? String
                    if (text.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        Toast.makeText(applicationContext, text, Toast.LENGTH_LONG).show()
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // The intent the activity started on is where a tapped or shared address arrives, and it is
        // already in hand by the time the engine is configured — well before Dart can ask for it.
        linkBridge = MediaLinkBridge(flutterEngine.dartExecutor.binaryMessenger).also {
            it.onIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        linkBridge?.onIntent(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        streamingDndBridge?.dispose()
        streamingDndBridge = null
        mihonChannel?.setMethodCallHandler(null)
        mihonChannel = null
        mihonBridge = null
        mihonScope?.cancel()
        mihonScope = null
        mangaTranslationChannel?.setMethodCallHandler(null)
        mangaTranslationChannel = null
        mangaReaderComfortChannel?.setMethodCallHandler(null)
        mangaReaderComfortChannel = null
        mangaReaderVolumeChannel?.setMethodCallHandler(null)
        mangaReaderVolumeChannel = null
        mangaVolumeKeyPaging = false
        mangaTranslationBridge?.dispose()
        mangaTranslationBridge = null
        playbackAdBrowserBridge?.dispose()
        playbackAdBrowserBridge = null
        playbackAdInputBridge?.dispose()
        playbackAdInputBridge = null
        linkBridge?.dispose()
        linkBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        launchingOwnActivity = true
        try {
            super.startActivityForResult(intent, requestCode, options)
        } catch (e: RuntimeException) {
            launchingOwnActivity = false
            throw e
        }
    }

    // Only a real departure, such as the home button, reaches the plugins listening for it.
    override fun onUserLeaveHint() {
        if (launchingOwnActivity) {
            launchingOwnActivity = false
            return
        }
        super.onUserLeaveHint()
    }

    override fun onResume() {
        super.onResume()
        launchingOwnActivity = false
        streamingDndBridge?.setForeground(true)
    }

    override fun onPause() {
        mangaVolumeKeyPaging = false
        streamingDndBridge?.setForeground(false)
        super.onPause()
    }

    // Android sends hardware volume keys to the Activity before Flutter's
    // Focus tree can see them. Intercept them only while the manga reader has
    // explicitly enabled page turning; otherwise the system volume is untouched.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (mangaVolumeKeyPaging &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
                event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                val direction = if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) "up" else "down"
                mangaReaderVolumeChannel?.invokeMethod("volumeKey", direction)
            }
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (downloadsBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun isTelevision(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        return uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            (uiModeManager == null &&
                packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK))
    }

    private companion object {
        const val DEVICE_PRESENTATION_CHANNEL =
            "com.m5ham3ds.raven23/device_presentation"
    }
}
