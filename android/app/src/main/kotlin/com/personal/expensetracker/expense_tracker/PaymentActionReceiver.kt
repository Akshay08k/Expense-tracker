package com.personal.expensetracker.expense_tracker

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class PaymentActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PaymentActionReceiver"
        const val ACTION_QUICK_SAVE = "com.personal.expensetracker.ACTION_QUICK_SAVE"
        const val ACTION_ADD_NOTE = "com.personal.expensetracker.ACTION_ADD_NOTE"
        const val KEY_TEXT_REPLY = "key_text_reply"
        const val CHANNEL_ID = "finflow_payment_detected"
        const val NOTIFICATION_ID = 9001
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d(TAG, "Received notification action: $action")

        val amount = intent.getDoubleExtra("amount", 0.0)
        val title = intent.getStringExtra("title") ?: "Payment"
        val isIncome = intent.getBooleanExtra("is_income", false)
        val sourceApp = intent.getStringExtra("source_app") ?: "UPI"
        val categoryId = intent.getStringExtra("category_id") ?: (if (isIncome) "salary" else "food")

        var note = intent.getStringExtra("note") ?: ""

        // If user typed a description in the inline reply box
        if (action == ACTION_ADD_NOTE) {
            val remoteInputResults = RemoteInput.getResultsFromIntent(intent)
            val replyText = remoteInputResults?.getCharSequence(KEY_TEXT_REPLY)?.toString()
            if (!replyText.isNullOrBlank()) {
                note = replyText.trim()
            }
        }

        // 1. Save directly into SharedPreferences (local database)
        try {
            saveTransactionNatively(context, amount, title, isIncome, categoryId, note)
            Log.d(TAG, "Transaction successfully saved natively without opening app: Amount=$amount, Note=$note")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving transaction natively", e)
        }

        // 2. Notify Flutter if active
        val paymentMap = hashMapOf<String, Any>(
            "amount" to amount,
            "title" to title,
            "isIncome" to isIncome,
            "categoryId" to categoryId,
            "note" to note,
            "sourceApp" to sourceApp
        )
        MainActivity.notifyPaymentIfActive(paymentMap)

        // 3. Update the notification to show immediate confirmation, auto-dismissing in 5 seconds
        PaymentNotificationListenerService.createNotificationChannel(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val formattedAmount = if (amount % 1.0 == 0.0) amount.toInt().toString() else String.format("%.2f", amount)
        val noteSuffix = if (note.isNotBlank()) " • \"$note\"" else ""

        val confirmationTitle = if (isIncome) "✅ Income Saved: ₹$formattedAmount" else "✅ Expense Saved: ₹$formattedAmount"
        val confirmationText = "$title$noteSuffix (Recorded in FinFlow)"

        val notifId = intent.getIntExtra("notif_id", NOTIFICATION_ID)

        val updatedNotification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(confirmationTitle)
            .setContentText(confirmationText)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(true)
            .setTimeoutAfter(5000) // Automatically dismisses notification after 5 seconds!
            .build()

        notificationManager.notify(notifId, updatedNotification)
    }

    private fun saveTransactionNatively(
        context: Context,
        amount: Double,
        title: String,
        isIncome: Boolean,
        categoryId: String,
        note: String
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val txJsonStr = prefs.getString("flutter.exp_tracker_transactions", "[]") ?: "[]"
        val accJsonStr = prefs.getString("flutter.exp_tracker_accounts", "[]") ?: "[]"

        val txArray = JSONArray(txJsonStr)
        val accArray = JSONArray(accJsonStr)

        val txId = UUID.randomUUID().toString()
        val nowIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())

        var primaryAccountId = "default_account"
        if (accArray.length() > 0) {
            var foundIdx = 0
            for (i in 0 until accArray.length()) {
                val accObj = accArray.getJSONObject(i)
                if (accObj.optString("type") == "bank") {
                    foundIdx = i
                    break
                }
            }
            val targetAcc = accArray.getJSONObject(foundIdx)
            primaryAccountId = targetAcc.optString("id", primaryAccountId)
            val curBal = targetAcc.optDouble("balance", 0.0)
            val newBal = if (isIncome) curBal + amount else curBal - amount
            targetAcc.put("balance", newBal)
            accArray.put(foundIdx, targetAcc)
        }

        val newTx = JSONObject().apply {
            put("id", txId)
            put("title", title)
            put("amount", amount)
            put("type", if (isIncome) "income" else "expense")
            put("categoryId", categoryId)
            put("accountId", primaryAccountId)
            put("toAccountId", JSONObject.NULL)
            put("paymentMode", "onlineUpi")
            put("dateTime", nowIso)
            put("note", note)
        }

        // Prepend new transaction to the top of list
        val updatedTxArray = JSONArray()
        updatedTxArray.put(newTx)
        for (i in 0 until txArray.length()) {
            updatedTxArray.put(txArray.get(i))
        }

        prefs.edit()
            .putString("flutter.exp_tracker_transactions", updatedTxArray.toString())
            .putString("flutter.exp_tracker_accounts", accArray.toString())
            .apply()
    }
}

