package com.carmen.pocket_claw

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by the
// local_auth plugin — the biometric prompt is implemented as an
// androidx.fragment.app.DialogFragment and needs a FragmentActivity
// host. FlutterFragmentActivity is Flutter's official subclass of it
// and is drop-in compatible with the normal FlutterActivity.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Device-info channel: Dart-side `DeviceMemoryService` calls
        // `getTotalRam` to gate model downloads on devices without
        // enough memory. ActivityManager.MemoryInfo.totalMem matches
        // what Android Settings shows the user, so the gate aligns
        // with their expectations.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.carmen.pocket_claw/device"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTotalRam" -> {
                    val activityManager =
                        getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val memInfo = ActivityManager.MemoryInfo()
                    activityManager.getMemoryInfo(memInfo)
                    result.success(memInfo.totalMem)
                }
                else -> result.notImplemented()
            }
        }
    }
}
