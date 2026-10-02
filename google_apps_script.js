/**
 * ===================================================================================
 * FINFLOW FINANCIAL OS - ADVANCED GOOGLE APPS SCRIPT DATABASE & EXECUTIVE DASHBOARD
 * ===================================================================================
 * 
 * FEATURES:
 * 1. 🎯 Dedicated Target Database File ("FinFlow_Expense_Tracker")
 * 2. 📊 Executive Command Center Dashboard:
 *    - High-Impact Financial KPI Hero Cards (Net Worth, Income, Expense, Net Savings, Savings Rate %, Daily Avg)
 *    - 🥧 Embedded Interactive Pie/Donut Chart (Expense Distribution by Category)
 *    - 📈 Embedded Monthly Cash Flow Bar Chart (Income vs Expense comparison)
 *    - 📅 Month-Wise Financial Performance Matrix (Income, Expense, Profit, Loss, Highest Spend Day, Top Category, Tx Count)
 *    - 💳 Payment Modes & Account Balances Breakdown
 * 3. 📅 Formatted Month-Ending Sheets:
 *    - Monthly Financial Overview & Burn Rate KPIs
 *    - Grouped Spends by Category Summary Table (% of Month, Counts, Totals)
 *    - Detailed Filterable Transactions Log with Type Badges (Green Income, Red Expense, Blue Transfer)
 *    - Frozen Header Rows & Auto-Fit Column Widths
 * 4. 💾 All_Transactions & Accounts Sheets (Lossless Database with Frozen Headers & Filter-Ready)
 * 5. ⚡ Real-Time Instant Auto-Sync Engine (Mobile & Web)
 * 
 * SETUP GUIDE:
 * 1. Open Google Sheets (https://sheets.new).
 * 2. Click "Extensions" > "Apps Script".
 * 3. Replace all code in Code.gs with THIS SCRIPT.
 * 4. Click "Deploy" (top right) > "New deployment" > Select type "Web app".
 * 5. Set Description: "FinFlow API", Execute as: "Me", Who has access: "Anyone".
 * 6. Click "Deploy", authorize, copy Web App URL, and paste into FinFlow app!
 */

var SPREADSHEET_FILE_NAME = "FinFlow_Expense_Tracker";

/**
 * Main Webhook POST handler: Handles instant sync from the mobile app
 */
function doPost(e) {
  try {
    var raw = e.postData.contents;
    var data = JSON.parse(raw);
    var action = data.action || 'sync';
    
    if (action === 'sync') {
      var ss = getOrCreateSpreadsheet(data);
      var currency = data.currency || '₹';
      var transactions = data.transactions || [];
      var accounts = data.accounts || [];
      
      // 1. Write / Update Accounts Sheet
      updateAccountsSheet(ss, accounts, currency);
      
      // 2. Write / Update All Transactions Master Sheet (lossless database)
      updateMasterTransactionsSheet(ss, transactions, accounts, currency);
      
      // 3. Write / Update Month-Wise Formatted Sheets with Grouped Category Spends
      updateMonthlySheets(ss, transactions, accounts, currency);
      
      // 4. Write / Update Executive Dashboard Sheet with Pie Chart, Bar Chart & Month-Wise Breakdown
      updateDashboardSheet(ss, transactions, accounts, currency);
      
      // 5. Clean up any unneeded empty default Sheet1
      cleanupDefaultSheet(ss);
      
      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        message: 'Successfully synced ' + transactions.length + ' transactions and ' + accounts.length + ' accounts into "' + ss.getName() + '"!',
        spreadsheetName: ss.getName(),
        spreadsheetUrl: ss.getUrl(),
        count: transactions.length
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: 'Unknown action: ' + action
    })).setMimeType(ContentService.MimeType.JSON);
    
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * Main GET handler: Restores data when migrating devices or verifies connectivity
 */
function doGet(e) {
  try {
    var action = (e && e.parameter && e.parameter.action) ? e.parameter.action : 'fetch';
    var ss = getOrCreateSpreadsheet(e && e.parameter ? e.parameter : null);
    
    if (action === 'fetch' || action === 'pull') {
      var txs = readTransactions(ss);
      var accs = readAccounts(ss);
      
      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        spreadsheetName: ss.getName(),
        spreadsheetUrl: ss.getUrl(),
        transactions: txs,
        accounts: accs
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      message: 'FinFlow Google Apps Script Web App is active!',
      spreadsheetName: ss.getName(),
      spreadsheetUrl: ss.getUrl()
    })).setMimeType(ContentService.MimeType.JSON);
    
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

// -------------------------------------------------------------------
// Spreadsheet File Resolver (Dedicated Named File)
// -------------------------------------------------------------------

function getOrCreateSpreadsheet(data) {
  var targetName = (data && data.spreadsheetName) ? data.spreadsheetName : SPREADSHEET_FILE_NAME;
  
  if (data && data.spreadsheetId) {
    try {
      return SpreadsheetApp.openById(data.spreadsheetId);
    } catch (_) {}
  }
  
  var active = null;
  try {
    active = SpreadsheetApp.getActiveSpreadsheet();
  } catch (_) {
    active = null;
  }
  
  if (active) {
    if (!active.getName() || active.getName() === 'Untitled spreadsheet') {
      active.rename(targetName);
    }
    return active;
  }
  
  try {
    var files = DriveApp.getFilesByName(targetName);
    if (files.hasNext()) {
      return SpreadsheetApp.open(files.next());
    }
    return SpreadsheetApp.create(targetName);
  } catch (err) {
    return SpreadsheetApp.create(targetName);
  }
}

