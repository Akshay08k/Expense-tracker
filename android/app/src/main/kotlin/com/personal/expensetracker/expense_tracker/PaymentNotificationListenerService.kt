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

        // Whitelisted payment, banking, and transactional notification apps
        val SUPPORTED_PACKAGES = mapOf(
            // Primary UPI Apps
            "com.google.android.apps.nbu.paisa.user" to "Google Pay",
            "com.phonepe.app" to "PhonePe",
            "net.one97.paytm" to "Paytm",
            "in.org.npci.upiapp" to "BHIM UPI",
            "com.cred.club" to "CRED",
            "in.amazon.mShop.android.shopping" to "Amazon Pay",

            // Bank of Baroda (BOB)
            "com.bankofbaroda.upi" to "BHIM Baroda Pay",
            "com.ibspl.bobworld" to "bob World",
            "com.baroda.mconnect" to "BOB mConnect",

            // Major Banks
            "com.sbi.upi" to "BHIM SBI Pay",
            "com.sbi.lotusintouch" to "SBI YONO",
            "com.csam.icici.bank.imobile" to "iMobile ICICI",
            "com.hdfcbank.payzapp" to "PayZapp HDFC",
            "com.snapwork.hdfc" to "HDFC MobileBanking",
            "com.axis.mobile" to "Axis Mobile",
            "com.upi.axispay" to "BHIM Axis Pay",
            "com.msf.kopl" to "Kotak Bank",
            "com.canarabank.mobility" to "Canara Bank",
            "com.pnb.upi" to "BHIM PNB",
            "com.unionbank.ecommerce.mobile.android" to "Union Bank",
            "com.idfcfirstbank.optimus" to "IDFC First",
            "money.jupiter" to "Jupiter",
            "co.fi.money" to "Fi Money",

            // Truecaller (Smart Payment / UPI notification)
            "com.truecaller" to "Truecaller Pay",

            // Default Messaging Apps (For Bank Debit SMS like BOBSMS - No READ_SMS permission needed!)
            "com.google.android.apps.messaging" to "Bank SMS",
            "com.samsung.android.messaging" to "Bank SMS",
            "com.android.mms" to "Bank SMS",
            "com.oneplus.mms" to "Bank SMS"
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

        // 1. FAST FILTER: Only inspect whitelisted packages (Zero Battery Drain)
        if (!SUPPORTED_PACKAGES.containsKey(packageName)) {
            return
        }

        val appName = SUPPORTED_PACKAGES[packageName] ?: "UPI App"
        val extras = sbn.notification?.extras ?: return

        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""
        val subText = extras.getCharSequence("android.subText")?.toString() ?: ""
        val infoText = extras.getCharSequence("android.infoText")?.toString() ?: ""

        val fullText = "$title $text $bigText $subText $infoText".trim()
        Log.d(TAG, "Processing notification from $appName ($packageName): $fullText")

        // 2. Parse Amount and Payee/Merchant using enhanced Regex
        val parsed = parseTransaction(fullText, title, text, appName, packageName) ?: return

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

    private fun parseTransaction(
        fullText: String,
        title: String,
        text: String,
        appName: String,
        packageName: String
    ): ParsedPayment? {
        val lower = fullText.lowercase()

        // Ignore OTP, login, password, or non-transaction alerts
        if (lower.contains("otp") || lower.contains("login") || lower.contains("code") ||
            lower.contains("secret") || lower.contains("password") ||
            lower.contains("cashback received") || lower.contains("offers")
        ) {
            return null
        }

        // For SMS messaging apps: Ensure it's from a bank/financial sender or has transaction keywords
        val isMessagingApp = packageName.contains("messaging") || packageName.contains("mms")
        if (isMessagingApp) {
            val isBankSender = title.matches(Regex("(?i).*(bob|sbi|hdfc|icici|axis|kotak|pnb|canara|union|idfc|paytm|upi|sms|alert|bank|citi|rbl|indus|yesb|bop|baroda).*"))
            val hasDebitIndicator = lower.contains("dr.") || lower.contains("dr ") ||
                    lower.contains("debited") || lower.contains("withdrawn") ||
                    lower.contains("spent") || lower.contains("paid") || lower.contains("cr. to")
            if (!isBankSender && !hasDebitIndicator) {
                return null // Instantly drop non-banking personal SMS from friends
            }
        }

        // Must indicate a payment, debit, transfer, OR have currency symbol with a payee
        val hasDebitKeyword = lower.contains("paid") || lower.contains("sent") ||
                lower.contains("debited") || lower.contains("successful") ||
                lower.contains("transfer to") || lower.contains("payment to") ||
                lower.contains("spent") || lower.contains("dr.") || lower.contains("dr ") ||
                lower.contains("cr. to") || lower.contains("cr to")

        val hasCurrencySymbol = fullText.contains("₹") || lower.contains("rs.") || lower.contains("rs ") || lower.contains("inr")

        if (!hasDebitKeyword && !hasCurrencySymbol) {
            return null
        }

        // Regex for Amount: Handles Rs.10.00, Rs 10, ₹10, INR 1,250.50, Paid 10, etc.
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

        // Fallback: [number] ₹ / Rs
        if (amount == null) {
            val fallbackPattern = Pattern.compile(
                "([0-9,]+(?:\\.[0-9]{1,2})?)\\s*(?:₹|rs\\.?|inr)",
                Pattern.CASE_INSENSITIVE
            )
            val fallbackMatcher = fallbackPattern.matcher(fullText)
            if (fallbackMatcher.find()) {
                val rawAmt = fallbackMatcher.group(1)?.replace(",", "")
                amount = rawAmt?.toDoubleOrNull()
            }
        }

        if (amount == null || amount <= 0.0) {
            return null
        }

        // Extract Payee / Merchant / VPA
        var payee = ""

        // Pattern 1: Cr. to <payee> (very common in Indian Bank SMS like BOBSMS)
        val crToPattern = Pattern.compile(
            "(?:(?:cr\\.?\\s+to|credited\\s+to)\\s+([A-Za-z0-9@&._'-]{2,35}?)(?:\\s+on|\\s+ref|\\s+using|\\.|,|$))",
            Pattern.CASE_INSENSITIVE
        )
        val crToMatcher = crToPattern.matcher(fullText)
        if (crToMatcher.find()) {
            payee = crToMatcher.group(1)?.trim() ?: ""
        }

        // Pattern 2: to / at / for / paid to / sent to <payee>
        if (payee.isBlank()) {
            val toPattern = Pattern.compile(
                "(?:(?:paid to|sent to|transfer to|payment to|to|at)\\s+([A-Za-z0-9@&._'-]{2,35}?)(?:\\s+successful|\\s+using|\\s+on|\\s+at|\\s+from|\\s+ref|\\.|,|$))",
                Pattern.CASE_INSENSITIVE
            )
            val toMatcher = toPattern.matcher(fullText)
            if (toMatcher.find()) {
                val extracted = toMatcher.group(1)?.trim()
                if (!extracted.isNullOrBlank() && !extracted.equals("you", ignoreCase = true) && !extracted.equals("a/c", ignoreCase = true)) {
                    payee = extracted
                }
            }
        }

        // Pattern 3: Truecaller / UPI format where title is the VPA / Payee (e.g. "Komaleakshay7@oksbi")
        if (payee.isBlank() && title.isNotBlank() && !title.equals(appName, ignoreCase = true) && !title.contains("SMS", ignoreCase = true)) {
            payee = title.trim()
        }

        val effectivePayee = if (payee.isBlank()) {
            "Payment via $appName"
        } else {
            cleanPayeeName(payee)
        }

        return ParsedPayment(
            amount = amount,
            payee = effectivePayee,
            sourceApp = appName,
            timestamp = System.currentTimeMillis()
        )
    }

    private fun cleanPayeeName(name: String): String {
        val cleaned = name
            .replace(Regex("(?i)^(the|m/s|vpa)\\s+"), "")
            .trim()

        // Format VPA like komaleakshay7@oksbi as "komaleakshay7 (SBI)"
        if (cleaned.contains("@")) {
            val parts = cleaned.split("@")
            val handle = parts[0]
            val bank = if (parts.size > 1) {
                parts[1].replace(Regex("(?i)^ok"), "").uppercase()
            } else {
                "UPI"
            }
            return "$handle ($bank)"
        }

        return cleaned.split(" ")
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
