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
import java.util.Locale
import java.util.regex.Pattern

class PaymentNotificationListenerService : NotificationListenerService() {

    companion object {
        const val TAG = "FinFlowPaymentListener"
        const val CHANNEL_ID = "finflow_payment_detected"
        const val CHANNEL_NAME = "Detected Payments"
        const val NOTIFICATION_ID = 9001

        private var lastProcessedAmount: Double = -1.0
        private var lastProcessedTime: Long = 0L

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
            "com.truecaller.messenger" to "Truecaller SMS",

            // Default & OEM Messaging Apps (For Bank Debit/Credit SMS like BOBSMS - Zero READ_SMS permission needed!)
            "com.google.android.apps.messaging" to "Bank SMS",
            "com.samsung.android.messaging" to "Bank SMS",
            "com.android.mms" to "Bank SMS",
            "com.oneplus.mms" to "Bank SMS",
            "com.coloros.mms" to "Bank SMS",
            "com.heytap.mms" to "Bank SMS",
            "com.oppo.mms" to "Bank SMS",
            "com.realme.mms" to "Bank SMS",
            "com.xiaomi.mms" to "Bank SMS",
            "com.miui.smsextra" to "Bank SMS",
            "com.vivo.mms" to "Bank SMS",
            "com.bbk.mms" to "Bank SMS",
            "com.nothing.mms" to "Bank SMS"
        )

