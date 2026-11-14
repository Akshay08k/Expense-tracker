package com.personal.expensetracker.expense_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.regex.Pattern

class PaymentNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "FinFlowPaymentListener"
        private const val CHANNEL_ID = "finflow_payment_detected"
        private const val CHANNEL_NAME = "Detected Payments"
        private const val NOTIFICATION_ID = 9001

        // Whitelisted payment & banking app package names in India/Global
        val SUPPORTED_PACKAGES = mapOf(
            "com.google.android.apps.nbu.paisa.user" to "Google Pay",
            "com.phonepe.app" to "PhonePe",
            "net.one97.paytm" to "Paytm",
            "in.org.npci.upiapp" to "BHIM",
            "com.cred.club" to "CRED",
            "in.amazon.mShop.android.shopping" to "Amazon Pay",
            "com.sbi.upi" to "SBI UPI",
            "com.csam.icici.bank.imobile" to "iMobile ICICI",
            "com.hdfcbank.payzapp" to "PayZapp HDFC",
            "com.axis.mobile" to "Axis Mobile",
            "com.msf.kopl" to "Kotak Bank"
        )
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "PaymentNotificationListenerService created")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        // 1. FAST FILTER: Ignore 99.9% of unrelated notifications instantly (Zero Battery Drain)
        if (!SUPPORTED_PACKAGES.containsKey(packageName)) {
            return
        }

        val appName = SUPPORTED_PACKAGES[packageName] ?: "UPI App"
        val extras = sbn.notification?.extras ?: return

        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""

        val fullText = "$title $text $bigText".trim()
        Log.d(TAG, "Processing notification from $appName: $fullText")

        // 2. Parse Amount and Payee/Merchant using Regex
        val parsed = parseTransaction(fullText, title, text, appName) ?: return

        Log.d(TAG, "Successfully parsed transaction: Amount=${parsed.amount}, Payee=${parsed.payee}, App=${parsed.sourceApp}")

        // 3. Notify Flutter if app is active in foreground
        val paymentData = hashMapOf<String, Any>(
            "amount" to parsed.amount,
            "title" to parsed.payee,
            "sourceApp" to parsed.sourceApp,
            "timestamp" to parsed.timestamp,
            "rawText" to fullText
        )

        val handledInForeground = MainActivity.notifyPaymentIfActive(paymentData)

        // 4. If app is in background or closed, show a high-priority heads-up prompt notification
        if (!handledInForeground) {
            MainActivity.pendingPaymentData = paymentData
            showDetectedNotification(parsed)
        }
    }

    data class ParsedPayment(
        val amount: Double,
        val payee: String,
        val sourceApp: String,
        val timestamp: Long
    )

    private fun parseTransaction(fullText: String, title: String, text: String, appName: String): ParsedPayment? {
        val lower = fullText.lowercase()

        // Ignore OTP, login, promotional, or non-debit alerts
        if (lower.contains("otp") || lower.contains("login") || lower.contains("code") ||
            lower.contains("cashback received") || lower.contains("offers")) {
            return null
        }

        // Must indicate a payment, debit, or sent transaction
        val isPayment = lower.contains("paid") || lower.contains("sent") ||
                lower.contains("debited") || lower.contains("successful") ||
                lower.contains("transfer to") || lower.contains("payment to") ||
                lower.contains("spent")

        if (!isPayment) {
            return null
        }

        // Regex for Amount: Matches ₹ 120, INR 1,250.50, Rs. 450, etc.
        val amountPattern = Pattern.compile(
            "(?:(?:₹|rs\\.?|inr|paid|debited by|debited for)\\s*[:.]?\\s*([0-9,]+(?:\\.[0-9]{1,2})?))",
            Pattern.CASE_INSENSITIVE
        )
        val amountMatcher = amountPattern.matcher(fullText)

        var amount: Double? = null
        if (amountMatcher.find()) {
            val rawAmt = amountMatcher.group(1)?.replace(",", "")
            amount = rawAmt?.toDoubleOrNull()
        }

        // Fallback for amounts directly preceding currency: "150.00 paid" or "500 debited"
        if (amount == null) {
            val fallbackPattern = Pattern.compile("([0-9,]+(?:\\.[0-9]{1,2})?)\\s*(?:₹|rs\\.?|inr)", Pattern.CASE_INSENSITIVE)
            val fallbackMatcher = fallbackPattern.matcher(fullText)
            if (fallbackMatcher.find()) {
                val rawAmt = fallbackMatcher.group(1)?.replace(",", "")
                amount = rawAmt?.toDoubleOrNull()
            }
        }

        if (amount == null || amount <= 0.0) {
            return null
        }

        // Regex for Payee/Merchant Name
        var payee = "Payment via $appName"
        val payeePattern = Pattern.compile(
            "(?:(?:to|at|for|paid to|sent to)\\s+([A-Za-z0-9 &._'-]{2,30}?)(?:\\s+successful|\\s+using|\\s+on|\\s+at|\\s+from|\\.|,|$))",
            Pattern.CASE_INSENSITIVE
        )
        val payeeMatcher = payeePattern.matcher(fullText)

        if (payeeMatcher.find()) {
            val extracted = payeeMatcher.group(1)?.trim()
            if (!extracted.isNullOrBlank() && extracted.length > 1 && !extracted.equals("you", ignoreCase = true)) {
                payee = cleanPayeeName(extracted)
            }
        } else if (title.isNotBlank() && !title.equals(appName, ignoreCase = true) && !title.contains("paid", ignoreCase = true)) {
            payee = cleanPayeeName(title)
        }

        return ParsedPayment(
            amount = amount,
            payee = payee,
            sourceApp = appName,
            timestamp = System.currentTimeMillis()
        )
    }

    private fun cleanPayeeName(name: String): String {
        return name
            .replace(Regex("(?i)^(the|m/s|vpa)\\s+"), "")
            .trim()
            .split(" ")
            .joinToString(" ") { word ->
                if (word.isNotEmpty()) word.substring(0, 1).uppercase() + word.substring(1).lowercase() else ""
            }
    }

    private fun showDetectedNotification(payment: ParsedPayment) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("is_payment_detected", true)
            putExtra("amount", payment.amount)
            putExtra("title", payment.payee)
            putExtra("source_app", payment.sourceApp)
            putExtra("timestamp", payment.timestamp)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            (System.currentTimeMillis() % 10000).toInt(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val formattedAmount = if (payment.amount % 1.0 == 0.0) {
            payment.amount.toInt().toString()
        } else {
            String.format("%.2f", payment.amount)
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Payment Detected: ₹$formattedAmount")
            .setContentText("Paid to ${payment.payee} via ${payment.sourceApp}. Tap to record.")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("Detected ₹$formattedAmount paid to ${payment.payee}. Tap to categorize and save in FinFlow."))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifies you when a UPI or card payment is detected so you can record it in 1 tap"
                enableVibration(true)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}

