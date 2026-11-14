/*
 * Copyright 2015 Javier Tomás
 * Licensed under the Apache License, Version 2.0.
 * Adapted from Mihon/Anliyomi host integration for RAVEN23.
 */
package com.m5ham3ds.raven23.mihon

import android.app.Application
import android.content.Context
import android.util.Log
import eu.kanade.tachiyomi.network.NetworkHelper
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.protobuf.ProtoBuf
import okhttp3.OkHttpClient
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.InjektModule
import uy.kohesive.injekt.api.InjektRegistrar
import uy.kohesive.injekt.api.addSingleton

/** Lazy, idempotent dependency graph required by Mihon extension constructors. */
object RavenMihonInjektModules {
    private const val TAG = "RavenMihonInjekt"
    @Volatile private var registered = false

    @OptIn(ExperimentalSerializationApi::class)
    fun ensureRegistered(context: Context) {
        if (registered) return
        synchronized(this) {
            if (registered) return
            val app = context.applicationContext as Application
            val client = OkHttpClient.Builder().build()
            Injekt.importModule(object : InjektModule {
                override fun InjektRegistrar.registerInjectables() {
                    addSingleton(app)
                    addSingleton(NetworkHelper(app, client))
                    addSingleton(Json { ignoreUnknownKeys = true; explicitNulls = false })
                    addSingleton<ProtoBuf>(ProtoBuf)
                }
            })
            registered = true
            Log.i(TAG, "Mihon extension dependency graph registered")
        }
    }
}
