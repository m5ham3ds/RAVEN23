package eu.kanade.tachiyomi.network

import android.content.Context
import android.webkit.WebSettings
import eu.kanade.tachiyomi.network.interceptor.CloudflareInterceptor
import eu.kanade.tachiyomi.network.interceptor.UncaughtExceptionInterceptor
import eu.kanade.tachiyomi.network.interceptor.UserAgentInterceptor
import okhttp3.Cache
import okhttp3.OkHttpClient
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Host-provided network service injected into Mihon-compatible manga extensions.
 *
 * RAVEN23 creates a dedicated seed [OkHttpClient] for this runtime in
 * [com.m5ham3ds.raven23.mihon.RavenMihonInjektModules]. This helper derives the
 * Manga extension client from that seed and installs Mihon's required
 * interceptors, WebView-backed cookie jar, Cloudflare handling, cache and
 * download timeouts. It is intentionally isolated from the app's video and
 * anime networking stacks so Manga extensions cannot change their behavior.
 */
class NetworkHelper(
    private val context: Context,
    baseClient: OkHttpClient,
) {

    init {
        // Adopt the DEVICE's real WebView User-Agent as the app's default.
        //
        // A cf_clearance cookie is tied to the browser identity that earned it,
        // and Cloudflare cross-checks the UA against signals the WebView sends
        // regardless (Sec-CH-UA client hints, TLS). Shipping a fixed
        // "Android 13; Pixel 7 … Chrome/125" string made those disagree: the
        // solver forces the WebView to claim Chrome 125 while its client hints
        // still say what it really is (a tester on Android 10 reported
        // Chrome/141), so the clearance is issued against an identity our
        // okhttp requests can't reproduce — the user passes the challenge and
        // is immediately blocked again. Taking the real UA makes the challenge
        // and the requests that follow it the same browser.
        //
        // `; wv` marks the UA as a WebView; upstream strips it so sources see a
        // normal Chrome, and the tester's Animiru UA confirms that convention.
        // Best-effort: this can throw while WebView is being updated, and the
        // hardcoded constant remains the fallback.
        if (deviceUserAgent == null) {
            deviceUserAgent = runCatching {
                WebSettings.getDefaultUserAgent(context)
                    .replace("; wv", "")
                    .takeIf { it.isNotBlank() }
            }.getOrNull()
        }
    }

    /** Cookie store backed by Android's global WebView [android.webkit.CookieManager].
     *  Declared before [client] because the Cloudflare interceptor reads and updates it. */
    val cookieJar = AndroidCookieJar()

    /**
     * Private Manga extension client derived from RAVEN23's Mihon seed client.
     *
     * Extensions default GET/POST requests to `maxAge(10, MINUTES)` ([Requests]),
     * which requires a backing cache. The cache keeps catalogue/detail/chapter
     * responses locally and eases source rate limits. Image/page byte fetches
     * derive a cacheless client (`newCachelessCallWithProgress`) so large image
     * responses do not evict the JSON cache.
     */
    val client: OkHttpClient = baseClient.newBuilder()
        // Set explicit Mihon timeouts on the dedicated seed client. Its defaults
        // would otherwise allow a source call to wait indefinitely (callTimeout=0).
        // Connect/read timeouts only fire while a host is silent, so a source that
        // trickles bytes or loops through redirects also needs a total call timeout.
        //
        // These are upstream's own numbers, so extensions are already written
        // against them. Worst blocking wait inside this client is well under the
        // 2-minute cap: the headless Cloudflare solve is 12s, WebViewInterceptor
        // 30s, and the VISIBLE solve doesn't block at all (CloudflareInterceptor
        // throws CloudflareRequiredException and the user retries afterwards).
        // Two of the three are also looser than what we had.
        //
        // downloadClient below overrides callTimeout to 30 minutes, so large
        // media downloads keep their own budget.
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .callTimeout(2, TimeUnit.MINUTES)
        // Mihon's default client must carry an UncaughtExceptionInterceptor FIRST
        // in the chain — some extensions (e.g. Asura Scans) assert its presence on
        // the DEFAULT client and otherwise throw "UncaughtExceptionInterceptor must
        // be present in default client", so browse/latest just fail. The Mihon
        // client is isolated from video/anime clients; index 0 wraps all remaining
        // Manga interceptors.
        .apply { interceptors().add(0, UncaughtExceptionInterceptor()) }
        // Same story: extensions also assert a UserAgentInterceptor on the default
        // client ("UserAgentInterceptor must be present in default client"). It
        // just fills in a default User-Agent when a request has none.
        .addInterceptor(UserAgentInterceptor(::defaultUserAgentProvider))
        // 15 MB is plenty for JSON (browse/detail/chapter lists); LRU-evicted.
        .cache(Cache(File(context.cacheDir, "network_cache"), 15L * 1024 * 1024))
        // Read and write cookies through the global WebView CookieManager so the
        // cf_clearance produced by a visible or headless WebView solve is sent by
        // subsequent Manga source requests.
        .cookieJar(cookieJar)
        // Solve Cloudflare challenges (403/503 + `Server: cloudflare`) for Manga
        // sources. Non-challenge traffic passes through untouched. This interceptor
        // is installed only in the private Mihon client.
        .addInterceptor(
            CloudflareInterceptor(context, cookieJar, ::defaultUserAgentProvider),
        )
        // Pin the User-Agent of clearance-carrying requests, at the wire.
        //
        // A network interceptor is the last thing before the socket, so it sees
        // (and fixes) the FINAL headers — an application interceptor can't. That
        // distinction is the whole point: on a blocked device the application
        // layer reported the UA as correct while the wire carried a different
        // one, because layers below it had rewritten the request. Anything that
        // must be true of what leaves the phone has to be enforced here.
        .addNetworkInterceptor { chain ->
            val original = chain.request()
            val cookieHeader = original.header("Cookie").orEmpty()
            val pinnedUa = solveUaFor(original.url.host)
            val req = if (
                pinnedUa != null &&
                cookieHeader.contains("cf_clearance") &&
                original.header("User-Agent") != pinnedUa
            ) {
                original.newBuilder().header("User-Agent", pinnedUa).build()
            } else {
                original
            }
            val res = chain.proceed(req)
            val cfServer = res.header("Server")?.contains("cloudflare", true) == true
            if (res.code in intArrayOf(403, 503) && cfServer) {
                val wireUa = req.header("User-Agent").orEmpty()
                val solveUa = (solveUaFor(req.url.host) ?: challengeUserAgent).orEmpty()
                val cookie = req.header("Cookie").orEmpty()
                fun tail(s: String) = if (s.length > 26) "…" + s.takeLast(26) else s
                android.util.Log.w(
                    "RAVEN23MihonCF",
                    "refused at the wire: ${res.code} ${req.url.host} " +
                        "cf=${if (cookie.contains("cf_clearance")) "yes" else "NO"} " +
                        "ua=${if (wireUa == solveUa) "same" else "DIFF"} " +
                        "ray=${res.header("cf-ray")?.take(8) ?: "-"}\n" +
                        "wireUA=$wireUa\nsolveUA=$solveUa\ncookie=${tail(cookie)}",
                )
            }
            res
        }
        .build()

    /**
     * @deprecated Since extension-lib 1.5 — the regular [client] handles Cloudflare.
     * Kept because older extensions still reference it.
     */
    @Deprecated("The regular client handles Cloudflare by default", ReplaceWith("client"))
    @Suppress("unused")
    val cloudflareClient: OkHttpClient = client

    /** Longer-timeout variant used by extensions for large media downloads.
     *  Cacheless — big media must not evict the JSON response cache (and was
     *  never cached before this). */
    val downloadClient: OkHttpClient = client.newBuilder()
        .cache(null)
        .callTimeout(30, TimeUnit.MINUTES)
        .build()

    /** The instance overload the interceptors above are wired to — it must
     *  resolve to the SAME string as the companion one, or okhttp would send a
     *  different UA than the Cloudflare solve used. */
    fun defaultUserAgentProvider(): String = Companion.defaultUserAgentProvider()

    companion object {
        /** Fallback only — used until [deviceUserAgent] is known, and on the
         *  rare device where WebView can't be queried at all. */
        private const val DEFAULT_USER_AGENT =
            "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) " +
                "Chrome/125.0.0.0 Mobile Safari/537.36"

        /** The device's own WebView UA (`; wv` stripped), filled in by the
         *  NetworkHelper constructor. Null until then. */
        @Volatile
        var deviceUserAgent: String? = null

        fun defaultUserAgentProvider(): String = deviceUserAgent ?: DEFAULT_USER_AGENT

        /**
         * The User-Agent of the last request that hit a Cloudflare challenge.
         * The visible solver (SourceWebViewActivity) reads this so it solves
         * with the SAME UA the source's okhttp requests actually send — a
         * cf_clearance cookie is bound to its UA, so a mismatch (source uses its
         * own UA, solver used the app default) makes Cloudflare reject the
         * solved cookie and re-challenge forever.
         */
        @Volatile
        var challengeUserAgent: String? = null

        /**
         * The UA a Cloudflare challenge was solved under, PER HOST.
         *
         * [challengeUserAgent] alone is a single global, and a browse fires
         * several requests at once (list, latest, covers) that need not carry
         * the same UA — whichever is challenged last wins, so the solve can run
         * under one request's UA while another goes out with a different one.
         * cf_clearance is bound to the UA that earned it, so Cloudflare refuses
         * the mismatch and the user is challenged again immediately. Measured on
         * a blocked device: cookie present on the wire, UA different.
         *
         * Keyed by host because that's the scope a clearance has.
         */
        private val solveUaByHost = java.util.concurrent.ConcurrentHashMap<String, String>()

        fun rememberSolveUa(host: String, ua: String?) {
            if (!ua.isNullOrBlank()) solveUaByHost[host] = ua
        }

        fun solveUaFor(host: String): String? = solveUaByHost[host]

        /**
         * When the visible solver last came away with a `cf_clearance`
         * (`System.currentTimeMillis()`, 0 = never).
         *
         * The Cloudflare interceptor clears cf_clearance before every re-solve.
         * That's right for a stale cookie and wrong for one the user just earned
         * by hand — deleting it means the next challenge re-prompts, and the
         * solve after that is deleted too, forever. This lets the interceptor
         * spot a fresh cookie and keep it.
         */
        @Volatile
        var lastSolveAtMs: Long = 0L
    }
}
