package com.m5ham3ds.raven23.downloads

import androidx.media3.common.MimeTypes
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadRequest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The native Media3 offline PlatformView resolves completed downloads through these store APIs. */
class StreamDownloadStorePlayerContractTest {
    @Test
    fun progressiveContainersMapToMedia3ProgressiveMimeTypes() {
        assertEquals(MimeTypes.VIDEO_MP4, progressiveMimeType("mp4"))
        assertEquals(MimeTypes.VIDEO_MP4, progressiveMimeType("progressive"))
        assertEquals(MimeTypes.VIDEO_WEBM, progressiveMimeType("webm"))
    }

    @Test
    fun refreshedLinksRespectDeclaredContainerForOpaqueSignedUrls() {
        assertEquals(
            "mp4",
            downloadLinkFormat(
                isM3u8 = false,
                isDash = false,
                declaredContainer = "mp4",
                url = "https://cdn.example/stream?token=signed",
            ),
        )
        assertEquals(
            "webm",
            downloadLinkFormat(
                isM3u8 = false,
                isDash = false,
                declaredContainer = "webm",
                url = "https://cdn.example/stream?token=signed",
            ),
        )
        assertEquals(
            "hls",
            downloadLinkFormat(
                isM3u8 = true,
                isDash = false,
                declaredContainer = "mp4",
                url = "https://cdn.example/stream?token=signed",
            ),
        )
        assertEquals(
            "hls",
            downloadLinkFormat(
                isM3u8 = false,
                isDash = false,
                declaredContainer = null,
                url = "https://cdn.example/master.m3u8?token=signed",
            ),
        )
        assertEquals(
            "dash",
            downloadLinkFormat(
                isM3u8 = false,
                isDash = false,
                declaredContainer = null,
                url = "https://cdn.example/manifest.mpd?token=signed",
            ),
        )
        assertEquals(
            "mp4",
            downloadLinkFormat(
                isM3u8 = false,
                isDash = false,
                declaredContainer = null,
                url = "https://cdn.example/VIDEO.MP4?token=signed#segment",
            ),
        )
        assertEquals(
            "webm",
            downloadLinkFormat(
                isM3u8 = false,
                isDash = false,
                declaredContainer = null,
                url = "https://cdn.example/video.webm?token=signed",
            ),
        )
        assertEquals(
            "progressive",
            downloadLinkFormat(
                isM3u8 = false,
                isDash = false,
                declaredContainer = null,
                url = "https://cdn.example/stream?token=signed",
            ),
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun unsupportedProgressiveContainerIsRejected() {
        progressiveMimeType("torrent")
    }

    @Test
    fun offlineExportWatchdogHasABoundedDeadline() {
        assertFalse(isOfflineExportTimedOut(1_000L, 1_000L, 30_000L))
        assertFalse(isOfflineExportTimedOut(1_000L, 30_999L, 30_000L))
        assertTrue(isOfflineExportTimedOut(1_000L, 31_000L, 30_000L))
        assertFalse(isOfflineExportTimedOut(31_000L, 30_000L, 30_000L))
        assertFalse(isOfflineExportTimedOut(1_000L, 31_000L, 0L))
    }

    @Test
    fun offlineExportRejectsShortSegmentsButAllowsSmallRuntimeDifferences() {
        assertTrue(isOfflineExportDurationComplete(2_880_000L, 2_880_000L))
        assertTrue(isOfflineExportDurationComplete(2_770_000L, 2_880_000L))
        assertFalse(isOfflineExportDurationComplete(60_000L, 2_880_000L))
        assertFalse(isOfflineExportDurationComplete(0L, 2_880_000L))
        assertFalse(isOfflineExportDurationComplete(180_000L, 0L))
        assertFalse(isOfflineExportDurationComplete(-1L, 0L))
    }

    @Test
    fun offlineExportRequiresBothVideoAndAudioTracks() {
        assertTrue(isOfflineExportTrackSetComplete(true, true))
        assertFalse(isOfflineExportTrackSetComplete(true, false))
        assertFalse(isOfflineExportTrackSetComplete(false, true))
        assertFalse(isOfflineExportTrackSetComplete(false, false))
    }

    @Test
    fun vixSrcRefreshBuildsNewSignedMasterPlaylistUrlFromEmbed() {
        val html = """
            <script>
              window.masterPlaylist = { url: "/master.m3u8?asset=movie-42" };
              const signing = {"token":"new-token-123","expires":"1893456000"};
            </script>
        """.trimIndent()

        val renewed = vixSrcMasterPlaylistUrl(
            html,
            "https://vixsrc.to/embed/42",
        )

        assertTrue(renewed!!.startsWith("https://vixsrc.to/master.m3u8?"))
        assertTrue(renewed.contains("asset=movie-42"))
        assertTrue(renewed.contains("token=new-token-123"))
        assertTrue(renewed.contains("expires=1893456000"))
        assertTrue(renewed.contains("h=1"))
        assertTrue(renewed.contains("lang=en"))
    }

    @Test
    fun vixSrcRefreshResolvesRelativeAndProtocolRelativeEmbedUrls() {
        assertEquals(
            "https://vixsrc.to/embed/player",
            resolveVixSrcUrl("https://vixsrc.to/api/movie/42", "/embed/player"),
        )
        assertEquals(
            "https://cdn.vixsrc.to/embed/player",
            resolveVixSrcUrl("https://vixsrc.to/api/movie/42", "//cdn.vixsrc.to/embed/player"),
        )
    }

    @Test
    fun initialDownloadMustFitEstimateAndTwoHundredMiBReserve() {
        val reserve = OFFLINE_STORAGE_RESERVE_BYTES
        val estimate = 50L * 1024L * 1024L
        assertFalse(hasEnoughStorageToStart(reserve, null))
        assertFalse(hasEnoughStorageToStart(reserve + estimate, estimate))
        assertTrue(hasEnoughStorageToStart(reserve + estimate + 1L, estimate))
    }

    @Test
    fun activeDownloadPausesWhenStorageReachesTwoHundredMiB() {
        val reserve = OFFLINE_STORAGE_RESERVE_BYTES
        assertTrue(shouldPauseForLowStorage(reserve))
        assertTrue(shouldPauseForLowStorage(reserve - 1L))
        assertFalse(shouldPauseForLowStorage(reserve + 1L))
    }

    @Test
    fun resumeRequiresSpaceForOnlyTheEstimatedRemainingBytes() {
        val reserve = OFFLINE_STORAGE_RESERVE_BYTES
        val total = 500L * 1024L * 1024L
        val downloaded = 350L * 1024L * 1024L
        val remaining = total - downloaded
        assertFalse(hasEnoughStorageToResume(reserve + remaining, total, downloaded))
        assertTrue(hasEnoughStorageToResume(reserve + remaining + 1L, total, downloaded))
    }

    @Test
    fun unknownSizeStillRequiresTheTwoHundredMiBReserve() {
        val reserve = OFFLINE_STORAGE_RESERVE_BYTES
        assertFalse(hasEnoughStorageToResume(reserve, null, 0L))
        assertTrue(hasEnoughStorageToResume(reserve + 1L, null, 0L))
    }

    @Test
    fun movieExportUsesOnlyTheMovieTitle() {
        assertEquals(
            "Dune Part Two",
            OfflineExportFileNames.buildStem(
                title = "Dune Part Two",
                isMovie = true,
                season = -1,
                episode = -1,
                episodeLabel = "",
            ),
        )
    }

    @Test
    fun episodeExportIncludesSeasonEpisodeAndEpisodeName() {
        assertEquals(
            "ONE PIECE - S02E07 - The Adventure Begins",
            StreamDownloadsBridge.buildOfflineExportStem(
                title = "ONE PIECE",
                isMovie = false,
                season = 2,
                episode = 7,
                episodeLabel = "S02 • E07 The Adventure Begins • From Server",
            ),
        )
    }

    @Test
    fun episodeFolderStemRemainsTheSeriesTitle() {
        assertEquals(
            "ONE PIECE",
            OfflineExportFileNames.sanitize("ONE PIECE"),
        )
    }

    @Test
    fun exportTitleSanitizerRemovesUnsafePathCharacters() {
        assertEquals(
            "One_ Piece_ Season 2",
            StreamDownloadsBridge.sanitizeOfflineExportTitle("One/ Piece: Season 2"),
        )
    }

    @Test
    fun progressiveCacheExportRequiresACompletedMp4WithMatchingByteCount() {
        assertTrue(
            canCopyProgressiveMp4FromCache(
                state = Download.STATE_COMPLETED,
                mimeType = MimeTypes.VIDEO_MP4,
                contentLength = 120L,
                bytesDownloaded = 120L,
            ),
        )
        assertFalse(
            canCopyProgressiveMp4FromCache(
                state = Download.STATE_DOWNLOADING,
                mimeType = MimeTypes.VIDEO_MP4,
                contentLength = 120L,
                bytesDownloaded = 120L,
            ),
        )
        assertFalse(
            canCopyProgressiveMp4FromCache(
                state = Download.STATE_COMPLETED,
                mimeType = MimeTypes.APPLICATION_M3U8,
                contentLength = 120L,
                bytesDownloaded = 120L,
            ),
        )
        assertFalse(
            canCopyProgressiveMp4FromCache(
                state = Download.STATE_COMPLETED,
                mimeType = MimeTypes.VIDEO_MP4,
                contentLength = 120L,
                bytesDownloaded = 119L,
            ),
        )
        assertFalse(
            canCopyProgressiveMp4FromCache(
                state = Download.STATE_COMPLETED,
                mimeType = MimeTypes.VIDEO_MP4,
                contentLength = -1L,
                bytesDownloaded = 120L,
            ),
        )
    }

    @Test
    fun playerReflectionTargetsStillExist() {
        val store = StreamDownloadStore::class.java
        assertEquals(
            Download::class.java,
            store.getMethod("getDownload", String::class.java).returnType,
        )
        assertEquals(
            CacheDataSource.Factory::class.java,
            store.getMethod(
                "readOnlyCacheFactory",
                DownloadRequest::class.java,
            ).returnType,
        )
    }
}
