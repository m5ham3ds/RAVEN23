package com.m5ham3ds.raven23.downloads

import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadRequest
import org.junit.Assert.assertEquals
import org.junit.Test

/** The external better_player_plus package opens offline downloads through its retained reflection API. */
class StreamDownloadStorePlayerContractTest {
    @Test fun playerReflectionTargetsStillExist() {
        val store = StreamDownloadStore::class.java
        assertEquals(Download::class.java, store.getMethod("getDownload", String::class.java).returnType)
        assertEquals(CacheDataSource.Factory::class.java,
            store.getMethod("readOnlyCacheFactory", DownloadRequest::class.java).returnType)
    }
}
