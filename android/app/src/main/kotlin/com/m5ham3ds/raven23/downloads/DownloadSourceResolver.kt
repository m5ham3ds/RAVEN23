package com.m5ham3ds.raven23.downloads

import android.net.Uri
import android.util.Base64
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.offline.DownloadRequest
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

/** Resolve a refreshed link's container without assuming signed URLs have file extensions. */
internal fun downloadLinkFormat(
    isM3u8: Boolean,
    isDash: Boolean,
    declaredContainer: String?,
    url: String,
): String {
    if (isM3u8) return "hls"
    if (isDash) return "dash"
    when (declaredContainer?.trim()?.lowercase()) {
        "hls", "m3u8" -> return "hls"
        "dash", "mpd" -> return "dash"
        "mp4", "m4v" -> return "mp4"
        "webm" -> return "webm"
    }
    // Keep format inference JVM-testable: this helper only needs the URL path,
    // not Android Uri behavior. URI handles escaped paths; URL is a tolerant
    // fallback for provider URLs containing characters URI rejects.
    val path = runCatching { URI(url).path.orEmpty() }.getOrElse {
        runCatching { URL(url).path.orEmpty() }.getOrDefault("")
    }.lowercase()
    return when {
        path.endsWith(".m3u8") -> "hls"
        path.endsWith(".mpd") -> "dash"
        path.endsWith(".mp4") || path.endsWith(".m4v") -> "mp4"
        path.endsWith(".webm") -> "webm"
        else -> "progressive"
    }
}

/** Refresh only positively identified expiry, never connectivity errors or generic HTTP failures. */
@UnstableApi
internal object DownloadExpiry {
    fun isExpired(error: IOException): Boolean {
        val response = generateSequence<Throwable>(error) { it.cause }
            .filterIsInstance<HttpDataSource.InvalidResponseCodeException>().firstOrNull() ?: return false
        if (response.responseCode !in listOf(400, 401, 403, 404, 410)) return false
        val body = response.responseBody.toString(Charsets.UTF_8).take(4096).lowercase()
        if (Regex("\\bexpired\\b|\\btoken_expired\\b|\\bexpiredtoken\\b|\\brequestexpired\\b").containsMatchIn(body) &&
            !Regex("\\bnot\\s+expired\\b").containsMatchIn(body)) return true
        if (response.responseCode !in listOf(401, 403, 410)) return false
        val uri = response.dataSpec.uri
        val now = System.currentTimeMillis() / 1000
        for (name in listOf("expires", "Expires", "exp")) {
            val expires = uri.getQueryParameter(name)?.toLongOrNull() ?: continue
            if (expires in 1..now) return true
        }
        // A JWT's expiry is only a hint after the server has rejected this URL.
        val token = uri.getQueryParameter("token") ?: return false
        return try {
            val parts = token.split('.')
            if (parts.size != 3) false else {
                val payload = JSONObject(String(Base64.decode(parts[1], Base64.URL_SAFE or Base64.NO_WRAP)))
                payload.optLong("exp", Long.MAX_VALUE) in 1..now
            }
        } catch (_: Exception) { false }
    }
}

internal fun resolveVixSrcUrl(baseUrl: String, reference: String): String? =
    runCatching {
        if (reference.startsWith("//")) {
            "https:$reference"
        } else {
            URI(baseUrl).resolve(reference).toString()
        }
    }.getOrNull()

/** Mirrors VixSrc's embed signing contract without depending on Android APIs. */
internal fun vixSrcMasterPlaylistUrl(embedHtml: String, baseUrl: String): String? {
    val url = Regex("""window\.masterPlaylist\s*=\s*\{[\s\S]*?url:\s*['"]([^'"]+)['"]""")
        .find(embedHtml)?.groupValues?.getOrNull(1) ?: return null
    val token = Regex("""['"]token['"]\s*:\s*['"]([^'"]+)['"]""")
        .find(embedHtml)?.groupValues?.getOrNull(1) ?: return null
    val expires = Regex("""['"]expires['"]\s*:\s*['"]([^'"]+)['"]""")
        .find(embedHtml)?.groupValues?.getOrNull(1) ?: return null
    val resolved = resolveVixSrcUrl(baseUrl, url) ?: return null
    val uri = runCatching { URI(resolved) }.getOrNull() ?: return null
    if (uri.scheme !in listOf("http", "https") || uri.rawAuthority.isNullOrBlank()) return null

    val retainedQuery = uri.rawQuery.orEmpty().split('&')
        .filter(String::isNotBlank)
        .filterNot { item ->
            val key = item.substringBefore('=')
            runCatching { java.net.URLDecoder.decode(key, "UTF-8") }
                .getOrDefault(key) in setOf("token", "expires", "h", "lang")
        }
    fun encode(value: String): String =
        java.net.URLEncoder.encode(value, "UTF-8").replace("+", "%20")
    val query = (retainedQuery + listOf(
        "token=" + encode(token),
        "expires=" + encode(expires),
        "h=1",
        "lang=en",
    )).joinToString("&")
    return buildString {
        append(uri.scheme)
        append("://")
        append(uri.rawAuthority)
        append(uri.rawPath.orEmpty())
        append('?')
        append(query)
        uri.rawFragment?.let { append('#').append(it) }
    }
}

