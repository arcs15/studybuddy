package com.studybuddy.studybuddy

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Reads the SMS inbox for the "Import from SMS" feature. Nothing leaves the phone. */
class MainActivity : FlutterActivity() {
    private val channelName = "arcx/sms"
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "readSms") {
                    if (hasPermission()) {
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
    }

    private fun hasPermission(): Boolean {
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
