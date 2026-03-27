package com.example.cpu

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
                    else -> result.notImplemented()
                }
            }
    }

    private fun buildStatsMap(): Map<String, Any> {
        val cpuTemp = readCpuTemperature()
        val currentMa = readBatteryCurrent()
        val ramInfo = readRamInfo()

        return mapOf(
            "cpuTemp"    to cpuTemp,
            "currentMa"  to currentMa,
            "totalRamMb" to ramInfo.first,
            "usedRamMb"  to ramInfo.second,
            "freeRamMb"  to ramInfo.third,
        )
    }

    // ── CPU temperature ────────────────────────────────────────────────────────
    private fun readCpuTemperature(): Double {
        // Try common sysfs thermal zone paths
        val paths = listOf(
            "/sys/class/thermal/thermal_zone0/temp",
            "/sys/class/thermal/thermal_zone1/temp",
            "/sys/devices/virtual/thermal/thermal_zone0/temp",
        )
        for (path in paths) {
            try {
                val raw = File(path).readText().trim().toLongOrNull() ?: continue
                // Values > 1000 are in milli-degrees Celsius
                return if (raw > 1000) raw / 1000.0 else raw.toDouble()
            } catch (_: Exception) {}
        }
        return -1.0 // unavailable
    }

    // ── Battery current (mA) ───────────────────────────────────────────────────
    // Positive = charging, Negative = discharging (sign may vary by OEM)
    private fun readBatteryCurrent(): Int {
        val paths = listOf(
            "/sys/class/power_supply/battery/current_now",
            "/sys/class/power_supply/Battery/current_now",
        )
        for (path in paths) {
            try {
                val raw = File(path).readText().trim().toLongOrNull() ?: continue
                // Values are in µA on most devices → convert to mA
                return (raw / 1000).toInt()
            } catch (_: Exception) {}
        }
        return 0
    }

    // ── RAM info via ActivityManager ───────────────────────────────────────────
    // Returns Triple(totalMb, usedMb, freeMb)
    private fun readRamInfo(): Triple<Long, Long, Long> {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        val totalMb = info.totalMem / 1024 / 1024
        val freeMb  = info.availMem / 1024 / 1024
        val usedMb  = totalMb - freeMb
        return Triple(totalMb, usedMb, freeMb)
    }
}

// Simple Triple helper (Kotlin stdlib Triple is fine, but explicit for clarity)
private data class Triple<A, B, C>(val first: A, val second: B, val third: C)