function cleanupDefaultSheet(ss) {
  try {
    var s1 = ss.getSheetByName('Sheet1');
    if (s1 && ss.getSheets().length > 1) {
      if (s1.getLastRow() <= 1 && s1.getLastColumn() <= 1) {
        ss.deleteSheet(s1);
      }
    }
  } catch (_) {}
}

// -------------------------------------------------------------------
// 1. EXECUTIVE DASHBOARD SHEET (COMMAND CENTER)
// -------------------------------------------------------------------

function updateDashboardSheet(ss, txs, accs, currency) {
  var sheet = ss.getSheetByName('📊 Dashboard');
  if (!sheet) {
    sheet = ss.insertSheet('📊 Dashboard', 0);
  } else {
    ss.setActiveSheet(sheet);
    ss.moveChartToObjectSheet && ss.moveActiveSheet(1);
  }
  sheet.clear();
  
  // Clear any existing charts
  var oldCharts = sheet.getCharts();
  for (var c = 0; c < oldCharts.length; c++) {
    sheet.removeChart(oldCharts[c]);
  }
  
  // Data aggregations
  var totalIncome = 0;
  var totalExpense = 0;
  var catTotals = {};
  var catCounts = {};
  var payModeTotals = {};
  var payModeCounts = {};
  
  var monthStats = {};
  var monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  
  for (var i = 0; i < txs.length; i++) {
    var t = txs[i];
    var d = new Date(t.dateTime);
    var y = d.getFullYear();
    var m = d.getMonth();
    var mSortKey = y + '-' + ((m + 1) < 10 ? '0' + (m + 1) : (m + 1));
    var mLabel = monthNames[m] + ' ' + y;
    
    if (!monthStats[mSortKey]) {
      monthStats[mSortKey] = {
        label: mLabel,
        income: 0,
        expense: 0,
        dayExpenses: {},
        catExpenses: {},
        txCount: 0
      };
    }
    
    monthStats[mSortKey].txCount++;
    var dayKey = Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM-dd');
    
    if (t.type === 'income') {
      totalIncome += t.amount;
      monthStats[mSortKey].income += t.amount;
    } else if (t.type === 'expense') {
      totalExpense += t.amount;
      catTotals[t.categoryId] = (catTotals[t.categoryId] || 0) + t.amount;
      catCounts[t.categoryId] = (catCounts[t.categoryId] || 0) + 1;
      
      monthStats[mSortKey].expense += t.amount;
      monthStats[mSortKey].dayExpenses[dayKey] = (monthStats[mSortKey].dayExpenses[dayKey] || 0) + t.amount;
      monthStats[mSortKey].catExpenses[t.categoryId] = (monthStats[mSortKey].catExpenses[t.categoryId] || 0) + t.amount;
      
      var pMode = t.paymentMode || 'OTHER';
      payModeTotals[pMode] = (payModeTotals[pMode] || 0) + t.amount;
      payModeCounts[pMode] = (payModeCounts[pMode] || 0) + 1;
    }
  }
  
  var totalBalance = 0;
  for (var a = 0; a < accs.length; a++) {
    totalBalance += accs[a].balance;
  }
  var netSavings = totalIncome - totalExpense;
  var savingsRate = totalIncome > 0 ? (netSavings / totalIncome) * 100 : 0;
  var activeMonthsCount = Math.max(Object.keys(monthStats).length, 1);
  var avgMonthlySpend = totalExpense / activeMonthsCount;
  
  // Row 1: Executive Banner
  sheet.getRange('A1:J1').merge()
    .setValue('📊 FINFLOW FINANCIAL OS • EXECUTIVE DASHBOARD')
    .setFontSize(15)
    .setFontWeight('bold')
    .setBackground('#0D9488')
    .setFontColor('#FFFFFF')
    .setHorizontalAlignment('center')
    .setVerticalAlignment('middle');
  sheet.setRowHeight(1, 42);
  
  // Row 2: Subtitle & Metadata Summary
  var timeStr = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm:ss');
  var subInfo = 'Last Synced: ' + timeStr +
                '  •  Total Transactions: ' + txs.length +
                '  •  Accounts: ' + accs.length +
                '  •  Active Months: ' + activeMonthsCount +
                '  •  Currency: ' + currency;
  sheet.getRange('A2:J2').merge()
    .setValue(subInfo)
    .setFontSize(9.5)
    .setFontColor('#64748B')
    .setBackground('#F8FAFC')
    .setHorizontalAlignment('center')
    .setVerticalAlignment('middle');
  sheet.setRowHeight(2, 24);
  
  // Row 4-6: FINANCIAL HEALTH & PERFORMANCE KPI HERO CARDS
  var kpiStartRow = 4;
  sheet.getRange(kpiStartRow, 1, 1, 10).merge()
    .setValue('🏆 FINANCIAL SUMMARY & KEY PERFORMANCE INDICATORS')
    .setFontWeight('bold')
    .setFontSize(11)
    .setBackground('#1E293B')
    .setFontColor('#FFFFFF');
  sheet.setRowHeight(kpiStartRow, 25);
  
  // Card 1: Total Net Worth
  sheet.getRange(kpiStartRow + 1, 1, 1, 2).merge().setValue('TOTAL NET WORTH').setFontSize(9).setFontWeight('bold').setFontColor('#475569').setBackground('#F8FAFC').setHorizontalAlignment('center');
  sheet.getRange(kpiStartRow + 2, 1, 1, 2).merge().setValue(totalBalance).setNumberFormat(currency + ' #,##0.00').setFontSize(13).setFontWeight('bold').setFontColor('#0F172A').setBackground('#F8FAFC').setHorizontalAlignment('center');
  
  // Card 2: Total Income
  sheet.getRange(kpiStartRow + 1, 3, 1, 2).merge().setValue('ALL-TIME INCOME').setFontSize(9).setFontWeight('bold').setFontColor('#16A34A').setBackground('#F0FDF4').setHorizontalAlignment('center');
  sheet.getRange(kpiStartRow + 2, 3, 1, 2).merge().setValue(totalIncome).setNumberFormat(currency + ' #,##0.00').setFontSize(13).setFontWeight('bold').setFontColor('#16A34A').setBackground('#F0FDF4').setHorizontalAlignment('center');
  
  // Card 3: Total Expenses
  sheet.getRange(kpiStartRow + 1, 5, 1, 2).merge().setValue('ALL-TIME EXPENSES').setFontSize(9).setFontWeight('bold').setFontColor('#DC2626').setBackground('#FEF2F2').setHorizontalAlignment('center');
  sheet.getRange(kpiStartRow + 2, 5, 1, 2).merge().setValue(totalExpense).setNumberFormat(currency + ' #,##0.00').setFontSize(13).setFontWeight('bold').setFontColor('#DC2626').setBackground('#FEF2F2').setHorizontalAlignment('center');
  
  // Card 4: Net Savings
  sheet.getRange(kpiStartRow + 1, 7, 1, 2).merge().setValue('NET SAVINGS (SURPLUS)').setFontSize(9).setFontWeight('bold').setFontColor(netSavings >= 0 ? '#16A34A' : '#DC2626').setBackground('#F8FAFC').setHorizontalAlignment('center');
  sheet.getRange(kpiStartRow + 2, 7, 1, 2).merge().setValue(netSavings).setNumberFormat(currency + ' #,##0.00').setFontSize(13).setFontWeight('bold').setFontColor(netSavings >= 0 ? '#16A34A' : '#DC2626').setBackground('#F8FAFC').setHorizontalAlignment('center');
  
  // Card 5: Savings Rate
  sheet.getRange(kpiStartRow + 1, 9, 1, 2).merge().setValue('SAVINGS RATE %').setFontSize(9).setFontWeight('bold').setFontColor('#2563EB').setBackground('#EFF6FF').setHorizontalAlignment('center');
  sheet.getRange(kpiStartRow + 2, 9, 1, 2).merge().setValue(savingsRate / 100).setNumberFormat('0.0%').setFontSize(13).setFontWeight('bold').setFontColor('#2563EB').setBackground('#EFF6FF').setHorizontalAlignment('center');
  
  sheet.getRange(kpiStartRow + 1, 1, 2, 10).setBorder(true, true, true, true, true, true, '#CBD5E1', SpreadsheetApp.BorderStyle.SOLID);
  sheet.setRowHeight(kpiStartRow + 1, 20);
  sheet.setRowHeight(kpiStartRow + 2, 28);
  
  // Row 8: SECTION: CATEGORY-WISE SPENDS & EMBEDDED PIE CHART
  var catStartRow = 8;
  sheet.getRange(catStartRow, 1, 1, 4).merge()
    .setValue('📊 ALL-TIME SPENDS BY CATEGORY')
    .setFontWeight('bold')
    .setFontSize(11)
    .setBackground('#1E293B')
    .setFontColor('#FFFFFF');
    
  sheet.getRange(catStartRow + 1, 1, 1, 4).setValues([['Category', 'Count', 'Spent (' + currency + ')', '% of Total']])
    .setFontWeight('bold')
    .setBackground('#334155')
    .setFontColor('#FFFFFF');
    
  var sortedCats = Object.keys(catTotals).sort(function(a, b) {
    return catTotals[b] - catTotals[a];
  });
  
  var catRows = [];
  for (var ci = 0; ci < sortedCats.length; ci++) {
    var cId = sortedCats[ci];
    var cAmt = catTotals[cId];
    var cCnt = catCounts[cId] || 0;
    var cPct = totalExpense > 0 ? (cAmt / totalExpense) : 0;
    catRows.push([cId.toUpperCase(), cCnt, cAmt, cPct]);
  }
  
  var catDataEndRow = catStartRow + 1;
  if (catRows.length > 0) {
    sheet.getRange(catStartRow + 2, 1, catRows.length, 4).setValues(catRows);
    sheet.getRange(catStartRow + 2, 2, catRows.length, 1).setNumberFormat('#,##0');
    sheet.getRange(catStartRow + 2, 3, catRows.length, 1).setNumberFormat(currency + ' #,##0.00');
    sheet.getRange(catStartRow + 2, 4, catRows.length, 1).setNumberFormat('0.0%');
    
    // Total row
    catDataEndRow = catStartRow + 2 + catRows.length;
    sheet.getRange(catDataEndRow, 1).setValue('TOTAL EXPENSES').setFontWeight('bold');
    sheet.getRange(catDataEndRow, 2).setValue(txs.filter(function(x) { return x.type === 'expense'; }).length).setFontWeight('bold');
    sheet.getRange(catDataEndRow, 3).setValue(totalExpense).setNumberFormat(currency + ' #,##0.00').setFontWeight('bold').setFontColor('#DC2626');
    sheet.getRange(catDataEndRow, 4).setValue(1.0).setNumberFormat('0.0%').setFontWeight('bold');
    sheet.getRange(catDataEndRow, 1, 1, 4).setBackground('#F1F5F9');
    
    sheet.getRange(catStartRow + 1, 1, catRows.length + 2, 4).setBorder(true, true, true, true, true, true, '#CBD5E1', SpreadsheetApp.BorderStyle.SOLID);
    
    // EMBED DONUT PIE CHART AT COLUMN E
    var pieChart = sheet.newChart()
      .setChartType(Charts.ChartType.PIE)
      .addRange(sheet.getRange(catStartRow + 1, 1, catRows.length + 1, 1))
      .addRange(sheet.getRange(catStartRow + 1, 3, catRows.length + 1, 1))
      .setPosition(catStartRow, 5, 10, 0)
      .setOption('title', 'Category Expense Distribution')
      .setOption('titleTextStyle', { fontSize: 13, bold: true, color: '#1E293B' })
      .setOption('pieHole', 0.40)
      .setOption('width', 460)
      .setOption('height', 270)
      .setOption('chartArea', { left: 15, top: 35, width: '90%', height: '80%' })
      .setOption('legend', { position: 'right' })
      .build();
    sheet.insertChart(pieChart);
  }
  
  // Row below category: PAYMENT MODES BREAKDOWN
  var payStartRow = catDataEndRow + 2;
  sheet.getRange(payStartRow, 1, 1, 4).merge()
    .setValue('💳 PAYMENT MODES BREAKDOWN')
    .setFontWeight('bold')
    .setFontSize(11)
    .setBackground('#1E293B')
    .setFontColor('#FFFFFF');
    
  sheet.getRange(payStartRow + 1, 1, 1, 4).setValues([['Mode', 'Tx Count', 'Amount (' + currency + ')', 'Share']])
    .setFontWeight('bold')
    .setBackground('#334155')
    .setFontColor('#FFFFFF');
    
  var payRows = [];
  for (var pm in payModeTotals) {
    var pAmt = payModeTotals[pm];
    var pCnt = payModeCounts[pm] || 0;
    var pShare = totalExpense > 0 ? (pAmt / totalExpense) : 0;
    payRows.push([pm.toUpperCase(), pCnt, pAmt, pShare]);
  }
  
  var payEndRow = payStartRow + 1;
  if (payRows.length > 0) {
    sheet.getRange(payStartRow + 2, 1, payRows.length, 4).setValues(payRows);
    sheet.getRange(payStartRow + 2, 2, payRows.length, 1).setNumberFormat('#,##0');
    sheet.getRange(payStartRow + 2, 3, payRows.length, 1).setNumberFormat(currency + ' #,##0.00');
    sheet.getRange(payStartRow + 2, 4, payRows.length, 1).setNumberFormat('0.0%');
    payEndRow = payStartRow + 1 + payRows.length;
    sheet.getRange(payStartRow + 1, 1, payRows.length + 1, 4).setBorder(true, true, true, true, true, true, '#CBD5E1', SpreadsheetApp.BorderStyle.SOLID);
  }
  
  // MONTH-WISE PERFORMANCE & METRICS MATRIX SECTION
  var monthStartRow = Math.max(payEndRow + 3, catStartRow + 14);
  
  sheet.getRange(monthStartRow, 1, 1, 10).merge()
    .setValue('📅 MONTH-WISE FINANCIAL PERFORMANCE & SUMMARY MATRIX')
    .setFontWeight('bold')
    .setFontSize(12)
    .setBackground('#1E293B')
    .setFontColor('#FFFFFF')
    .setHorizontalAlignment('left');
  sheet.setRowHeight(monthStartRow, 28);
  
  var monthHeaders = [
    'Month',
    'Total Income (' + currency + ')',
    'Total Expense (' + currency + ')',
    'Total Profit (' + currency + ')',
    'Total Loss (' + currency + ')',
    'Savings Rate',
    'Daily Avg Spend',
    'Highest Spend Day',
    'Top Spend Category',
    'Tx Count'
  ];
  
  sheet.getRange(monthStartRow + 1, 1, 1, 10).setValues([monthHeaders])
    .setFontWeight('bold')
    .setBackground('#475569')
    .setFontColor('#FFFFFF')
    .setHorizontalAlignment('center');
  sheet.setRowHeight(monthStartRow + 1, 24);
  
  var sortedMonthsList = Object.keys(monthStats).sort().reverse();
  var monthTableRows = [];
  
  for (var mi = 0; mi < sortedMonthsList.length; mi++) {
    var msKey = sortedMonthsList[mi];
    var mData = monthStats[msKey];
    var mInc = mData.income;
    var mExp = mData.expense;
    var mProfit = mInc > mExp ? (mInc - mExp) : 0;
    var mLoss = mExp > mInc ? (mExp - mInc) : 0;
    var mSavingsRate = mInc > 0 ? (mProfit - mLoss) / mInc : 0;
    var mDailyAvg = mExp / 30;
    
    var highestDay = 'N/A';
    var maxDayExp = 0;
    for (var dk in mData.dayExpenses) {
      if (mData.dayExpenses[dk] > maxDayExp) {
        maxDayExp = mData.dayExpenses[dk];
        highestDay = dk + ' (' + currency + ' ' + Utilities.formatString('%,.2f', maxDayExp) + ')';
      }
    }
    
    var topCat = 'N/A';
    var maxCatExp = 0;
    for (var ck in mData.catExpenses) {
      if (mData.catExpenses[ck] > maxCatExp) {
        maxCatExp = mData.catExpenses[ck];
        topCat = ck.toUpperCase() + ' (' + currency + ' ' + Utilities.formatString('%,.2f', maxCatExp) + ')';
      }
    }
    
    monthTableRows.push([
      mData.label,
      mInc,
      mExp,
      mProfit,
      mLoss,
      mSavingsRate,
      mDailyAvg,
      highestDay,
      topCat,
      mData.txCount
    ]);
  }
  
  if (monthTableRows.length > 0) {
    var startDataRow = monthStartRow + 2;
    sheet.getRange(startDataRow, 1, monthTableRows.length, 10).setValues(monthTableRows);
    
    sheet.getRange(startDataRow, 2, monthTableRows.length, 4).setNumberFormat(currency + ' #,##0.00');
    sheet.getRange(startDataRow, 6, monthTableRows.length, 1).setNumberFormat('0.0%');
    sheet.getRange(startDataRow, 7, monthTableRows.length, 1).setNumberFormat(currency + ' #,##0.00');
    sheet.getRange(startDataRow, 10, monthTableRows.length, 1).setNumberFormat('#,##0');
    
    for (var rIdx = 0; rIdx < monthTableRows.length; rIdx++) {
      var curRow = startDataRow + rIdx;
      sheet.getRange(curRow, 2).setFontColor('#16A34A').setFontWeight('bold');
      sheet.getRange(curRow, 3).setFontColor('#DC2626').setFontWeight('bold');
      sheet.getRange(curRow, 4).setFontColor('#16A34A').setFontWeight('bold');
      sheet.getRange(curRow, 5).setFontColor('#DC2626').setFontWeight('bold');
      
      var bg = (rIdx % 2 === 0) ? '#FFFFFF' : '#F8FAFC';
      sheet.getRange(curRow, 1).setBackground(bg).setFontWeight('bold');
      sheet.getRange(curRow, 6, 1, 5).setBackground(bg);
    }
    
    var summaryEndRow = startDataRow + monthTableRows.length;
    sheet.getRange(summaryEndRow, 1).setValue('TOTAL / OVERALL').setFontWeight('bold');
    sheet.getRange(summaryEndRow, 2).setValue(totalIncome).setNumberFormat(currency + ' #,##0.00').setFontWeight('bold').setFontColor('#16A34A');
    sheet.getRange(summaryEndRow, 3).setValue(totalExpense).setNumberFormat(currency + ' #,##0.00').setFontWeight('bold').setFontColor('#DC2626');
    sheet.getRange(summaryEndRow, 4).setValue(netSavings > 0 ? netSavings : 0).setNumberFormat(currency + ' #,##0.00').setFontWeight('bold').setFontColor('#16A34A');
    sheet.getRange(summaryEndRow, 5).setValue(netSavings < 0 ? -netSavings : 0).setNumberFormat(currency + ' #,##0.00').setFontWeight('bold').setFontColor('#DC2626');
    sheet.getRange(summaryEndRow, 6).setValue(savingsRate / 100).setNumberFormat('0.0%').setFontWeight('bold');
    sheet.getRange(summaryEndRow, 7).setValue(avgMonthlySpend / 30).setNumberFormat(currency + ' #,##0.00').setFontWeight('bold');
    sheet.getRange(summaryEndRow, 8, 1, 2).setValue('-');
    sheet.getRange(summaryEndRow, 10).setValue(txs.length).setNumberFormat('#,##0').setFontWeight('bold');
    sheet.getRange(summaryEndRow, 1, 1, 10).setBackground('#E2E8F0');
    
    sheet.getRange(monthStartRow + 1, 1, monthTableRows.length + 2, 10)
      .setBorder(true, true, true, true, true, true, '#CBD5E1', SpreadsheetApp.BorderStyle.SOLID);
      
    var barChart = sheet.newChart()
      .setChartType(Charts.ChartType.COLUMN)
      .addRange(sheet.getRange(monthStartRow + 1, 1, Math.min(monthTableRows.length, 12) + 1, 3))
      .setPosition(payStartRow, 5, 10, 0)
      .setOption('title', 'Monthly Income vs Expense Cashflow')
      .setOption('titleTextStyle', { fontSize: 13, bold: true, color: '#1E293B' })
      .setOption('colors', ['#16A34A', '#DC2626'])
      .setOption('width', 460)
      .setOption('height', 270)
      .setOption('chartArea', { left: 50, top: 40, width: '85%', height: '70%' })
      .setOption('legend', { position: 'top' })
      .build();
    sheet.insertChart(barChart);
  }
  
  for (var col = 1; col <= 10; col++) {
    sheet.autoResizeColumn(col);
  }
  
  sheet.setFrozenRows(2);
  return sheet;
}

