package com.jegan.money_manager_app

import android.Manifest
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val SMS_CHANNEL = "com.jegan.money_manager_app/sms"
    private val SMS_PERMISSION_CODE = 1001

    // Pending result to send back after permission grant
    private var pendingResult: MethodChannel.Result? = null
    private var pendingDaysBack: Int = 30

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readBankSms" -> {
                        val daysBack = call.argument<Int>("daysBack") ?: 30
                        if (hasSmsPermission()) {
                            val messages = readSms(daysBack)
                            result.success(messages)
                        } else {
                            pendingResult = result
                            pendingDaysBack = daysBack
                            requestSmsPermission()
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_SMS),
            SMS_PERMISSION_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_CODE) {
            val result = pendingResult ?: return
            pendingResult = null
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                result.success(readSms(pendingDaysBack))
            } else {
                result.error("PERMISSION_DENIED", "SMS permission was denied", null)
            }
        }
    }

    private fun readSms(daysBack: Int): List<Map<String, Any>> {
        val messages = mutableListOf<Map<String, Any>>()
        val cutoff = System.currentTimeMillis() - (daysBack.toLong() * 24 * 60 * 60 * 1000)

        // Bank sender keywords to filter
        val bankKeywords = listOf(
            "HDFCBK", "HDFC", "ICICIB", "ICICI", "SBIINB", "SBI",
            "KOTAKB", "KOTAK", "AXISBK", "AXIS", "YESBK", "YESBNK",
            "INDBNK", "IDFCBK", "FEDBK", "CANBNK", "PNBSMS", "BOISMS",
            "GPAY", "PHONEPE", "PAYTM"
        )

        try {
            val uri = Uri.parse("content://sms/inbox")
            val projection = arrayOf("address", "body", "date")
            val selection = "date > ?"
            val selectionArgs = arrayOf(cutoff.toString())
            val sortOrder = "date DESC"

            val cursor: Cursor? = contentResolver.query(
                uri, projection, selection, selectionArgs, sortOrder
            )

            cursor?.use {
                val addressIdx = it.getColumnIndex("address")
                val bodyIdx = it.getColumnIndex("body")
                val dateIdx = it.getColumnIndex("date")

                while (it.moveToNext() && messages.size < 500) {
                    val address = it.getString(addressIdx) ?: continue
                    val body = it.getString(bodyIdx) ?: continue
                    val date = it.getLong(dateIdx)

                    // Filter: only bank messages
                    val addrUpper = address.uppercase().replace("-", "").replace(" ", "")
                    val isBankSender = bankKeywords.any { kw -> addrUpper.contains(kw) }
                    val isBankBody = body.contains(Regex(
                        "(?:debited|credited|INR|Rs\\.|transaction|account|a/c)",
                        RegexOption.IGNORE_CASE
                    ))

                    if (isBankSender || isBankBody) {
                        messages.add(mapOf(
                            "sender" to address,
                            "body" to body,
                            "timestamp" to date
                        ))
                    }
                }
            }
        } catch (e: Exception) {
            // Return empty list if SMS reading fails
        }
        return messages
    }
}