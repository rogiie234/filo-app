package com.filo.filo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.pm.PackageManager
import android.content.pm.ActivityInfo
import android.os.Build
import android.content.Intent
import android.provider.Settings
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    private var lessonImages: LessonImageReader? = null
    private var examOrientation: Int? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val reader = LessonImageReader(applicationContext)
        lessonImages = reader
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.filo.filo/lesson_image")
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (call.method == "prepare" && path != null) reader.prepare(path, result)
                else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.filo.filo/exam")
            .setMethodCallHandler { call, result ->
                if (call.method != "protect" || call.arguments !is Boolean) {
                    result.notImplemented()
                } else {
                    try {
                        if (call.arguments == true) {
                            if (examOrientation == null) examOrientation = requestedOrientation
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            examOrientation?.let { requestedOrientation = it }
                            examOrientation = null
                        }
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("EXAM_PROTECTION_FAILED", "Could not protect exam screen", null)
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.filo.filo/device_time")
            .setMethodCallHandler { call, result ->
                if (call.method != "openSettings") {
                    result.notImplemented()
                } else {
                    try {
                        startActivity(Intent(Settings.ACTION_DATE_SETTINGS))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("SETTINGS_UNAVAILABLE", "Open Date & time in your phone Settings", null)
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.filo.filo/storage")
            .setMethodCallHandler { call, result ->
                if (call.method == "freeBytes") {
                    try {
                        result.success(android.os.StatFs(filesDir.absolutePath).availableBytes)
                    } catch (error: Exception) {
                        result.error("SPACE_UNKNOWN", "Cannot read available storage", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.filo.filo/notifications")
            .setMethodCallHandler { call, result ->
                if (call.method != "request") {
                    result.notImplemented()
                } else if (Build.VERSION.SDK_INT < 33 ||
                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                } else if (pendingPermission != null) {
                    result.error("BUSY", "Permission request already open", null)
                } else {
                    pendingPermission = result
                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 301)
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 301) {
            pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            pendingPermission = null
        }
    }

    override fun onDestroy() {
        lessonImages?.close()
        pendingPermission?.success(false)
        pendingPermission = null
        super.onDestroy()
    }
}