// -------------------------------------------------------------------
// 2. FORMATTED MONTH-WISE SHEETS WITH GROUPED CATEGORY SPENDS
// -------------------------------------------------------------------

function updateMonthlySheets(ss, txs, accounts, currency) {
  var monthGroups = {};
  var monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  
  var accMap = {};
  for (var a = 0; a < accounts.length; a++) {
    accMap[accounts[a].id] = accounts[a].name;
  }
  
  for (var i = 0; i < txs.length; i++) {
    var t = txs[i];
    var dt = new Date(t.dateTime);
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
    
    var groupTxs = monthGroups[mKey];
    groupTxs.sort(function(a, b) {
      return new Date(b.dateTime) - new Date(a.dateTime);
    });
    
    var mIncome = 0;
    var mExpense = 0;
    var catSums = {};
    var catCounts = {};
    
    for (var j = 0; j < groupTxs.length; j++) {
      var item = groupTxs[j];
      if (item.type === 'income') mIncome += item.amount;
      if (item.type === 'expense') {
        mExpense += item.amount;
        catSums[item.categoryId] = (catSums[item.categoryId] || 0) + item.amount;
        catCounts[item.categoryId] = (catCounts[item.categoryId] || 0) + 1;
      }
    }
    var mNet = mIncome - mExpense;
    var mDailyAvg = mExpense / 30;
    
    // Header Banner
    sheet.getRange('A1:I1').merge()
      .setValue('📅 ' + mKey + ' Financial Overview & Spend Breakdown')
      .setFontSize(13)
      .setFontWeight('bold')
      .setBackground('#0F172A')
      .setFontColor('#FFFFFF')
      .setHorizontalAlignment('center')
      .setVerticalAlignment('middle');
    sheet.setRowHeight(1, 36);
      
    // Quick KPI Row
    sheet.getRange('A2:B2').merge().setValue('Total Income: ' + currency + ' ' + Utilities.formatString('%,.2f', mIncome))
      .setFontWeight('bold').setFontColor('#16A34A').setBackground('#F0FDF4');
    sheet.getRange('C2:D2').merge().setValue('Total Expense: ' + currency + ' ' + Utilities.formatString('%,.2f', mExpense))
      .setFontWeight('bold').setFontColor('#DC2626').setBackground('#FEF2F2');
    sheet.getRange('E2:F2').merge().setValue('Net: ' + currency + ' ' + Utilities.formatString('%,.2f', mNet))
      .setFontWeight('bold').setFontColor(mNet >= 0 ? '#16A34A' : '#DC2626').setBackground('#F8FAFC');
    sheet.getRange('G2:H2').merge().setValue('Daily Spend Avg: ' + currency + ' ' + Utilities.formatString('%,.2f', mDailyAvg))
      .setFontWeight('bold').setFontColor('#D97706').setBackground('#FFFBEB');
    sheet.getRange('I2').setValue('Entries: ' + groupTxs.length)
      .setFontWeight('bold').setFontColor('#334155').setBackground('#F1F5F9');
      
    sheet.getRange('A2:I2').setBorder(true, true, true, true, true, true, '#CBD5E1', SpreadsheetApp.BorderStyle.SOLID);
    sheet.setRowHeight(2, 26);
    
    // Grouped Spends by Category Section
    sheet.getRange(4, 1, 1, 4).merge()
      .setValue('📊 ' + mKey.toUpperCase() + ' - SPENDS GROUPED BY CATEGORY')
      .setFontWeight('bold')
      .setFontSize(11)
      .setBackground('#1E293B')
      .setFontColor('#FFFFFF');
    sheet.setRowHeight(4, 24);
      
    sheet.getRange(5, 1, 1, 4).setValues([['Category', 'Count', 'Total Spent (' + currency + ')', '% of Month Spends']])
      .setFontWeight('bold')
      .setBackground('#334155')
      .setFontColor('#FFFFFF');
      
    var sortedCats = Object.keys(catSums).sort(function(a, b) {
      return catSums[b] - catSums[a];
    });
    
    var catRows = [];
    for (var sc = 0; sc < sortedCats.length; sc++) {
      var cName = sortedCats[sc];
      var amt = catSums[cName];
      var cnt = catCounts[cName];
      var pct = mExpense > 0 ? (amt / mExpense) : 0;
      catRows.push([cName.toUpperCase(), cnt, amt, pct]);
    }
    
    var afterCatRow = 6;
    if (catRows.length > 0) {
      sheet.getRange(6, 1, catRows.length, 4).setValues(catRows);
      sheet.getRange(6, 2, catRows.length, 1).setNumberFormat('#,##0');
      sheet.getRange(6, 3, catRows.length, 1).setNumberFormat(currency + ' #,##0.00');
      sheet.getRange(6, 4, catRows.length, 1).setNumberFormat('0.0%');
      
      var totRow = 6 + catRows.length;
      sheet.getRange(totRow, 1).setValue('TOTAL EXPENSES').setFontWeight('bold');
      sheet.getRange(totRow, 2).setValue(groupTxs.filter(function(x) { return x.type === 'expense'; }).length).setFontWeight('bold');
      sheet.getRange(totRow, 3).setValue(mExpense).setNumberFormat(currency + ' #,##0.00').setFontWeight('bold').setFontColor('#DC2626');
      sheet.getRange(totRow, 4).setValue(1.0).setNumberFormat('0.0%').setFontWeight('bold');
      sheet.getRange(totRow, 1, 1, 4).setBackground('#F1F5F9');
      
      sheet.getRange(5, 1, catRows.length + 2, 4).setBorder(true, true, true, true, true, true, '#CBD5E1', SpreadsheetApp.BorderStyle.SOLID);
      afterCatRow = totRow + 2;
    }
    
    // Detailed Transactions Log Table
    sheet.getRange(afterCatRow, 1, 1, 9).merge()
      .setValue('📝 DETAILED TRANSACTIONS LOG (' + groupTxs.length + ' entries)')
      .setFontWeight('bold')
      .setFontSize(11)
      .setBackground('#1E293B')
      .setFontColor('#FFFFFF');
    sheet.setRowHeight(afterCatRow, 24);
      
    var txHeaders = [
      'Date',
      'Time',
      'Type',
      'Title',
      'Category',
      'Amount (' + currency + ')',
      'Payment Mode',
      'Account',
      'Note'
    ];
    sheet.getRange(afterCatRow + 1, 1, 1, 9).setValues([txHeaders])
      .setFontWeight('bold')
      .setBackground('#475569')
      .setFontColor('#FFFFFF');
    sheet.setRowHeight(afterCatRow + 1, 24);
      
    var txRows = [];
    for (var tIdx = 0; tIdx < groupTxs.length; tIdx++) {
      var item = groupTxs[tIdx];
      var d = new Date(item.dateTime);
      var dateStr = Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM-dd');
      var timeStr = Utilities.formatDate(d, Session.getScriptTimeZone(), 'HH:mm');
      var accName = accMap[item.accountId] || item.accountId;
      var toAccName = item.toAccountId ? (accMap[item.toAccountId] || item.toAccountId) : null;
      var accDisplay = (item.type === 'transfer' && toAccName) ? (accName + ' → ' + toAccName) : accName;
      
      txRows.push([
        dateStr,
        timeStr,
        item.type.toUpperCase(),
        item.title,
        (item.categoryId || '').toUpperCase(),
        item.amount,
        item.paymentMode,
        accDisplay,
        item.note || ''
      ]);
    }
    
    if (txRows.length > 0) {
      var txStartRow = afterCatRow + 2;
      sheet.getRange(txStartRow, 1, txRows.length, 9).setValues(txRows);
      sheet.getRange(txStartRow, 6, txRows.length, 1).setNumberFormat(currency + ' #,##0.00');
      
      for (var tr = 0; tr < txRows.length; tr++) {
        var r = txStartRow + tr;
        var tType = txRows[tr][2];
        var amtCell = sheet.getRange(r, 6);
        var typeCell = sheet.getRange(r, 3);
        
        if (tType === 'INCOME') {
          amtCell.setFontColor('#16A34A').setFontWeight('bold');
          typeCell.setFontColor('#16A34A').setFontWeight('bold').setBackground('#DCFCE7');
        } else if (tType === 'EXPENSE') {
          amtCell.setFontColor('#DC2626').setFontWeight('bold');
          typeCell.setFontColor('#DC2626').setFontWeight('bold').setBackground('#FEE2E2');
        } else {
          amtCell.setFontColor('#4F46E5').setFontWeight('bold');
          typeCell.setFontColor('#4F46E5').setFontWeight('bold').setBackground('#EEF2FF');
        }
        
        var bg = (tr % 2 === 0) ? '#FFFFFF' : '#F8FAFC';
        sheet.getRange(r, 1, 1, 2).setBackground(bg);
        sheet.getRange(r, 4, 1, 6).setBackground(bg);
      }
      
      sheet.getRange(afterCatRow + 1, 1, txRows.length + 1, 9)
        .setBorder(true, true, true, true, true, true, '#CBD5E1', SpreadsheetApp.BorderStyle.SOLID);
    }
    
    for (var c = 1; c <= 9; c++) {
      sheet.autoResizeColumn(c);
    }
    
    sheet.setFrozenRows(2);
  }
}