@UnstableApi
internal class DownloadSourceResolver {
    /** Returns preparation arguments retaining the original source and track constraints. */
    fun resolve(request: DownloadRequest): Map<String, Any?> {
        val metadata = StreamDownloadStore.requestMetadata(request)
        val source = metadata.optJSONObject("source") ?: throw IOException("Download source metadata is unavailable.")
        if (source.optString("resolverType", "scraperApi") == "vixsrc") {
            return resolveVixSrc(request, metadata, source)
        }
        checkSource(source, metadata)
        val query = buildMap {
            put("provider", source.getString("providerId"))
            put("tmdbId", metadata.getInt("contentId").toString())
            if (metadata.getString("mediaType") == "episode") {
                put("season", metadata.getInt("seasonNumber").toString())
                put("episode", metadata.getInt("episodeNumber").toString())
            }
        }
        val path = if (metadata.getString("mediaType") == "movie") "/stream-movie" else "/stream-tv"
        val base = source.getString("apiBaseUrl").trim().trimEnd('/')
            .let { if (it.endsWith("/api/v2")) it else "$it/api/v2" }
        fun fetch(full: Boolean): JSONObject {
            val uri = Uri.parse("$base$path").buildUpon()
            query.forEach { (key, value) -> uri.appendQueryParameter(key, value) }
            if (full) uri.appendQueryParameter("full", "true")
            return getJson(uri.build().toString())
        }
        var body = fetch(true)
        if (!body.optBoolean("success") && body.optString("error").contains("full stream collection", true)) {
            body = fetch(false)
        }
        if (!body.optBoolean("success") || body.optString("provider") != source.getString("providerId")) {
            throw IOException("Could not renew the original download provider. Retry later.")
        }
        body.optJSONObject("media")?.let { media ->
            val expectedType = if (metadata.getString("mediaType") == "movie") "movie" else "show"
            if (media.optString("tmdbId") != metadata.getInt("contentId").toString() || media.optString("type") != expectedType) {
                throw IOException("The renewed source does not match the original title.")
            }
        }
        val format = metadata.getString("format")
        val links = body.optJSONArray("links") ?: throw IOException("The original download source is unavailable.")
        val matches = (0 until links.length()).mapNotNull { links.optJSONObject(it) }.filter { link ->
            link.optString("quality", "unknown quality") == source.getString("quality") &&
                link.optString("server") == source.optString("server") &&
                linkFormat(link) == format &&
                link.optString("url").isNotBlank()
        }.distinctBy { jsonMap(it) }
        if (matches.size != 1) {
            throw IOException("The original server and quality are unavailable or ambiguous. Retry later.")
        }
        val link = matches.single()
        val uri = Uri.parse(link.getString("url"))
        if (uri.scheme !in listOf("http", "https") || uri.host.isNullOrBlank()) throw IOException("Invalid renewed download URL.")
        val headers = link.optJSONObject("headers")?.let(::jsonMap)?.takeIf { it.isNotEmpty() }
            ?: if (uri.host?.let { it == "vixsrc.to" || it.endsWith(".vixsrc.to") } == true) {
                mapOf("accept" to "*/*", "origin" to "https://vixsrc.to", "referer" to "https://vixsrc.to/",
                    "user-agent" to "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36")
            } else emptyMap()
        return jsonMap(metadata) + mapOf(
            "id" to request.id,
            "url" to uri.toString(),
            "headers" to headers,
        )
    }

