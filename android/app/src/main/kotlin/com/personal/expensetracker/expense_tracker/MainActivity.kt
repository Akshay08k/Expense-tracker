package com.personal.expensetracker.expense_tracker

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.finflow/payment_detector"
        var activeInstance: MainActivity? = null
        var pendingPaymentData: Map<String, Any>? = null

        fun notifyPaymentIfActive(data: Map<String, Any>): Boolean {
            val instance = activeInstance ?: return false
            val channel = instance.methodChannel ?: return false
            instance.runOnUiThread {
                channel.invokeMethod("onPaymentDetected", data)
            }
            return true
        }
    }

    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activeInstance = this
        extractPaymentFromIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        activeInstance = this
    }

    override fun onPause() {
        super.onPause()
        if (activeInstance == this) {
            activeInstance = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (activeInstance == this) {
            activeInstance = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractPaymentFromIntent(intent)
        pendingPaymentData?.let { data ->
            methodChannel?.invokeMethod("onPaymentDetected", data)
        }
    }

    private fun extractPaymentFromIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.getBooleanExtra("is_payment_detected", false)) {
            val amount = intent.getDoubleExtra("amount", 0.0)
            val title = intent.getStringExtra("title") ?: "Payment"
            val sourceApp = intent.getStringExtra("source_app") ?: "UPI"
            val isIncome = intent.getBooleanExtra("is_income", false)
            val timestamp = intent.getLongExtra("timestamp", System.currentTimeMillis())

            if (amount > 0.0) {
                pendingPaymentData = hashMapOf(
                    "amount" to amount,
                    "title" to title,
                    "sourceApp" to sourceApp,
                    "isIncome" to isIncome,
                    "timestamp" to timestamp
                )
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationPermissionGranted" -> {
                    result.success(isNotificationServiceEnabled(context))
                }
                "openNotificationSettings" -> {
                    openNotificationSettings(context)
                    result.success(true)
                }
                "getPendingPayment" -> {
                    val data = pendingPaymentData
                    pendingPaymentData = null // clear once read
                    result.success(data)
                }
                "simulatePaymentNotification" -> {
                    val amount = (call.argument<Number>("amount"))?.toDouble() ?: 150.0
                    val payee = call.argument<String>("payee") ?: "Starbucks Coffee"
                    val appName = call.argument<String>("sourceApp") ?: "Google Pay"
                    val isIncome = call.argument<Boolean>("isIncome") ?: false

                    val dummyData = hashMapOf<String, Any>(
                        "amount" to amount,
                        "title" to payee,
                        "sourceApp" to appName,
                        "isIncome" to isIncome,
                        "timestamp" to System.currentTimeMillis()
                    )

                    pendingPaymentData = dummyData
                    methodChannel?.invokeMethod("onPaymentDetected", dummyData)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isNotificationServiceEnabled(context: Context): Boolean {
        val packageName = context.packageName
        val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
        if (!flat.isNullOrEmpty()) {
            val names = flat.split(":".toRegex()).toTypedArray()
            for (name in names) {
                val cn = ComponentName.unflattenFromString(name)
                if (cn != null && cn.packageName == packageName) {
                    return true
                }
            }
        }
        return false
    }

    private fun openNotificationSettings(context: Context) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        } else {
            Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }
}
