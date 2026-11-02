package com.studybuddy.studybuddy

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Native bridge: SMS inbox, reminders (notifications) and the home screen widget. Nothing leaves the phone. */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "arcx/sms").setMethodCallHandler { call, result ->
            if (call.method == "readSms") {
                if (hasSmsPermission()) {
                    result.success(readSms())
                } else if (Build.VERSION.SDK_INT >= 23) {
                    pending = result
                    requestPermissions(arrayOf(Manifest.permission.READ_SMS), 77)
                } else {
                    result.success(readSms())
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(messenger, "arcx/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotifPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 78)
                    }
                    result.success(true)
                }
                "scheduleReminders" -> {
                    val items = call.arguments as? List<*> ?: emptyList<Any>()
                    Reminders.replaceAll(applicationContext, items)
                    result.success(true)
                }
                "testReminder" -> {
                    Reminders.scheduleOne(
                        applicationContext, 999999, System.currentTimeMillis() + 10000,
                        "StudyBuddy test", "Reminders are working! ✅"
                    )
                    result.success(true)
                }
                "updateWidget" -> {
                    val m = call.arguments as? Map<*, *>
                    if (m != null) {
                        StudyWidget.save(
                            applicationContext,
                            (m["title"] as? String) ?: "StudyBuddy",
                            (m["big"] as? String) ?: "",
                            (m["line"] as? String) ?: ""
                        )
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasSmsPermission(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true
        return checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 77) {
            val r = pending
            pending = null
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                r?.success(readSms())
            } else {
                r?.error("DENIED", "SMS permission denied", null)
            }
        }
    }

    private fun readSms(): List<Map<String, Any?>> {
        val list = ArrayList<Map<String, Any?>>()
        val cursor = contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf("_id", "address", "body", "date"),
            null, null, "date DESC"
        )
        cursor?.use { c ->
            var n = 0
            while (c.moveToNext() && n < 400) {
                list.add(
                    mapOf(
                        "id" to c.getLong(0),
                        "address" to c.getString(1),
                        "body" to c.getString(2),
                        "date" to c.getLong(3)
                    )
                )
                n++
            }
        }
        return list
    }
}