// -------------------------------------------------------------------
// 3. MASTER TRANSACTIONS SHEET (LOSSLESS DATABASE)
// -------------------------------------------------------------------

function updateMasterTransactionsSheet(ss, txs, accounts, currency) {
  var sheet = ss.getSheetByName('All_Transactions');
  if (!sheet) {
    sheet = ss.insertSheet('All_Transactions');
  }
  sheet.clear();
  
  sheet.getRange('A1:J1').merge()
    .setValue('💾 ALL TRANSACTIONS MASTER DATABASE (' + txs.length + ' records)')
    .setFontWeight('bold')
    .setFontSize(12)
    .setFontColor('#FFFFFF')
    .setBackground('#0F172A')
    .setHorizontalAlignment('center')
    .setVerticalAlignment('middle');
  sheet.setRowHeight(1, 32);
  
  var headers = ['ID', 'DateTime', 'Type', 'Amount (' + currency + ')', 'Title', 'CategoryId', 'AccountId', 'ToAccountId', 'PaymentMode', 'Note'];
  sheet.getRange(2, 1, 1, headers.length).setValues([headers])
    .setFontWeight('bold')
    .setBackground('#1E293B')
    .setFontColor('#FFFFFF');
  sheet.setRowHeight(2, 24);
  
  if (txs.length > 0) {
    var rows = [];
    for (var i = 0; i < txs.length; i++) {
      var t = txs[i];
      rows.push([
        t.id,
        t.dateTime,
        t.type.toUpperCase(),
        t.amount,
        t.title,
        t.categoryId,
        t.accountId,
        t.toAccountId || '',
        t.paymentMode,
        t.note || ''
      ]);
    }
    sheet.getRange(3, 1, rows.length, headers.length).setValues(rows);
    sheet.getRange(3, 4, rows.length, 1).setNumberFormat(currency + ' #,##0.00');
    
    for (var rIdx = 0; rIdx < rows.length; rIdx++) {
      var curRow = 3 + rIdx;
      var tType = rows[rIdx][2];
      var amtCell = sheet.getRange(curRow, 4);
      if (tType === 'INCOME') amtCell.setFontColor('#16A34A').setFontWeight('bold');
      if (tType === 'EXPENSE') amtCell.setFontColor('#DC2626').setFontWeight('bold');
      
      var bg = (rIdx % 2 === 0) ? '#FFFFFF' : '#F8FAFC';
      sheet.getRange(curRow, 1, 1, 3).setBackground(bg);
      sheet.getRange(curRow, 5, 1, 6).setBackground(bg);
    }
    
    sheet.getRange(2, 1, rows.length + 1, headers.length)
      .setBorder(true, true, true, true, true, true, '#CBD5E1', SpreadsheetApp.BorderStyle.SOLID);
  }
  
  for (var col = 1; col <= headers.length; col++) {
    sheet.autoResizeColumn(col);
  }
  sheet.setFrozenRows(2);
  
  return sheet;
}

