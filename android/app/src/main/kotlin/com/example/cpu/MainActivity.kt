package com.example.cpu

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.BatteryManager
import android.provider.Settings
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.cpu/native_stats"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getNativeStats" -> {
                        try {
                            result.success(buildStatsMap())
                        } catch (e: Exception) {
                            result.error("STATS_ERROR", e.message, null)
                        }
                    }
                    "getRunningApps" -> {
                        try {
                            if (!hasUsageAccessPermission()) {
                                result.success(mutableListOf<Map<String, Any?>>()) // Return empty
                            } else {
                                result.success(buildRunningApps())
                            }
                        } catch (e: Exception) {
                            result.error("RUNNING_APPS_ERROR", e.message, null)
                        }
                    }
                    "hasUsagePermission" -> {
                        result.success(hasUsageAccessPermission())
                    }
                    "openUsageSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── Check Usage Permission ──────────────────────────────────────────────
    private fun hasUsageAccessPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // ── Running apps via UsageStatsManager ────────────────────────────────────
    private fun buildRunningApps(): List<Map<String, Any?>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm  = packageManager
        
        // Query for last 30 minutes
        val endTime = System.currentTimeMillis()
        val startTime = endTime - (120 * 60 * 1000) // 120 minutes
        
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, startTime, endTime)
        if (stats == null || stats.isEmpty()) {
            return emptyList()
        }

        return stats
            .filter { it.totalTimeInForeground > 0 || it.lastTimeUsed > startTime }
            .sortedByDescending { it.lastTimeUsed }
            .distinctBy { it.packageName }
            .take(15) 
            .mapNotNull { stat ->
                val pkg = stat.packageName
                if (pkg == packageName) return@mapNotNull null

                try {
                    val ai = pm.getApplicationInfo(pkg, 0)
                    val label = pm.getApplicationLabel(ai).toString()
                    val icon  = getAppIconAsBytes(pm.getApplicationIcon(ai))

                    mapOf<String, Any?>(
                        "name"        to label,
                        "packageName" to pkg,
                        "icon"        to icon,
                        "lastUsed"    to stat.lastTimeUsed
                    )
                } catch (_: PackageManager.NameNotFoundException) {
                    null
                }
            }
    }

    private fun getAppIconAsBytes(drawable: Drawable): ByteArray? {
        try {
            val bitmap = if (drawable is BitmapDrawable) {
                drawable.bitmap
            } else {
                val b = Bitmap.createBitmap(
                    max(1, drawable.intrinsicWidth),
                    max(1, drawable.intrinsicHeight),
                    Bitmap.Config.ARGB_8888
                )
                val canvas = Canvas(b)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                b
            }
            
            // Resize for performance
            val scaled = Bitmap.createScaledBitmap(bitmap, 64, 64, true)
            val stream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.PNG, 80, stream)
            return stream.toByteArray()
        } catch (_: Exception) {
            return null
        }
    }

    private fun buildStatsMap(): Map<String, Any> {
        val cpuTemp   = readCpuTemperature()
        val currentMa = readBatteryCurrent()
        val ramInfo   = readRamInfo()

        return mapOf(
            "cpuTemp"    to cpuTemp,
            "currentMa"  to currentMa,
            "totalRamMb" to ramInfo.first,
            "usedRamMb"  to ramInfo.second,
            "freeRamMb"  to ramInfo.third,
        )
    }

    // ── Battery current (mA) ───────────────────────────────────────────────
    // Strategy:
    //  1. BatteryManager.BATTERY_PROPERTY_CURRENT_NOW  (API 21+, µA, most reliable)
    //  2. sysfs /sys/class/power_supply/battery/current_now (µA fallback)
    //
    // Sign convention we RETURN (positive = charging, negative = discharging):
    //  BatteryManager already uses this convention.
    //  For sysfs we normalise using the charging state.
    private fun readBatteryCurrent(): Int {
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager

        // ── 1. BatteryManager API ─────────────────────────────────────────
        try {
            val microAmps = bm.getLongProperty(
                BatteryManager.BATTERY_PROPERTY_CURRENT_NOW
            )
            if (microAmps != Long.MIN_VALUE) {           // MIN_VALUE = "not supported"
                return (microAmps / 1000L).toInt()       // µA → mA
            }
        } catch (_: Exception) {}

        // ── 2. sysfs fallback ─────────────────────────────────────────────
        val paths = listOf(
            "/sys/class/power_supply/battery/current_now",
            "/sys/class/power_supply/Battery/current_now",
        )
        for (path in paths) {
            try {
                val raw = File(path).readText().trim().toLongOrNull() ?: continue
                val mA  = (raw / 1000L).toInt()
                // Normalise sign: some OEMs report positive when discharging
                val isCharging = bm.isCharging
                return if (isCharging && mA < 0) -mA   // flip if sign wrong
                       else if (!isCharging && mA > 0) -mA
                       else mA
            } catch (_: Exception) {}
        }
        return 0
    }

    // ── CPU temperature ────────────────────────────────────────────────────
    private fun readCpuTemperature(): Double {
        val paths = listOf(
            "/sys/class/thermal/thermal_zone0/temp",
            "/sys/class/thermal/thermal_zone1/temp",
            "/sys/devices/virtual/thermal/thermal_zone0/temp",
        )
        for (path in paths) {
            try {
                val raw = File(path).readText().trim().toLongOrNull() ?: continue
                return if (raw > 1000) raw / 1000.0 else raw.toDouble()
            } catch (_: Exception) {}
        }
        return -1.0
    }

    // ── RAM info via ActivityManager ───────────────────────────────────────
    private fun readRamInfo(): Triple<Long, Long, Long> {
        val am   = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        val totalMb = info.totalMem / 1024 / 1024
        val freeMb  = info.availMem / 1024 / 1024
        val usedMb  = totalMb - freeMb
        return Triple(totalMb, usedMb, freeMb)
    }
}

private data class Triple<A, B, C>(val first: A, val second: B, val third: C)
