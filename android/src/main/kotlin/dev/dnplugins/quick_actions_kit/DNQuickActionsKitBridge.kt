// Copyright 2026 the quick_actions_kit contributors.
// SPDX-License-Identifier: Apache-2.0
package dev.dnplugins.quick_actions_kit

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Handler
import android.os.Looper
import androidx.annotation.Keep
import org.json.JSONArray
import org.json.JSONObject

/** No dependency on private framework view classes; independently archiveable. */
@Keep
object DNQuickActionsKitBridge {
    const val EXTRA_TYPE = "dev.dnplugins.quick_actions_kit.TYPE"
    const val ACTION_OPEN = "dev.dnplugins.quick_actions_kit.OPEN"
    private var context: Application? = null
    private var hostResumed = false
    private fun isHost(activity: Activity): Boolean = activity.componentName ==
        activity.packageManager.getLaunchIntentForPackage(activity.packageName)?.component
    private val lifecycle = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityResumed(activity: Activity) {
            if (isHost(activity)) {
                hostResumed = true
                main.post { flushPending() }
            }
        }
        override fun onActivityPaused(activity: Activity) {
            if (isHost(activity)) hostResumed = false
        }
        override fun onActivityCreated(activity: Activity, state: Bundle?) {}
        override fun onActivityStarted(activity: Activity) {}
        override fun onActivityStopped(activity: Activity) {}
        override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) {}
        override fun onActivityDestroyed(activity: Activity) {}
    }

    fun attach(app: Application) {
        if (context === app) return
        context?.unregisterActivityLifecycleCallbacks(lifecycle)
        context = app
        app.registerActivityLifecycleCallbacks(lifecycle)
    }
    private val main = Handler(Looper.getMainLooper())
    private val pending = ArrayDeque<String>()
    private var listening = false
    private var activeGeneration = -1L

    @JvmStatic external fun generation(): Long
    @JvmStatic external fun deliver(token: Long, kind: Int, payload: ByteArray): Boolean
    @JvmStatic external fun resetDispatcher()

    @JvmStatic fun initialize(newSession: Boolean) {
        activeGeneration = generation()
        if (newSession) listening = false
        else main.post { flushPending() }
    }

    fun detach() {
        listening = false
        context?.unregisterActivityLifecycleCallbacks(lifecycle)
        context = null
        hostResumed = false
        resetDispatcher()
    }

    fun receive(type: String) {
        check(Looper.myLooper() == Looper.getMainLooper())
        if (type.isBlank()) return
        // Wait for the host to resume before notifying Dart. Delivering from
        // the receiver can target a tree that the host is about to remount.
        if (pending.size == 32) pending.removeFirst()
        pending.addLast(type)
    }

    private fun flushPending() {
        if (!hostResumed || !listening || activeGeneration < 0 || activeGeneration != generation()) return
        while (pending.isNotEmpty()) {
            val type = pending.first()
            if (!deliver(0, 1, JSONObject.quote(type).toByteArray(Charsets.UTF_8))) break
            pending.removeFirst()
        }
    }

    @JvmStatic fun request(token: Long, bytes: ByteArray) {
        val requestGeneration = generation()
        val text = String(bytes, Charsets.UTF_8)
        main.post {
            if (requestGeneration != generation() || requestGeneration != activeGeneration) return@post
            try {
                val app = context ?: throw NativeFailure("engine_detached", "The engine is detached.")
                val request = JSONObject(text)
                when (request.getString("operation")) {
                    "listen" -> {
                        listening = true
                        reply(token)
                        flushPending()
                        return@post
                    }
                    "stop" -> listening = false
                    "clear" -> manager(app).removeAllDynamicShortcuts()
                    "set" -> setItems(app, request.getJSONArray("payload"))
                    else -> throw NativeFailure("invalid_operation", "Unknown operation.")
                }
                reply(token)
            } catch (failure: NativeFailure) {
                reply(token, failure.code, failure.message ?: "Operation failed.")
            } catch (_: Exception) {
                reply(token, "native_error", "The shortcut operation failed.")
            }
        }
    }

    private fun manager(app: Context): ShortcutManager =
        app.getSystemService(ShortcutManager::class.java)
            ?: throw NativeFailure("unavailable", "Shortcut service is unavailable.")

    private fun setItems(app: Context, items: JSONArray) {
        val service = manager(app)
        val launch = app.packageManager.getLaunchIntentForPackage(app.packageName)
            ?: throw NativeFailure("no_launcher", "The application has no launcher activity.")
        if (items.length() + service.manifestShortcuts.size > service.maxShortcutCountPerActivity) {
            throw NativeFailure("too_many_shortcuts", "The launcher shortcut limit would be exceeded.")
        }
        val ids = mutableSetOf<String>()
        val shortcuts = (0 until items.length()).map { index ->
            val item = items.getJSONObject(index)
            val type = item.getString("type")
            val title = item.getString("title")
            if (type.isBlank() || title.isBlank() || !ids.add(type)) {
                throw NativeFailure("invalid_shortcut", "Types must be unique and types/titles nonempty.")
            }
            val intent = Intent(app, QuickActionReceiverActivity::class.java)
                .setAction(ACTION_OPEN).putExtra(EXTRA_TYPE, type)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val builder = ShortcutInfo.Builder(app, type)
                .setShortLabel(title).setLongLabel(title).setRank(index)
                .setActivity(launch.component!!).setIntent(intent)
            if (!item.isNull("icon")) {
                val icon = item.getString("icon")
                var id = app.resources.getIdentifier(icon, "drawable", app.packageName)
                if (id == 0) id = app.resources.getIdentifier(icon, "mipmap", app.packageName)
                if (id != 0) builder.setIcon(Icon.createWithResource(app, id))
            }
            builder.build()
        }
        if (!service.setDynamicShortcuts(shortcuts)) {
            throw NativeFailure("rate_limited", "Android rejected the shortcut update; retry later.")
        }
    }

    private fun reply(token: Long, code: String? = null, message: String? = null) {
        val result = JSONObject()
        if (code != null) result.put("error", JSONObject().put("code", code).put("message", message))
        deliver(token, 0, result.toString().toByteArray(Charsets.UTF_8))
    }
    private class NativeFailure(val code: String, message: String): Exception(message)
}
