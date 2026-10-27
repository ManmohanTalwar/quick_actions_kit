// Copyright 2026 the quick_actions_kit contributors.
// SPDX-License-Identifier: Apache-2.0
package dev.dnplugins.quick_actions_kit

import android.app.Activity
import android.content.Intent
import android.content.pm.ShortcutManager
import android.os.Bundle

/**
 * A launcher entry point, not an authorization boundary. It stores a cold tap
 * before the engine exists and forwards to the host's normal launcher activity.
 * This uses public Android APIs rather than a private DN activity dependency.
 */
class QuickActionReceiverActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            val type = intent?.takeIf { it.action == DNQuickActionsKitBridge.ACTION_OPEN }
                ?.getStringExtra(DNQuickActionsKitBridge.EXTRA_TYPE)
            if (!type.isNullOrBlank()) {
                DNQuickActionsKitBridge.receive(type)
                getSystemService(ShortcutManager::class.java)?.reportShortcutUsed(type)
            }
            packageManager.getLaunchIntentForPackage(packageName)?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                startActivity(it)
            }
        } finally {
            finish() // NoDisplay activities must finish before onResume.
        }
    }
}
