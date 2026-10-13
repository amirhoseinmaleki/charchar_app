package com.PardisSaz.game

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.PardisSaz.game/security"

    // Opt out of edge-to-edge: native overlay views (Tapsell's banner ad
    // among them) are pinned to the raw window edge with no inset/margin
    // API of their own, so an edge-to-edge window lets them land behind
    // the system navigation bar. Reserving the system bar space here keeps
    // the app's drawable area — and anything pinned to its bottom — above it.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isDeviceRooted") {
                result.success(checkRoot())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun checkRoot(): Boolean {
        return checkRootPaths() || checkSuBinary() || checkTestKeys()
    }

    private fun checkTestKeys(): Boolean {
        val buildTags = android.os.Build.TAGS
        return buildTags != null && buildTags.contains("test-keys")
    }

    private fun checkRootPaths(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/system/bin/.ext/.su",
            "/system/usr/we-need-root/su-backup",
            "/system/xbin/mu",
            "/system/xbin/daemonsu"
        )
        for (path in paths) {
            if (File(path).exists()) return true
        }
        return false
    }

    private fun checkSuBinary(): Boolean {
        var process: Process? = null
        return try {
            process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            val reader = java.io.BufferedReader(java.io.InputStreamReader(process.inputStream))
            reader.readLine() != null
        } catch (t: Throwable) {
            false
        } finally {
            process?.destroy()
        }
    }
}

