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
    fun offlineExportRejectsShortSegmentsButAllowsSmallRuntimeDifferences() {
        assertTrue(isOfflineExportDurationComplete(2_880_000L, 2_880_000L))
        assertTrue(isOfflineExportDurationComplete(2_770_000L, 2_880_000L))
        assertFalse(isOfflineExportDurationComplete(60_000L, 2_880_000L))
        assertFalse(isOfflineExportDurationComplete(0L, 2_880_000L))
        assertTrue(isOfflineExportDurationComplete(180_000L, 0L))
        assertFalse(isOfflineExportDurationComplete(-1L, 0L))
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
