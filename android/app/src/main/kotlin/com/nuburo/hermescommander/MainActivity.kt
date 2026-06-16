package com.nuburo.hermescommander

import android.app.ActivityManager
import android.app.PictureInPictureParams
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.util.Rational
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by the
// local_auth plugin — the biometric prompt is implemented as an
// androidx.fragment.app.DialogFragment and needs a FragmentActivity
// host. FlutterFragmentActivity is Flutter's official subclass of it
// and is drop-in compatible with the normal FlutterActivity.
class MainActivity : FlutterFragmentActivity() {
    private var autoEnterPip = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Device-info channel: Dart-side `DeviceMemoryService` calls
        // `getTotalRam` to gate model downloads on devices without
        // enough memory. ActivityManager.MemoryInfo.totalMem matches
        // what Android Settings shows the user, so the gate aligns
        // with their expectations.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.nuburo.hermescommander/device"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTotalRam" -> {
                    val activityManager =
                        getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val memInfo = ActivityManager.MemoryInfo()
                    activityManager.getMemoryInfo(memInfo)
                    result.success(memInfo.totalMem)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager =
                        getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.nuburo.hermescommander/tv"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPipSupported" -> result.success(isPipSupported())
                "setAutoPip" -> {
                    autoEnterPip = call.argument<Boolean>("enabled") == true
                    result.success(null)
                }
                "enterPip" -> {
                    val width = call.argument<Int>("width") ?: 16
                    val height = call.argument<Int>("height") ?: 9
                    result.success(enterTvPip(width, height))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onUserLeaveHint() {
        if (autoEnterPip) {
            enterTvPip(16, 9)
        }
        super.onUserLeaveHint()
    }

    private fun isPipSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun enterTvPip(width: Int, height: Int): Boolean {
        if (!isPipSupported()) return false

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val safeWidth = width.coerceIn(1, 239)
                val safeHeight = height.coerceIn(1, 239)
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(safeWidth, safeHeight))
                    .build()
                enterPictureInPictureMode(params)
            } else {
                false
            }
        } catch (_: Throwable) {
            false
        }
    }
}
