package com.filo.filo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.content.res.Configuration
import android.Manifest
import android.content.pm.PackageManager
import android.content.pm.ActivityInfo
import android.os.Build
import android.content.Intent
import android.provider.Settings
import android.view.MotionEvent
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    private var examProtected = false
    private var examObscured = false
    private var discardExamGesture = false

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        publishExamWindow()
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (examProtected) {
            val obscured = (event.flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED) != 0 ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                    (event.flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED) != 0)
            // shortcut: passive overlays may emit no event; Android 12+ also hides non-system overlays.
            if (event.actionMasked == MotionEvent.ACTION_DOWN) {
                discardExamGesture = obscured || examObscured || !hasWindowFocus() || isInMultiWindowMode
            }
            if (obscured != examObscured) {
                examObscured = obscured
                publishExamWindow()
            }
            if (obscured) discardExamGesture = true
            if (obscured || discardExamGesture) {
                val cancel = MotionEvent.obtain(event)
                cancel.action = MotionEvent.ACTION_CANCEL
                super.dispatchTouchEvent(cancel)
                cancel.recycle()
                return true
            }
        }
        return super.dispatchTouchEvent(event)
    }

    private var examWindowEvents: EventChannel.EventSink? = null
    private fun publishExamWindow() {
        examWindowEvents?.success(mapOf(
            "multi_window" to isInMultiWindowMode,
            "obscured" to (examProtected && (examObscured || !hasWindowFocus())),
            "overlay_supported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
        ))
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        publishExamWindow()
    }

    override fun onResume() {
        super.onResume()
        publishExamWindow()
    }

    private var lessonImages: LessonImageReader? = null
    private var examOrientation: Int? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.filo.filo/exam_window")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    examWindowEvents = events
                    publishExamWindow()
                }
                override fun onCancel(arguments: Any?) { examWindowEvents = null }
            })
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
                        val enabled = call.arguments == true
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) window.setHideOverlayWindows(enabled)
                        examProtected = enabled
                        if (!enabled) {
                            examObscured = false
                            discardExamGesture = false
                        }
                        if (enabled) {
                            if (examOrientation == null) examOrientation = requestedOrientation
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            examOrientation?.let { requestedOrientation = it }
                            examOrientation = null
                        }
                        publishExamWindow()
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
                if (call.method == "status") {
                    try {
                        result.success(getSystemService(android.app.NotificationManager::class.java).areNotificationsEnabled())
                    } catch (_: Exception) {
                        result.error("STATUS_UNAVAILABLE", "Could not check notification access", null)
                    }
                } else if (call.method == "openSettings") {
                    try {
                        startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                        result.success(null)
                    } catch (_: Exception) {
                        try {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                android.net.Uri.parse("package:$packageName")))
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("SETTINGS_UNAVAILABLE", "Could not open notification settings", null)
                        }
                    }
                } else if (call.method == "debugToken" &&
                    (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
                    com.google.firebase.messaging.FirebaseMessaging.getInstance().token
                        .addOnCompleteListener { task ->
                            if (task.isSuccessful) result.success(task.result)
                            else result.error("FCM_NATIVE_FAILURE", pushFailureSummary(task.exception), null)
                        }
                } else if (call.method != "request") {
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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && examProtected) runCatching { window.setHideOverlayWindows(false) }
        examWindowEvents = null
        lessonImages?.close()
        pendingPermission?.success(false)
        pendingPermission = null
        super.onDestroy()
    }
}
