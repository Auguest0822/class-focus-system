package com.example.student_app

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * 学生端 App 使用时长追踪插件。
 *
 * 通过 Android 系统的 [UsageStatsManager] 查询学生在课堂期间离开学生端 App 后，
 * 在其他 App 中停留的时长（前台时间）。数据经 MethodChannel 传回 Dart 层上传后端。
 */
object AppUsagePlugin {
    const val CHANNEL = "com.example.student_app/usage"

    /** 需要在 Dart 层通过 MethodChannel 同步持有的 ApplicationContext */
    private lateinit var appContext: Context

    // ── 注册 MethodChannel ─────────────────────────────────────────
    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> result.success(isUsageStatsPermissionGranted())
                    "openUsageAccessSettings" -> {
                        openUsageAccessSettings()
                        result.success(true)
                    }

                    "queryUsageStats" -> {
                        val begin = call.argument<Long>("begin") ?: 0L
                        val end = call.argument<Long>("end") ?: System.currentTimeMillis()
                        result.success(queryUsageStats(begin, end))
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /** 在 MainActivity 中初始化 context（在 register 之前调用） */
    fun init(context: Context) {
        appContext = context.applicationContext
    }

    // ── 权限检查 ──────────────────────────────────────────────────
    /**
     * 通过 [AppOpsManager] 直接查询 PACKAGE_USAGE_STATS 权限是否已授予。
     *
     * 不能用 queryUsageStats 的返回值是否为空来判断——刚授权时短时间内
     * 确实没有使用数据，queryUsageStats 返回空列表会被误判为"无权限"。
     */
    fun isUsageStatsPermissionGranted(): Boolean {
        val appOps = appContext.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
            ?: return false
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            appContext.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        appContext.startActivity(intent)
    }

    // ── 查询使用统计 ──────────────────────────────────────────────
    /**
     * 通过 [UsageEvents] 查询 [begin] 到 [end] 毫秒之间各 App 的前台使用时长。
     *
     * UsageEvents 提供逐条事件（MOVE_TO_FOREGROUND / MOVE_TO_BACKGROUND），
     * 精度到毫秒，不会像 queryUsageStats 那样把整个时间 bucket 的数据都带回来。
     *
     * 返回每个 App 的：
     * - packageName: 包名
     * - appName: 应用显示名
     * - usageSeconds: 前台停留秒数
     * - startTime: 该 App 在查询范围内第一次切到前台的时间（ISO 8601）
     * - endTime: 该 App 在查询范围内最后一次切到后台的时间（ISO 8601）
     */
    fun queryUsageStats(begin: Long, end: Long): List<Map<String, Any?>> {
        val usm = appContext.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()

        val events: UsageEvents = usm.queryEvents(begin, end)
        val selfPackage = appContext.packageName
        val pm = appContext.packageManager

        // 按包名聚合：每个包记录 { foreground 开始时间, background 结束时间, 累计前台毫秒 }
        data class AppSession(
            var totalMs: Long = 0,
            var firstForeground: Long? = null,
            var lastBackground: Long? = null,
            var currentForegroundStart: Long? = null  // 当前是否在前台
        )

        val sessions = mutableMapOf<String, AppSession>()
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            if (pkg == selfPackage) continue
            if (isSystemPackage(pkg)) continue

            val session = sessions.getOrPut(pkg) { AppSession() }

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    session.currentForegroundStart = event.timeStamp
                    if (session.firstForeground == null) {
                        session.firstForeground = event.timeStamp
                    }
                }

                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    session.lastBackground = event.timeStamp
                    val start = session.currentForegroundStart
                    if (start != null) {
                        session.totalMs += (event.timeStamp - start)
                        session.currentForegroundStart = null
                    }
                }

                // ACTIVITY_PAUSED / ACTIVITY_STOPPED 当做切后台的辅助信号
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    // 只有在前台状态中的才计为结束
                    val start = session.currentForegroundStart
                    if (start != null) {
                        session.totalMs += (event.timeStamp - start)
                        session.currentForegroundStart = null
                        session.lastBackground = event.timeStamp
                    }
                }
            }
        }

        // 如果在查询窗口结束时仍在 foreground，计到窗口结束时间
        for ((_, session) in sessions) {
            val start = session.currentForegroundStart
            if (start != null) {
                session.totalMs += (end - start)
                session.lastBackground = end
                session.currentForegroundStart = null
            }
        }

        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }

        return sessions
            .mapNotNull { (pkg, session) ->
                val usageSeconds = (session.totalMs / 1000).toInt()
                if (usageSeconds < 1) return@mapNotNull null

                val appName = try {
                    val appInfo = pm.getApplicationInfo(pkg, 0)
                    pm.getApplicationLabel(appInfo).toString()
                } catch (_: PackageManager.NameNotFoundException) {
                    pkg
                }

                mapOf(
                    "packageName" to pkg,
                    "appName" to appName,
                    "usageSeconds" to usageSeconds,
                    "startTime" to session.firstForeground?.let { isoFormat.format(Date(it)) },
                    "endTime" to session.lastBackground?.let { isoFormat.format(Date(it)) },
                )
            }
            .sortedByDescending { it["usageSeconds"] as? Int ?: 0 }
    }

    private fun isSystemPackage(pkg: String): Boolean {
        return pkg.startsWith("com.android.") ||
                pkg == "android" ||
                pkg.startsWith("com.google.android.") ||
                pkg == "com.android.systemui"
    }
}
