// Copyright 2026 the quick_actions_kit contributors.
// SPDX-License-Identifier: Apache-2.0
package dev.dnplugins.quick_actions_kit

import android.app.Application
import io.flutter.embedding.engine.plugins.FlutterPlugin

/** JVM load must precede Dart's DynamicLibrary.open so JNI_OnLoad runs. */
class QuickActionsKitPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        DNQuickActionsKitBridge.attach(binding.applicationContext as Application)
        System.loadLibrary("quick_actions_kit")
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        DNQuickActionsKitBridge.detach()
    }
}