    private fun resolveVixSrc(
        request: DownloadRequest,
        metadata: JSONObject,
        source: JSONObject,
    ): Map<String, Any?> {
        val base = source.optString("apiBaseUrl").trim().trimEnd('/')
        val baseUri = runCatching { URI(base) }.getOrNull()
            ?: throw IOException("Invalid VixSrc base URL.")
        if (source.optInt("version") != 1 ||
            source.optString("resolverType") != "vixsrc" ||
            source.optString("providerId") != "vixsrc" ||
            baseUri.scheme != "https" || baseUri.host != "vixsrc.to" ||
            source.optString("quality").isBlank() ||
            metadata.optInt("contentId") <= 0 ||
            metadata.optString("cacheNamespace").isBlank() ||
            metadata.optJSONArray("selectedTracks") == null ||
            metadata.optString("format") != "hls") {
            throw IOException("VixSrc download recovery metadata is incomplete.")
        }

        val apiPath = when (metadata.optString("mediaType")) {
            "movie" -> "/api/movie/\${metadata.getInt("contentId")}"
            "episode" -> {
                val season = metadata.optInt("seasonNumber", -1)
                val episode = metadata.optInt("episodeNumber", -1)
                if (season <= 0 || episode <= 0) {
                    throw IOException("VixSrc episode recovery metadata is incomplete.")
                }
                "/api/tv/\${metadata.getInt("contentId")}/$season/$episode"
            }
            else -> throw IOException("VixSrc only supports movie and episode downloads.")
        }
        val apiUrl = base + apiPath
        val headers = mapOf(
            "Accept" to "*/*",
            "Origin" to "https://vixsrc.to",
            "Referer" to "https://vixsrc.to/",
            "User-Agent" to VIXSRC_USER_AGENT,
        )

        repeat(2) {
            val apiResponse = requestText(apiUrl, headers)
            if (apiResponse.code !in 200..299) {
                throw IOException("VixSrc could not renew the original title link (HTTP \${apiResponse.code}).")
            }
            val embedReference = try {
                JSONObject(apiResponse.body).optString("src").takeIf(String::isNotBlank)
            } catch (_: Exception) {
                null
            } ?: throw IOException("VixSrc returned an invalid embed reference.")
            val embedUrl = resolveVixSrcUrl(base, embedReference)
                ?: throw IOException("VixSrc returned an invalid embed URL.")
            val embedResponse = requestText(embedUrl, headers)
            if (embedResponse.code == 410) return@repeat
            if (embedResponse.code !in 200..299) {
                throw IOException("VixSrc embed is unavailable (HTTP \${embedResponse.code}).")
            }
            val playlistUrl = vixSrcMasterPlaylistUrl(embedResponse.body, base)
                ?: throw IOException("VixSrc did not provide a renewed HLS playlist.")
            val playlistResponse = requestText(playlistUrl, headers)
            if (playlistResponse.code == 410) return@repeat
            if (playlistResponse.code !in 200..299 ||
                !playlistResponse.body.lineSequence().any {
                    it.trim().startsWith("#EXT-X-STREAM-INF")
                }) {
                throw IOException("VixSrc renewed playlist is unavailable or invalid.")
            }
            return DownloadSourceResolver.jsonMap(metadata) + mapOf(
                "id" to request.id,
                "url" to playlistUrl,
                "headers" to headers,
            )
        }
        throw IOException("VixSrc embed token remained expired after renewal. Retry later.")
    }

    private data class TextResponse(val code: Int, val body: String)

    private fun requestText(url: String, headers: Map<String, String>): TextResponse {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 30_000
        connection.instanceFollowRedirects = true
        headers.forEach { (name, value) -> connection.setRequestProperty(name, value) }
        try {
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            return TextResponse(code, body)
        } finally {
            connection.disconnect()
        }
    }

    private fun linkFormat(link: JSONObject): String = downloadLinkFormat(
        isM3u8 = link.optBoolean("isM3U8"),
        isDash = link.optBoolean("isDASH") || link.optBoolean("isDash"),
        declaredContainer = link.optString("streamContainer")
            .takeIf(String::isNotBlank),
        url = link.optString("url"),
    )

    private fun checkSource(source: JSONObject, metadata: JSONObject) {
        if (source.optString("resolverType", "scraperApi") != "scraperApi" ||
            source.optInt("version") != 1 || source.optString("providerId").isBlank() ||
            source.optString("quality").isBlank() || metadata.optInt("contentId") <= 0 ||
            metadata.optString("cacheNamespace").isBlank() ||
            metadata.optJSONArray("selectedTracks") == null ||
            metadata.optString("format") !in listOf("hls", "dash", "mp4", "webm", "progressive") ||
            metadata.optString("mediaType") !in listOf("movie", "episode")) {
            throw IOException("Download recovery metadata is incomplete.")
        }
        val base = Uri.parse(source.optString("apiBaseUrl"))
        if (base.scheme !in listOf("http", "https") || base.host.isNullOrBlank()) throw IOException("Invalid download API URL.")
        if (metadata.optString("mediaType") == "episode" &&
            (metadata.optInt("seasonNumber", -1) < 0 || metadata.optInt("episodeNumber", -1) <= 0)) {
            throw IOException("Download episode metadata is incomplete.")
        }
    }

    private fun getJson(url: String): JSONObject {
        val response = requestText(url, mapOf("Accept" to "application/json"))
        val body = try {
            JSONObject(response.body)
        } catch (_: Exception) {
            throw IOException("Download provider returned an invalid response (HTTP \${response.code}).")
        }
        if (response.code !in 200..299 &&
            !body.optString("error").contains("full stream collection", true)) {
            throw IOException("Download provider is unavailable (HTTP \${response.code}). Retry later.")
        }
        return body
    }

    companion object {
        private const val VIXSRC_USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

        private fun jsonValue(value: Any?): Any? = when (value) {
            null, JSONObject.NULL -> null
            is JSONObject -> jsonMap(value)
            is org.json.JSONArray -> (0 until value.length()).map { jsonValue(value.get(it)) }
            else -> value
        }

        fun jsonMap(json: JSONObject): Map<String, Any?> = json.keys().asSequence().associateWith { key -> jsonValue(json.get(key)) }
    }
}