// -------------------------------------------------------------------
// 4. ACCOUNTS SHEET
// -------------------------------------------------------------------

function updateAccountsSheet(ss, accs, currency) {
  var sheet = ss.getSheetByName('Accounts');
  if (!sheet) {
    sheet = ss.insertSheet('Accounts');
  }
  sheet.clear();
  
  sheet.getRange('A1:F1').merge()
    .setValue('💳 CONNECTED ACCOUNTS & BALANCES (' + accs.length + ' accounts)')
    .setFontWeight('bold')
    .setFontSize(12)
    .setFontColor('#FFFFFF')
    .setBackground('#0D9488')
    .setHorizontalAlignment('center')
    .setVerticalAlignment('middle');
  sheet.setRowHeight(1, 32);
  
  var headers = ['ID', 'Account Name', 'Type', 'Balance (' + currency + ')', 'Color Value', 'Share of Wealth'];
  sheet.getRange(2, 1, 1, headers.length).setValues([headers])
    .setFontWeight('bold')
    .setBackground('#0F766E')
    .setFontColor('#FFFFFF');
  sheet.setRowHeight(2, 24);
  
  var totalBal = 0;
  for (var k = 0; k < accs.length; k++) totalBal += accs[k].balance;
  
  if (accs.length > 0) {
    var rows = [];
    for (var i = 0; i < accs.length; i++) {
      var a = accs[i];
      var share = totalBal > 0 ? (a.balance / totalBal) : 0;
      rows.push([a.id, a.name, a.type.toUpperCase(), a.balance, a.colorValue, share]);
    }
    sheet.getRange(3, 1, rows.length, headers.length).setValues(rows);
    sheet.getRange(3, 4, rows.length, 1).setNumberFormat(currency + ' #,##0.00').setFontWeight('bold').setFontColor('#0F172A');
    sheet.getRange(3, 6, rows.length, 1).setNumberFormat('0.0%').setFontWeight('bold').setFontColor('#0D9488');
    
    var totR = 3 + rows.length;
    sheet.getRange(totR, 1, 1, 3).merge().setValue('TOTAL NET WORTH').setFontWeight('bold');
    sheet.getRange(totR, 4).setValue(totalBal).setNumberFormat(currency + ' #,##0.00').setFontWeight('bold').setFontColor('#0D9488');
    sheet.getRange(totR, 5).setValue('-');
    sheet.getRange(totR, 6).setValue(1.0).setNumberFormat('0.0%').setFontWeight('bold');
    sheet.getRange(totR, 1, 1, headers.length).setBackground('#E2E8F0');
    
    sheet.getRange(2, 1, rows.length + 2, headers.length)
      .setBorder(true, true, true, true, true, true, '#CBD5E1', SpreadsheetApp.BorderStyle.SOLID);
  }
  
  for (var col = 1; col <= headers.length; col++) {
    sheet.autoResizeColumn(col);
  }
  sheet.setFrozenRows(2);
  
  return sheet;
}

// -------------------------------------------------------------------
// 5. RESTORE DATA READERS
// -------------------------------------------------------------------

function readTransactions(ss) {
  var sheet = ss.getSheetByName('All_Transactions');
  if (!sheet) return [];
  var data = sheet.getDataRange().getValues();
  if (data.length <= 2) return [];
  
  var results = [];
  for (var i = 2; i < data.length; i++) {
    var row = data[i];
    if (!row[0]) continue;
    results.push({
      id: String(row[0]),
      dateTime: String(row[1]),
      type: String(row[2]).toLowerCase(),
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
  if (data.length <= 2) return [];
  
  var results = [];
  for (var i = 2; i < data.length; i++) {
    var row = data[i];
    if (!row[0]) continue;
    results.push({
      id: String(row[0]),
      name: String(row[1]),
      type: String(row[2]).toLowerCase(),
      balance: Number(row[3]) || 0,
      colorValue: Number(row[4]) || 0xFF0D9488
    });
  }
  return results;
}
