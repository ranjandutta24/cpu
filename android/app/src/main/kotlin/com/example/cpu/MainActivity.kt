package com.example.cpu

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.BatteryManager
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
                    "getRunningApps" -> {
                        try {
                            result.success(buildRunningApps())
                        } catch (e: Exception) {
                            result.error("RUNNING_APPS_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── Running apps via ActivityManager ──────────────────────────────────────
    private fun buildRunningApps(): List<Map<String, Any?>> {
        val am  = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val pm  = packageManager
        val procs = am.runningAppProcesses ?: return emptyList()

        return procs
            .filter { it.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND_SERVICE }
            .mapNotNull { proc ->
                val pkg = proc.pkgList?.firstOrNull() ?: return@mapNotNull null
                val label = try {
                    val ai = pm.getApplicationInfo(pkg, 0)
                    pm.getApplicationLabel(ai).toString()
                } catch (_: PackageManager.NameNotFoundException) {
                    proc.processName ?: pkg
                }
                mapOf<String, Any?>(
                    "name"        to label,
                    "packageName" to pkg,
                )
            }
            .sortedBy { it["name"] as? String ?: "" }
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
