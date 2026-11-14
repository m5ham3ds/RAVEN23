package com.m5ham3ds.raven23.mihon

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MihonExtensionLoaderAbiTest {

    @Test
    fun androidFloatRepresentationOfSixteenIsAcceptedAndCanonicalized() {
        val packageManagerValue = 1.6f.toDouble()

        assertEquals(1.600000023841858, packageManagerValue, 0.0)
        assertTrue(MihonExtensionLoader.isLibVersionSupported(packageManagerValue))
        assertEquals(1.6, MihonExtensionLoader.normalizeSupportedLibVersion(packageManagerValue)!!, 0.0)
        assertEquals(
            1.4,
            MihonExtensionLoader.normalizeSupportedLibVersion(1.4f.toDouble())!!,
            0.0,
        )
    }

    @Test
    fun exactSupportedVersionsRemainAccepted() {
        assertEquals(1.4, MihonExtensionLoader.normalizeSupportedLibVersion(1.4)!!, 0.0)
        assertEquals(1.6, MihonExtensionLoader.normalizeSupportedLibVersion(1.6)!!, 0.0)
    }

    @Test
    fun unsupportedVersionsAndNonFiniteValuesRemainRejected() {
        val unsupported = listOf(
            1.5,
            1.6000001,
            1.600001,
            1.6001,
            1.7,
            Double.NaN,
            Double.POSITIVE_INFINITY,
            Double.NEGATIVE_INFINITY,
        )

        unsupported.forEach { version ->
            assertFalse("Unexpectedly accepted extensions-lib version: $version", MihonExtensionLoader.isLibVersionSupported(version))
            assertNull(MihonExtensionLoader.normalizeSupportedLibVersion(version))
        }
    }
}
