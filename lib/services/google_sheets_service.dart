import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/transaction.dart';

class GoogleSheetsSyncResult {
  final bool success;
  final String message;
  final int? transactionCount;
  final int? accountCount;
  final List<TransactionModel>? transactions;
  final List<Account>? accounts;

  const GoogleSheetsSyncResult({
    required this.success,
    required this.message,
    this.transactionCount,
    this.accountCount,
    this.transactions,
    this.accounts,
  });
}

class GoogleSheetsService {
  static const String _keySheetsUrl = 'exp_tracker_google_sheets_url';
  static const String _keyLastSync = 'exp_tracker_google_sheets_last_sync';

  final SharedPreferences _prefs;

  GoogleSheetsService(this._prefs);

  static Future<GoogleSheetsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return GoogleSheetsService(prefs);
  }

  String? getSavedUrl() {
    return _prefs.getString(_keySheetsUrl);
  }

  Future<void> saveUrl(String url) async {
    await _prefs.setString(_keySheetsUrl, url.trim());
  }

  Future<void> clearUrl() async {
    await _prefs.remove(_keySheetsUrl);
    await _prefs.remove(_keyLastSync);
  }

  String? getLastSyncTime() {
    return _prefs.getString(_keyLastSync);
  }

  Future<void> recordSyncTime() async {
    await _prefs.setString(_keyLastSync, DateTime.now().toIso8601String());
  }

  /// Push transactions and accounts to Google Sheets via Google Apps Script Web App
  Future<GoogleSheetsSyncResult> pushToGoogleSheets({
    required String webAppUrl,
    required List<TransactionModel> transactions,
    required List<Account> accounts,
    required String currency,
  }) async {
    final url = webAppUrl.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      return const GoogleSheetsSyncResult(
        success: false,
        message: 'Invalid Web App URL. Please enter a valid Google Apps Script Web App URL.',
      );
    }

    try {
      final payload = jsonEncode({
        'action': 'sync',
        'currency': currency,
        'timestamp': DateTime.now().toIso8601String(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'accounts': accounts.map((a) => a.toJson()).toList(),
      });

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200 || response.statusCode == 302) {
        // Apps script might return a redirect (302) or json response
        dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          data = null;
        }

        await recordSyncTime();

        return GoogleSheetsSyncResult(
          success: true,
          message: data != null && data['message'] != null
              ? data['message'].toString()
              : 'Successfully synced ${transactions.length} transactions and ${accounts.length} accounts to Google Sheets!',
          transactionCount: transactions.length,
          accountCount: accounts.length,
        );
      } else {
        return GoogleSheetsSyncResult(
          success: false,
          message: 'Server responded with status code ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return GoogleSheetsSyncResult(
        success: false,
        message: 'Network or sync error: $e',
      );
    }
  }

  /// Pull transactions and accounts from Google Sheets (Used when changing mobile devices!)
  Future<GoogleSheetsSyncResult> pullFromGoogleSheets({
    required String webAppUrl,
  }) async {
    final url = webAppUrl.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      return const GoogleSheetsSyncResult(
        success: false,
        message: 'Invalid Web App URL. Please enter a valid Google Apps Script Web App URL.',
      );
    }

    try {
      // Apps Script GET endpoint with ?action=fetch
      final uri = Uri.parse(url).replace(
        queryParameters: {'action': 'fetch'},
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 40));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['status'] == 'error') {
          return GoogleSheetsSyncResult(
            success: false,
            message: data['message'] ?? 'Error received from Google Sheets script.',
          );
        }

        final rawTxs = data['transactions'] as List<dynamic>? ?? [];
        final rawAccs = data['accounts'] as List<dynamic>? ?? [];

        final txs = rawTxs
            .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
            .toList();

        final accs = rawAccs
            .map((item) => Account.fromJson(item as Map<String, dynamic>))
            .toList();

        await recordSyncTime();

        return GoogleSheetsSyncResult(
          success: true,
          message: 'Successfully pulled ${txs.length} transactions and ${accs.length} accounts from Google Sheets!',
          transactionCount: txs.length,
          accountCount: accs.length,
          transactions: txs,
          accounts: accs,
        );
      } else {
        return GoogleSheetsSyncResult(
          success: false,
          message: 'Server returned HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return GoogleSheetsSyncResult(
        success: false,
        message: 'Failed to pull data from Google Sheets: $e',
      );
    }
  }

  /// The copy-paste ready Google Apps Script that lives in the user's Google Sheet
  static const String appsScriptCode = '''
/**
 * ===================================================================
 * EXPENSE TRACKER - GOOGLE APPS SCRIPT WEB APP BACKEND
 * ===================================================================
 * 
 * HOW TO SET UP (Takes 2 minutes):
 * 1. Open Google Sheets (https://sheets.new)
 * 2. Click "Extensions" > "Apps Script"
 * 3. Delete any code in the editor, and paste THIS ENTIRE SCRIPT.
 * 4. Click "Deploy" (top right) > "New deployment"
 * 5. Select type: "Web app" (click gear icon next to Select type)
 * 6. Description: "Expense Tracker API"
 * 7. Execute as: "Me (your email)"
 * 8. Who has access: "Anyone"
 * 9. Click "Deploy", review permissions, and COPY the Web App URL!
 * 10. Paste that Web App URL into your Expense Tracker app.
 */

function doPost(e) {
  try {
    var raw = e.postData.contents;
    var data = JSON.parse(raw);
    var action = data.action || 'sync';
    
    if (action === 'sync') {
      var ss = SpreadsheetApp.getActiveSpreadsheet();
      var currency = data.currency || '₹';
      var transactions = data.transactions || [];
      var accounts = data.accounts || [];
      
      // 1. Write Accounts Sheet
      updateAccountsSheet(ss, accounts);
      
      // 2. Write All Transactions Master Sheet
      updateMasterTransactionsSheet(ss, transactions);
      
      // 3. Write Month-Wise Sheets
      updateMonthlySheets(ss, transactions, currency);
      
      // 4. Write / Update Dashboard Sheet
      updateDashboardSheet(ss, transactions, accounts, currency);
      
      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        message: 'Synced ' + transactions.length + ' transactions and ' + accounts.length + ' accounts successfully!',
        count: transactions.length
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: 'Unknown action'
    })).setMimeType(ContentService.MimeType.JSON);
    
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

function doGet(e) {
  try {
    var action = (e && e.parameter && e.parameter.action) ? e.parameter.action : 'fetch';
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    
    if (action === 'fetch' || action === 'pull') {
      var txs = readTransactions(ss);
      var accs = readAccounts(ss);
      
      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        transactions: txs,
        accounts: accs
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      message: 'Expense Tracker Google Apps Script Web App is running!'
    })).setMimeType(ContentService.MimeType.JSON);
    
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

// ---------------- Helper Sheet Functions ----------------

function updateMasterTransactionsSheet(ss, txs) {
  var sheet = ss.getSheetByName('All_Transactions');
  if (!sheet) {
    sheet = ss.insertSheet('All_Transactions');
  }
  sheet.clear();
  
  var headers = ['id', 'dateTime', 'type', 'amount', 'title', 'categoryId', 'accountId', 'toAccountId', 'paymentMode', 'note'];
  sheet.appendRow(headers);
  sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#334155').setFontColor('#ffffff');
  
  if (txs.length > 0) {
    var rows = [];
    for (var i = 0; i < txs.length; i++) {
      var t = txs[i];
      rows.push([
        t.id,
        t.dateTime,
        t.type,
        t.amount,
        t.title,
        t.categoryId,
        t.accountId,
        t.toAccountId || '',
        t.paymentMode,
        t.note || ''
      ]);
    }
    sheet.getRange(2, 1, rows.length, headers.length).setValues(rows);
  }
}

function updateAccountsSheet(ss, accs) {
  var sheet = ss.getSheetByName('Accounts');
  if (!sheet) {
    sheet = ss.insertSheet('Accounts');
  }
  sheet.clear();
  
  var headers = ['id', 'name', 'type', 'balance', 'colorValue'];
  sheet.appendRow(headers);
  sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#0D9488').setFontColor('#ffffff');
  
  if (accs.length > 0) {
    var rows = [];
    for (var i = 0; i < accs.length; i++) {
      var a = accs[i];
      rows.push([a.id, a.name, a.type, a.balance, a.colorValue]);
    }
    sheet.getRange(2, 1, rows.length, headers.length).setValues(rows);
  }
}

function updateMonthlySheets(ss, txs, currency) {
  var monthGroups = {};
  for (var i = 0; i < txs.length; i++) {
    var t = txs[i];
    var dt = new Date(t.dateTime);
    var monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    var key = monthNames[dt.getMonth()] + ' ' + dt.getFullYear();
    if (!monthGroups[key]) monthGroups[key] = [];
    monthGroups[key].push(t);
  }
  
  for (var mKey in monthGroups) {
    var sheet = ss.getSheetByName(mKey);
    if (!sheet) {
      sheet = ss.insertSheet(mKey);
    }
    sheet.clear();
    
    // Headers
    sheet.appendRow(['Date', 'Time', 'Type', 'Title', 'Category', 'Amount (' + currency + ')', 'Payment Mode', 'Note']);
    sheet.getRange(1, 1, 1, 8).setFontWeight('bold').setBackground('#1E293B').setFontColor('#ffffff');
    
    var groupTxs = monthGroups[mKey];
    var rows = [];
    for (var j = 0; j < groupTxs.length; j++) {
      var item = groupTxs[j];
      var d = new Date(item.dateTime);
      var dateStr = Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM-dd');
      var timeStr = Utilities.formatDate(d, Session.getScriptTimeZone(), 'HH:mm');
      rows.push([
        dateStr,
        timeStr,
        item.type.toUpperCase(),
        item.title,
        item.categoryId,
        item.amount,
        item.paymentMode,
        item.note || ''
      ]);
    }
    if (rows.length > 0) {
      sheet.getRange(2, 1, rows.length, 8).setValues(rows);
    }
  }
}

function updateDashboardSheet(ss, txs, accs, currency) {
  var sheet = ss.getSheetByName('📊 Dashboard');
  if (!sheet) {
    sheet = ss.insertSheet('📊 Dashboard', 0);
  }
  sheet.clear();
  
  var totalIncome = 0;
  var totalExpense = 0;
  var catTotals = {};
  
  for (var i = 0; i < txs.length; i++) {
    var t = txs[i];
    if (t.type === 'income') totalIncome += t.amount;
    if (t.type === 'expense') {
      totalExpense += t.amount;
      catTotals[t.categoryId] = (catTotals[t.categoryId] || 0) + t.amount;
    }
  }
  
  var totalBalance = 0;
  for (var a = 0; a < accs.length; a++) {
    totalBalance += accs[a].balance;
  }
  
  sheet.appendRow(['📊 EXPENSE TRACKER FINANCIAL DASHBOARD']);
  sheet.getRange('A1:D1').merge().setFontSize(14).setFontWeight('bold').setBackground('#0D9488').setFontColor('#ffffff').setHorizontalAlignment('center');
  
  sheet.appendRow(['Last Updated:', new Date().toLocaleString(), 'Currency:', currency]);
  sheet.appendRow([]);
  
  sheet.appendRow(['KPI Financial Metric', 'Value (' + currency + ')']);
  sheet.getRange(4, 1, 1, 2).setFontWeight('bold').setBackground('#1E293B').setFontColor('#ffffff');
  sheet.appendRow(['Current Balance', totalBalance]);
  sheet.appendRow(['Total Income', totalIncome]);
  sheet.appendRow(['Total Expense', totalExpense]);
  sheet.appendRow(['Net Savings', totalIncome - totalExpense]);
  sheet.appendRow(['Total Transactions', txs.length]);
  
  sheet.appendRow([]);
  sheet.appendRow(['Category', 'Expense Total (' + currency + ')', '% of Total']);
  var catHeaderRow = sheet.getLastRow();
  sheet.getRange(catHeaderRow, 1, 1, 3).setFontWeight('bold').setBackground('#334155').setFontColor('#ffffff');
  
  for (var c in catTotals) {
    var pct = totalExpense > 0 ? (catTotals[c] / totalExpense) * 100 : 0;
    sheet.appendRow([c, catTotals[c], pct.toFixed(1) + '%']);
  }
}

function readTransactions(ss) {
  var sheet = ss.getSheetByName('All_Transactions');
  if (!sheet) return [];
  var data = sheet.getDataRange().getValues();
  if (data.length <= 1) return [];
  
  var results = [];
  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    if (!row[0]) continue;
    results.push({
      id: String(row[0]),
      dateTime: String(row[1]),
      type: String(row[2]),
      amount: Number(row[3]) || 0,
      title: String(row[4]),
      categoryId: String(row[5]),
      accountId: String(row[6]),
      toAccountId: row[7] ? String(row[7]) : null,
      paymentMode: String(row[8]),
      note: row[9] ? String(row[9]) : ''
    });
  }
  return results;
}

function readAccounts(ss) {
  var sheet = ss.getSheetByName('Accounts');
  if (!sheet) return [];
  var data = sheet.getDataRange().getValues();
  if (data.length <= 1) return [];
  
  var results = [];
  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    if (!row[0]) continue;
    results.push({
      id: String(row[0]),
      name: String(row[1]),
      type: String(row[2]),
      balance: Number(row[3]) || 0,
      colorValue: Number(row[4]) || 0xFF0D9488
    });
  }
  return results;
}
''';
}