        fun isSupportedPackage(packageName: String): Boolean {
            if (SUPPORTED_PACKAGES.containsKey(packageName)) return true
            val lower = packageName.lowercase(Locale.ROOT)
            return lower.contains("messaging") ||
                    lower.contains(".mms") ||
                    lower.endsWith(".mms") ||
                    lower.contains(".sms") ||
                    lower.endsWith(".sms") ||
                    lower.contains("smsextra") ||
                    lower.contains("truecaller") ||
                    lower.contains(".upi") ||
                    lower.contains("bhim") ||
                    lower.contains("banking")
        }

        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifies you when a UPI payment or bank debit is detected so you can record it in 1 tap"
                    enableVibration(true)
                    lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                    setShowBadge(true)
                }
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.createNotificationChannel(channel)
            }
        }

        fun showPaymentNotification(
            context: Context,
            amount: Double,
            payee: String,
            sourceApp: String,
            isIncome: Boolean = false,
            timestamp: Long = System.currentTimeMillis()
        ) {
            createNotificationChannel(context)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra("is_payment_detected", true)
                putExtra("amount", amount)
                putExtra("title", payee)
                putExtra("source_app", sourceApp)
                putExtra("is_income", isIncome)
                putExtra("timestamp", timestamp)
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                (System.currentTimeMillis() % 10000).toInt(),
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val formattedAmount = if (amount % 1.0 == 0.0) {
                amount.toInt().toString()
            } else {
                String.format(Locale.US, "%.2f", amount)
            }

            val notifId = (timestamp % 100000).toInt() + 100
            val defaultCategoryId = if (isIncome) "salary" else predictCategoryNatively(payee)

            // 1. Action: ⚡ Quick Save (Saves in background without opening app)
            val quickSaveIntent = Intent(context, PaymentActionReceiver::class.java).apply {
                action = PaymentActionReceiver.ACTION_QUICK_SAVE
                putExtra("amount", amount)
                putExtra("title", payee)
                putExtra("source_app", sourceApp)
                putExtra("is_income", isIncome)
                putExtra("category_id", defaultCategoryId)
                putExtra("notif_id", notifId)
            }
            val quickSavePendingIntent = PendingIntent.getBroadcast(
                context,
                (System.currentTimeMillis() % 10000 + 1).toInt(),
                quickSaveIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val quickSaveAction = NotificationCompat.Action.Builder(
                R.mipmap.ic_launcher,
                "⚡ Quick Save",
                quickSavePendingIntent
            ).build()

            // 2. Action: ✏️ Add Description (Inline text box right inside the notification)
            val remoteInput = androidx.core.app.RemoteInput.Builder(PaymentActionReceiver.KEY_TEXT_REPLY)
                .setLabel("Enter note or description...")
                .build()

            val addNoteIntent = Intent(context, PaymentActionReceiver::class.java).apply {
                action = PaymentActionReceiver.ACTION_ADD_NOTE
                putExtra("amount", amount)
                putExtra("title", payee)
                putExtra("source_app", sourceApp)
                putExtra("is_income", isIncome)
                putExtra("category_id", defaultCategoryId)
                putExtra("notif_id", notifId)
            }
            val addNotePendingIntent = PendingIntent.getBroadcast(
                context,
                (System.currentTimeMillis() % 10000 + 2).toInt(),
                addNoteIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            )
            val addNoteAction = NotificationCompat.Action.Builder(
                R.mipmap.ic_launcher,
                "✏️ Add Description",
                addNotePendingIntent
            ).addRemoteInput(remoteInput).build()

            val titleText = if (isIncome) {
                "Income Received: ₹$formattedAmount"
            } else {
                "Payment Detected: ₹$formattedAmount"
            }

            val contentText = if (isIncome) {
                "Received from $payee via $sourceApp."
            } else {
                "Paid to $payee via $sourceApp."
            }

            val bigText = if (isIncome) {
                "Detected ₹$formattedAmount received from $payee. Tap Quick Save to record instantly, or add a description below."
            } else {
                "Detected ₹$formattedAmount paid to $payee. Tap Quick Save to record instantly, or add a description below."
            }

            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(titleText)
                .setContentText(contentText)
                .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_EVENT)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .addAction(quickSaveAction)
                .addAction(addNoteAction)

            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(notifId, builder.build())
        }

        fun predictCategoryNatively(payee: String): String {
            val lower = payee.lowercase(Locale.ROOT)
            if (lower.contains("zomato") || lower.contains("swiggy") || lower.contains("starbucks") ||
                lower.contains("mcdonald") || lower.contains("burger") || lower.contains("pizza") ||
                lower.contains("cafe") || lower.contains("tea") || lower.contains("chai") ||
                lower.contains("restaurant") || lower.contains("bakery") || lower.contains("food")) {
                return "food"
            }
            if (lower.contains("blinkit") || lower.contains("zepto") || lower.contains("instamart") ||
                lower.contains("dmart") || lower.contains("grocery") || lower.contains("supermarket") ||
                lower.contains("vegetable") || lower.contains("fruit") || lower.contains("dairy")) {
                return "groceries"
            }
            if (lower.contains("uber") || lower.contains("ola") || lower.contains("rapido") ||
                lower.contains("metro") || lower.contains("petrol") || lower.contains("fuel") ||
                lower.contains("shell") || lower.contains("hpcl") || lower.contains("bpcl")) {
                return "transport"
            }
            if (lower.contains("amazon") || lower.contains("flipkart") || lower.contains("myntra") ||
                lower.contains("zara") || lower.contains("shopping") || lower.contains("mall")) {
                return "shopping"
            }
            if (lower.contains("bescom") || lower.contains("airtel") || lower.contains("jio") ||
                lower.contains("electricity") || lower.contains("wifi") || lower.contains("gas") || lower.contains("bill")) {
                return "bills"
            }
            if (lower.contains("netflix") || lower.contains("spotify") || lower.contains("hotstar") ||
                lower.contains("prime") || lower.contains("pvr") || lower.contains("cinema") || lower.contains("movie")) {
                return "entertainment"
            }
            if (lower.contains("pharmacy") || lower.contains("apollo") || lower.contains("medplus") ||
                lower.contains("hospital") || lower.contains("clinic") || lower.contains("doctor")) {
                return "health"
            }
            return "food"
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel(this)
        Log.d(TAG, "PaymentNotificationListenerService created")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        // 1. FAST FILTER: Only inspect whitelisted/messaging packages (Zero Battery Drain)
        if (!isSupportedPackage(packageName)) {
            return
        }

        val appName = SUPPORTED_PACKAGES[packageName] ?: if (
            packageName.contains("mms") || packageName.contains("messaging") || packageName.contains("sms")
        ) "Bank SMS" else "Banking App"

        val extras = sbn.notification?.extras ?: return

        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""
        val subText = extras.getCharSequence("android.subText")?.toString() ?: ""
        val infoText = extras.getCharSequence("android.infoText")?.toString() ?: ""

        val sb = StringBuilder()
        sb.append(title).append(" ").append(text).append(" ").append(bigText).append(" ").append(subText).append(" ").append(infoText).append(" ")

        // Also gather any other text lines in the extras bundle (handles Truecaller, OEM SMS styles)
        try {
            for (key in extras.keySet()) {
                if (key != "android.title" && key != "android.text" && key != "android.bigText" &&
                    key != "android.subText" && key != "android.infoText") {
                    val value = extras.get(key)
                    if (value is CharSequence) {
                        sb.append(value).append(" ")
                    } else if (value is Array<*> && value.isArrayOf<CharSequence>()) {
                        for (item in value) {
                            if (item != null) sb.append(item).append(" ")
                        }
                    }
                }
            }
        } catch (_: Exception) {}

        val fullText = sb.toString().trim()
        Log.d(TAG, "Processing notification from $appName ($packageName): $fullText")

        // 2. Parse Amount, Payee/Merchant, and Transaction Type (Income vs Expense)
        val parsed = parseTransaction(fullText, title, text, appName, packageName) ?: return

        // Deduplicate notifications arriving within 3 seconds for the same amount (e.g. Bank SMS + Truecaller)
        val now = System.currentTimeMillis()
        if (lastProcessedAmount == parsed.amount && (now - lastProcessedTime) < 3000) {
            Log.d(TAG, "Dropping duplicate notification for amount ${parsed.amount} received within 3s")
            return
        }
        lastProcessedAmount = parsed.amount
        lastProcessedTime = now

        Log.d(TAG, "Successfully parsed transaction: Amount=${parsed.amount}, Payee=${parsed.payee}, isIncome=${parsed.isIncome}, App=${parsed.sourceApp}")

        // 3. Notify Flutter if app is active in foreground
        val paymentData = hashMapOf<String, Any>(
            "amount" to parsed.amount,
            "title" to parsed.payee,
            "sourceApp" to parsed.sourceApp,
            "isIncome" to parsed.isIncome,
            "timestamp" to parsed.timestamp,
            "rawText" to fullText
        )

        MainActivity.pendingPaymentData = paymentData
        MainActivity.notifyPaymentIfActive(paymentData)

        // 4. Always show the heads-up notification banner with Action Buttons ([⚡ Quick Save] & [✏️ Add Description])
        showPaymentNotification(
            context = this,
            amount = parsed.amount,
            payee = parsed.payee,
            sourceApp = parsed.sourceApp,
            isIncome = parsed.isIncome,
            timestamp = parsed.timestamp
        )
    }

    data class ParsedPayment(
        val amount: Double,
        val payee: String,
        val sourceApp: String,
        val timestamp: Long,
        val isIncome: Boolean = false
    )

    private fun parseTransaction(
        fullText: String,
        title: String,
        text: String,
        appName: String,
        packageName: String
    ): ParsedPayment? {
        val lower = fullText.lowercase(Locale.ROOT)

        // 1. Ignore OTP, login, password, or security alerts
        if (lower.contains("otp") || lower.contains("login") || lower.contains("code") ||
            lower.contains("secret") || lower.contains("password") ||
            lower.contains("cashback received") || lower.contains("offers")
        ) {
            return null
        }

        // 2. SENDER HEADER: In India, TRAI headers ending in "-P" (e.g. JX-KOTAKB-P, VM-HDFCBK-P) are PROMOTIONAL
        if (title.matches(Regex("(?i).+-[A-Z0-9]+-P$"))) {
            Log.d(TAG, "Ignoring promotional SMS header: $title")
            return null
        }

        // 3. STRICT ANTI-PROMOTIONAL GATE:
        // Ignore loans, pre-approved advances, cashback gamification, credit limit increases, and marketing promos
        val isPromotional = lower.contains("pre-approved") || lower.contains("pre approved") ||
                lower.contains("pre-qualified") || lower.contains("pre qualified") ||
                lower.contains("instant loan") || lower.contains("personal loan") ||
                lower.contains("advance is here") || lower.contains("payments away") ||
                lower.contains("payment away") || lower.contains("unlock guaranteed") ||
                lower.contains("unlock cashback") || lower.contains("guaranteed cashback") ||
                lower.contains("cashback on") || lower.contains("cashback of") ||
                lower.contains("win up to") || lower.contains("earn up to") ||
                lower.contains("stand a chance") || lower.contains("spin and win") ||
                lower.contains("scratch card") || lower.contains("apply now") ||
                lower.contains("avail now") || lower.contains("eligible for") ||
                lower.contains("credit limit") || lower.contains("increase limit") ||
                lower.contains("upgrade your") || lower.contains("t&c") ||
                lower.contains("terms and conditions") || lower.contains("sweet time") ||
                lower.contains("exclusive offer") || lower.contains("special offer") ||
                lower.contains("discount on") || lower.contains("coupon code") ||
                lower.contains("refer and earn") || lower.contains("invite friends") ||
                lower.contains("refer friends") || lower.contains("bill due") ||
                lower.contains("payment due") || lower.contains("due date") ||
                lower.contains("due on") || lower.contains("overdue") ||
                lower.contains("hurry") || lower.contains("don't miss") ||
                lower.contains("recharge now") || lower.contains("book now") ||
                lower.contains("order now") || lower.contains("get flat") ||
                lower.contains("earn flat") || lower.contains("complete 3 payments") ||
                lower.contains("complete payments") || lower.contains("make payments") ||
                lower.contains("cashback reward") || lower.contains("reward points") ||
                lower.contains("unlock offer") || lower.contains("claim your offer") ||
                lower.contains("congratulations! you are eligible")

        if (isPromotional) {
            Log.d(TAG, "Ignoring promotional/marketing notification: $fullText")
            return null
        }

        // 4. Legitimate Salary Credit Verification (must be an actual credit, not marketing/loan offer)
        val hasSalaryCredit = lower.contains("salary credited") ||
                lower.contains("credited towards salary") ||
                lower.contains("salary deposited") ||
                lower.contains("salary for ") ||
                (lower.contains("salary") && (lower.contains("credited") || lower.contains("deposited") || lower.contains("received")))

        // 5. Determine whether this transaction is an INCOME (received/credit)
        var isIncome = false
        if (lower.contains("received") || lower.contains("credited with") ||
            lower.contains("credited by") || lower.contains("deposited into") ||
            lower.contains("deposited to") || lower.contains("credited to a/c") ||
            lower.contains("credited to your a/c") || lower.contains("credited to your account") ||
            lower.contains("cr to a/c") || lower.contains("cr. to a/c") ||
            lower.contains("refund of") || lower.contains("refund credited") ||
            hasSalaryCredit
        ) {
            // Guard: If SMS says "Dr. from A/C" or "debited from A/C", it is an EXPENSE debit, NOT income!
            if (!lower.contains("dr. from") && !lower.contains("dr from") && !lower.contains("debited from")) {
                isIncome = true
            }
        }

        // For SMS messaging apps: Ensure it's from a bank/financial sender or has transaction keywords
        val isMessagingApp = packageName.contains("messaging") || packageName.contains("mms") || packageName.contains("sms")
        if (isMessagingApp) {
            val isBankSender = title.matches(Regex("(?i).*(bob|sbi|hdfc|icici|axis|kotak|pnb|canara|canbnk|union|idfc|paytm|upi|sms|alert|bank|citi|rbl|indus|yesb|bop|baroda|iob|idbi|fedbk|scb|central|corp|dena|synd|vijaya|maha|punjab|fss|cred).*"))
            val hasDebitIndicator = lower.contains("dr.") || lower.contains("dr ") ||
                    lower.contains("debited") || lower.contains("withdrawn") ||
                    lower.contains("spent") || lower.contains("paid") || lower.contains("cr. to")
            if (!isBankSender && !hasDebitIndicator && !isIncome) {
                return null // Instantly drop non-banking personal SMS from friends
            }
        }

        // 6. Must indicate a clear past-action Debit, an Income receipt, OR Truecaller VPA transaction
        val hasDebitKeyword = lower.contains("paid") || lower.contains("sent") ||
                lower.contains("debited") || lower.contains("withdrawn") ||
                lower.contains("dr.") || lower.contains("dr ") ||
                lower.contains("cr. to") || lower.contains("cr to") ||
                lower.contains("transferred to") || lower.contains("transfer to") ||
                (lower.contains("successful") && (lower.contains("payment") || lower.contains("transfer") || lower.contains("paid")))

        val isTruecallerVpa = packageName.contains("truecaller") && title.contains("@")

        if (!isIncome && !hasDebitKeyword && !isTruecallerVpa) {
            return null
        }

        // Regex for Amount: Handles Rs.10.00, Rs 10, ₹10, INR 1,250.50, Paid 10, Received 500, etc.
        val amountPattern = Pattern.compile(
            "(?:(?:₹|rs\\.?|inr|paid|received|debited by|debited for|debited with|debited of|spent)\\s*[:.]?\\s*([0-9,]+(?:\\.[0-9]{1,2})?))",
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

        // Extract Payee / Sender / Merchant Name
        var payee = ""

        if (isIncome) {
            // Pattern for Income: received from / from / by UPI/... / deposited by
            val fromPattern = Pattern.compile(
                "(?:(?:received\\s+from|from|deposited\\s+by|by\\s+upi/[^/]+/|by)\\s+([A-Za-z0-9@&._'-]+(?:\\s+[A-Za-z0-9@&._'-]+)*))",
                Pattern.CASE_INSENSITIVE
            )
            val fromMatcher = fromPattern.matcher(fullText)
            if (fromMatcher.find()) {
                val raw = fromMatcher.group(1)?.trim() ?: ""
                val cleaned = raw.split(Regex("(?i)\\s+(?:on|ref|using|via|in|into|for|towards|\\.)"))[0].trim()
                if (cleaned.isNotBlank() && !cleaned.equals("you", ignoreCase = true) && !cleaned.equals("a/c", ignoreCase = true)) {
                    payee = cleaned
                }
            }
            if (payee.isBlank() && title.isNotBlank() && !title.equals(appName, ignoreCase = true) && !title.contains("SMS", ignoreCase = true)) {
                payee = title.trim()
            }
        } else {
            // Pattern 1 for Expense: Cr. to <payee> (very common in Indian Bank SMS like BOBSMS)
            val crToPattern = Pattern.compile(
                "(?:(?:cr\\.?\\s+to|credited\\s+to)\\s+([A-Za-z0-9@&._'-]{2,35}?)(?:\\s+on|\\s+ref|\\s+using|\\.|,|$))",
                Pattern.CASE_INSENSITIVE
            )
            val crToMatcher = crToPattern.matcher(fullText)
            if (crToMatcher.find()) {
                payee = crToMatcher.group(1)?.trim() ?: ""
            }

            // Pattern 2 for Expense: to / at / for / paid to / sent to <payee>
            if (payee.isBlank()) {
                val toPattern = Pattern.compile(
                    "(?:(?:paid to|sent to|transfer to|payment to|to|at)\\s+([A-Za-z0-9@&._'-]{2,35}?)(?:\\s+successful|\\s+using|\\s+on|\\s+at|\\s+from|\\s+ref|\\.|,|$))",
                    Pattern.CASE_INSENSITIVE
                )
                val toMatcher = toPattern.matcher(fullText)
                if (toMatcher.find()) {
                    val extracted = toMatcher.group(1)?.trim()
                    if (!extracted.isNullOrBlank() && !extracted.equals("you", ignoreCase = true) &&
                        !extracted.equals("a/c", ignoreCase = true) &&
                        !extracted.equals("friends", ignoreCase = true) &&
                        !extracted.equals("someone", ignoreCase = true) &&
                        !extracted.equals("anyone", ignoreCase = true)) {
                        payee = extracted
                    }
                }
            }

            // Pattern 3 for Expense: Truecaller / UPI format where title is the VPA / Payee (e.g. "Komaleakshay7@oksbi")
            if (payee.isBlank() && title.isNotBlank() && !title.equals(appName, ignoreCase = true) && !title.contains("SMS", ignoreCase = true)) {
                payee = title.trim()
            }
        }

        val effectivePayee = if (payee.isBlank()) {
            if (isIncome) "Income via $appName" else "Payment via $appName"
        } else {
            cleanPayeeName(payee)
        }

        return ParsedPayment(
            amount = amount,
            payee = effectivePayee,
            sourceApp = appName,
            timestamp = System.currentTimeMillis(),
            isIncome = isIncome
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
                parts[1].replace(Regex("(?i)^ok"), "").uppercase(Locale.ROOT)
            } else {
                "UPI"
            }
            return "$handle ($bank)"
        }

        return cleaned.split(" ")
            .joinToString(" ") { word ->
                if (word.isNotEmpty()) word.substring(0, 1).uppercase(Locale.ROOT) + word.substring(1).lowercase(Locale.ROOT) else ""
            }
    }
}
