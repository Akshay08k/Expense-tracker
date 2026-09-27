/**
 * ===================================================================
 * EXPENSE TRACKER - GOOGLE APPS SCRIPT WEB APP BACKEND
 * ===================================================================
 * 
 * HOW TO SET UP (Takes ~2 minutes, 100% Free):
 * 1. Open Google Sheets (https://sheets.new) to create a new spreadsheet.
 * 2. Click "Extensions" > "Apps Script" in the top menu.
 * 3. Delete any boilerplate code in Code.gs, and PASTE THIS ENTIRE SCRIPT.
 * 4. Click the blue "Deploy" button (top right) > "New deployment".
 * 5. Click the gear icon next to "Select type" and choose "Web app".
 * 6. Set Description: "Expense Tracker API". 
 * 7. Set Execute as: "Me (your google email)".
 * 8. Set Who has access: "Anyone". (Crucial for the mobile app to sync).
 * 9. Click "Deploy". Grant permissions when Google asks.
 * 10. Copy the "Web app URL" (starts with https://script.google.com/macros/s/...)
 * 11. Open your Expense Tracker app > "Spreadsheet & Sync" > Paste URL!
 * 
 * Done! When you switch phones, simply paste this URL in the app on the new phone
 * and tap "Pull from Google Sheets" to immediately restore all your data!
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
      
      // 4. Write / Update Dashboard Sheet with KPIs and Pie Chart data
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
