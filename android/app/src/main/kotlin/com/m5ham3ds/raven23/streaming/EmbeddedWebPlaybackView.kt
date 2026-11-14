package com.m5ham3ds.raven23.streaming

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.view.View
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.ByteArrayInputStream
import java.net.InetAddress
import java.util.Locale

/** Native, visible embedded-player WebView. No JavaScript interface is exposed to page content. */
class EmbeddedWebPlaybackViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        EmbeddedWebPlaybackView(context, messenger, viewId, args as? Map<*, *> ?: emptyMap<Any, Any>())
}

@SuppressLint("SetJavaScriptEnabled")
private class EmbeddedWebPlaybackView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    args: Map<*, *>,
) : PlatformView, EventChannel.StreamHandler {
    private val container = FrameLayout(context)
    private val webView = WebView(context)
    private val methodChannel = MethodChannel(messenger, "raven23/embedded_web_player/$viewId")
    private val eventChannel = EventChannel(messenger, "raven23/embedded_web_player_events/$viewId")
    private var eventSink: EventChannel.EventSink? = null
    private var lastStatus = "loading"
    private var lastCanGoBack = false
    private var disposed = false
    private var currentScheme = "https"
    private var currentHost: String = ""

    init {
        container.addView(webView, FrameLayout.LayoutParams(-1, -1))
        methodChannel.setMethodCallHandler(::onMethodCall)
        eventChannel.setStreamHandler(this)
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = false
            allowFileAccess = false
            allowContentAccess = false
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            mediaPlaybackRequiresUserGesture = true
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            cacheMode = WebSettings.LOAD_NO_CACHE
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) safeBrowsingEnabled = true
        }
        // Preserve the app's process-wide first-party cookie setting; only the
        // third-party cookie policy is constrained for this individual view.
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, false)
        webView.webChromeClient = object : WebChromeClient() {
            override fun onReceivedTitle(view: WebView?, title: String?) {
                super.onReceivedTitle(view, title)
                if (isVerificationText(title.orEmpty())) emit("verification_required")
            }
        }
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val target = request?.url ?: return true
                if (!isAllowedNetworkUri(target)) {
                    emit("unsupported_link")
                    return true
                }
                if (currentScheme == "https" && target.scheme != "https") {
                    emit("blocked")
                    return true
                }
                val isRedirect = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && request.isRedirect
                val hasGesture = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && request.hasGesture()
                if (request.isForMainFrame && !isRedirect &&
                    !target.host.orEmpty().equals(currentHost, ignoreCase = true) && !hasGesture) {
                    emit("unsupported_link")
                    return true
                }
                return false
            }

            override fun shouldInterceptRequest(view: WebView?, request: WebResourceRequest?): WebResourceResponse? {
                val target = request?.url
                if (target == null || !isAllowedNetworkUri(target)) {
                    return blockedResponse()
                }
                return super.shouldInterceptRequest(view, request)
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                val currentUri = runCatching { Uri.parse(url.orEmpty()) }.getOrNull()
                currentHost = currentUri?.host.orEmpty()
                currentScheme = currentUri?.scheme ?: currentScheme
                emit("loading")
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                if (isVerificationText(view?.title.orEmpty()) || isVerificationText(url.orEmpty())) {
                    emit("verification_required")
                } else if (lastStatus == "loading") {
                    emit("ready")
                }
                updateCanGoBack()
            }

            override fun onReceivedError(
                view: WebView?, request: WebResourceRequest?, error: android.webkit.WebResourceError?,
            ) {
                super.onReceivedError(view, request, error)
                if (request?.isForMainFrame == true) emit("failed")
            }

            override fun onReceivedHttpError(
                view: WebView?, request: WebResourceRequest?, response: WebResourceResponse?,
            ) {
                super.onReceivedHttpError(view, request, response)
                if (request?.isForMainFrame == true && (response?.statusCode ?: 0) in 401..403) {
                    emit("blocked")
                }
            }
        }
        val startUrl = args["url"]?.toString().orEmpty()
        val parsed = runCatching { Uri.parse(startUrl) }.getOrNull()
        if (parsed == null || !isAllowedNetworkUri(parsed)) {
            emit("unsupported_link")
        } else {
            currentScheme = parsed.scheme ?: "https"
            currentHost = parsed.host.orEmpty()
            webView.loadUrl(startUrl, safeInitialHeaders(args["headers"]))
        }
    }

    override fun getView(): View = container

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        events?.success(eventPayload(lastStatus))
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("disposed", "Embedded player session has ended.", null)
            return
        }
        when (call.method) {
            "goBack" -> {
                val canGoBack = webView.canGoBack()
                if (canGoBack) webView.goBack()
                updateCanGoBack()
                result.success(canGoBack)
            }
            "canGoBack" -> result.success(webView.canGoBack())
            "reload" -> {
                emit("loading")
                webView.reload()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun updateCanGoBack() {
        lastCanGoBack = webView.canGoBack()
        eventSink?.success(eventPayload(lastStatus))
    }

    private fun emit(status: String) {
        lastStatus = status
        lastCanGoBack = webView.canGoBack()
        eventSink?.success(eventPayload(status))
    }

    private fun eventPayload(status: String): Map<String, Any> = mapOf(
        "status" to status,
        "canGoBack" to lastCanGoBack,
    )

    private fun blockedResponse() = WebResourceResponse(
        "text/plain", "utf-8", 403, "Blocked network destination", emptyMap(),
        ByteArrayInputStream(ByteArray(0)),
    )

    private fun safeInitialHeaders(raw: Any?): Map<String, String> {
        val supplied = raw as? Map<*, *> ?: return emptyMap()
        val allowed = setOf("referer", "origin", "user-agent")
        val result = linkedMapOf<String, String>()
        for ((rawKey, rawValue) in supplied) {
            val key = rawKey?.toString()?.trim().orEmpty()
            val value = rawValue?.toString()?.trim().orEmpty()
            if (key.lowercase(Locale.ROOT) !in allowed || value.isEmpty()) continue
            if (value.any { it == '\r' || it == '\n' }) continue
            val uri = if (key.equals("Referer", true) || key.equals("Origin", true))
                runCatching { Uri.parse(value) }.getOrNull() else null
            if (uri != null && !isAllowedNetworkUri(uri)) continue
            result[key] = value
        }
        return result
    }

    private fun isAllowedNetworkUri(uri: Uri): Boolean {
        val scheme = uri.scheme?.lowercase(Locale.ROOT)
        val host = uri.host?.lowercase(Locale.ROOT)?.removeSuffix(".") ?: return false
        if ((scheme != "http" && scheme != "https") || !uri.userInfo.isNullOrEmpty() || host.isBlank()) return false
        if (host == "localhost" || host.endsWith(".localhost") || host.endsWith(".local") ||
            host.endsWith(".internal") || host.endsWith(".test") || host.endsWith(".invalid")) return false
        val numericCandidate = host.matches(Regex("(?i)^(?:(?:0x[0-9a-f]+)|[0-9]+)(?:\\.(?:(?:0x[0-9a-f]+)|[0-9]+))*$"))
        val literal = if (host.contains(':') || numericCandidate) runCatching { InetAddress.getByName(host) }.getOrNull() else null
        if (numericCandidate && literal == null) return false
        if (literal != null) {
            if (literal.isAnyLocalAddress || literal.isLoopbackAddress || literal.isLinkLocalAddress ||
                literal.isSiteLocalAddress || literal.isMulticastAddress) return false
            val bytes = literal.address
            if (bytes.size == 16 && (bytes[0].toInt() and 0xfe) == 0xfc) return false
        }
        return true
    }

    private fun isVerificationText(value: String): Boolean {
        val text = value.lowercase(Locale.ROOT)
        return listOf("cloudflare", "just a moment", "verify you are human", "captcha", "security check", "human verification")
            .any(text::contains)
    }


    override fun dispose() {
        if (disposed) return
        disposed = true
        eventChannel.setStreamHandler(null)
        methodChannel.setMethodCallHandler(null)
        eventSink = null
        runCatching { webView.onPause() }
        runCatching { webView.stopLoading() }
        runCatching { webView.loadUrl("about:blank") }
        runCatching { webView.clearHistory() }
        // LOAD_NO_CACHE is configured for this view. clearCache() is process-wide
        // and could unexpectedly flush unrelated WebViews owned by other features.
        runCatching { webView.webChromeClient = null }
        runCatching { webView.webViewClient = WebViewClient() }
        runCatching { container.removeView(webView) }
        runCatching { webView.destroy() }
    }
}
