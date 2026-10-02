import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class ExcelExportResult {
  final String filePath;
  final int transactionCount;
  final int monthCount;

  const ExcelExportResult({
    required this.filePath,
    required this.transactionCount,
    required this.monthCount,
  });
}

class ExcelImportResult {
  final List<TransactionModel> transactions;
  final List<Account> accounts;
  final String fileName;

  const ExcelImportResult({
    required this.transactions,
    required this.accounts,
    required this.fileName,
  });
}

class ExcelService {
  /// Generate the complete Excel workbook with:
  /// 1. 📊 Dashboard sheet with KPIs, category breakdown & monthly summary
  /// 2. Month-wise sheets (e.g. Sep 2026, Aug 2026)
  /// 3. All_Transactions master sheet for lossless restore
  /// 4. Accounts sheet
  static Uint8List generateWorkbook({
    required List<TransactionModel> transactions,
    required List<Account> accounts,
    required String currency,
  }) {
    final excel = Excel.createExcel();

    // Default Sheet1 handling
    final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';

    // ---------------------------------------------------------
    // 1. DASHBOARD SHEET
    // ---------------------------------------------------------
    const dashSheetName = '📊 Dashboard';
    final dash = excel[dashSheetName];
    excel.setDefaultSheet(dashSheetName);

    // Styles
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#0D9488'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final sectionHeaderStyle = CellStyle(
      bold: true,
      fontSize: 12,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
    );

    final tableHeaderStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#334155'),
    );

    final kpiLabelStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#475569'),
      backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
    );

    final kpiValueStyle = CellStyle(
      bold: true,
      fontSize: 12,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'),
    );

    final incomeValueStyle = CellStyle(
      bold: true,
      fontSize: 12,
      fontColorHex: ExcelColor.fromHexString('#16A34A'),
      backgroundColorHex: ExcelColor.fromHexString('#F0FDF4'),
    );

    final expenseValueStyle = CellStyle(
      bold: true,
      fontSize: 12,
      fontColorHex: ExcelColor.fromHexString('#DC2626'),
      backgroundColorHex: ExcelColor.fromHexString('#FEF2F2'),
    );

    // Dashboard Banner
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('EXPENSE TRACKER FINANCIAL DASHBOARD')
      ..cellStyle = titleStyle;
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
      ..value = TextCellValue('')
      ..cellStyle = titleStyle;
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
      ..value = TextCellValue('')
      ..cellStyle = titleStyle;
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0))
      ..value = TextCellValue('')
      ..cellStyle = titleStyle;

    final nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
        TextCellValue('Generated on: $nowStr | Currency: $currency');

    // KPI Metrics calculation
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.income) totalIncome += tx.amount;
      if (tx.type == TransactionType.expense) totalExpense += tx.amount;
    }
    final netSavings = totalIncome - totalExpense;
    final totalBalance = accounts.fold(0.0, (sum, acc) => sum + acc.balance);

    // KPI Summary Table
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
      ..value = TextCellValue('FINANCIAL SUMMARY METRICS')
      ..cellStyle = sectionHeaderStyle;
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3))
      ..value = TextCellValue('AMOUNT ($currency)')
      ..cellStyle = sectionHeaderStyle;

    final kpis = [
      ('Total Current Balance (Accounts)', totalBalance, kpiValueStyle),
      ('Total Income', totalIncome, incomeValueStyle),
      ('Total Expenses', totalExpense, expenseValueStyle),
      ('Net Savings', netSavings, netSavings >= 0 ? incomeValueStyle : expenseValueStyle),
      ('Total Recorded Transactions', transactions.length.toDouble(), kpiValueStyle),
    ];

    for (int i = 0; i < kpis.length; i++) {
      final rowIdx = 4 + i;
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
        ..value = TextCellValue(kpis[i].$1)
        ..cellStyle = kpiLabelStyle;
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx))
        ..value = DoubleCellValue(kpis[i].$2)
        ..cellStyle = kpis[i].$3;
    }

    // Category Expense Breakdown
    const catHeaderRow = 10;
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: catHeaderRow))
      ..value = TextCellValue('EXPENSE BREAKDOWN BY CATEGORY')
      ..cellStyle = sectionHeaderStyle;
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: catHeaderRow))
      ..value = TextCellValue('COUNT')
      ..cellStyle = sectionHeaderStyle;
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: catHeaderRow))
      ..value = TextCellValue('TOTAL ($currency)')
      ..cellStyle = sectionHeaderStyle;
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: catHeaderRow))
      ..value = TextCellValue('% OF EXPENSES')
      ..cellStyle = sectionHeaderStyle;

    final Map<String, double> categorySums = {};
    final Map<String, int> categoryCounts = {};
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense) {
        categorySums[tx.categoryId] = (categorySums[tx.categoryId] ?? 0.0) + tx.amount;
        categoryCounts[tx.categoryId] = (categoryCounts[tx.categoryId] ?? 0) + 1;
      }
    }

    final sortedCats = categorySums.keys.toList()
      ..sort((a, b) => (categorySums[b] ?? 0).compareTo(categorySums[a] ?? 0));

    int currentCatRow = catHeaderRow + 1;
    for (final catId in sortedCats) {
      final cat = ExpenseCategory.findById(catId);
      final sum = categorySums[catId] ?? 0.0;
      final count = categoryCounts[catId] ?? 0;
      final percent = totalExpense > 0 ? (sum / totalExpense) * 100 : 0.0;

      dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentCatRow)).value =
          TextCellValue(cat.name);
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentCatRow)).value =
          IntCellValue(count);
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentCatRow)).value =
          DoubleCellValue(sum);
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentCatRow)).value =
          TextCellValue('${percent.toStringAsFixed(1)}%');
      currentCatRow++;
    }

    // Payment Mode Breakdown
    final payHeaderRow = currentCatRow + 1;
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: payHeaderRow))
      ..value = TextCellValue('PAYMENT MODE BREAKDOWN')
      ..cellStyle = sectionHeaderStyle;
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: payHeaderRow))
      ..value = TextCellValue('TX COUNT')
      ..cellStyle = sectionHeaderStyle;
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: payHeaderRow))
      ..value = TextCellValue('TOTAL SPENT ($currency)')
      ..cellStyle = sectionHeaderStyle;

    final Map<PaymentMode, double> modeSums = {};
    final Map<PaymentMode, int> modeCounts = {};
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense) {
        modeSums[tx.paymentMode] = (modeSums[tx.paymentMode] ?? 0.0) + tx.amount;
        modeCounts[tx.paymentMode] = (modeCounts[tx.paymentMode] ?? 0) + 1;
      }
    }

    int currentPayRow = payHeaderRow + 1;
    for (final mode in PaymentMode.values) {
      final sum = modeSums[mode] ?? 0.0;
      final count = modeCounts[mode] ?? 0;
      if (count > 0 || sum > 0) {
        dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentPayRow)).value =
            TextCellValue(mode.displayName);
        dash.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentPayRow)).value =
            IntCellValue(count);
        dash.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentPayRow)).value =
            DoubleCellValue(sum);
        currentPayRow++;
      }
    }

    // Month-Wise Financial Performance Table
    final monthHeaderRow = currentPayRow + 2;
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: monthHeaderRow))
      ..value = TextCellValue('MONTH-WISE FINANCIAL PERFORMANCE & SUMMARY')
      ..cellStyle = sectionHeaderStyle;
    final mDashHeaders = [
      'MONTH',
      'INCOME ($currency)',
      'EXPENSE ($currency)',
      'PROFIT ($currency)',
      'LOSS ($currency)',
      'HIGHEST TRANSACTION DAY',
      'TOP SPEND CATEGORY',
      'TX COUNT'
    ];
    final mDashHeadRow = monthHeaderRow + 1;
    for (int mi = 0; mi < mDashHeaders.length; mi++) {
      dash.cell(CellIndex.indexByColumnRow(columnIndex: mi, rowIndex: mDashHeadRow))
        ..value = TextCellValue(mDashHeaders[mi])
        ..cellStyle = tableHeaderStyle;
    }

    final Map<String, List<TransactionModel>> allMonthGroups = {};
    for (final tx in transactions) {
      final k = DateFormat('yyyy-MM').format(tx.dateTime);
      allMonthGroups.putIfAbsent(k, () => []).add(tx);
    }
    final sortedMonthKeys = allMonthGroups.keys.toList()..sort((a, b) => b.compareTo(a));

    int currentMonthRow = mDashHeadRow + 1;
    for (final mKey in sortedMonthKeys) {
      final mList = allMonthGroups[mKey]!;
      final monthDisplay = DateFormat('MMM yyyy').format(DateTime.parse('$mKey-01'));
      double mInc = 0.0;
      double mExp = 0.0;
      final Map<String, double> dayExpenses = {};
      final Map<String, double> catExpenses = {};

      for (final tx in mList) {
        final dayStr = DateFormat('yyyy-MM-dd').format(tx.dateTime);
        if (tx.type == TransactionType.income) {
          mInc += tx.amount;
        } else if (tx.type == TransactionType.expense) {
          mExp += tx.amount;
          dayExpenses[dayStr] = (dayExpenses[dayStr] ?? 0.0) + tx.amount;
          catExpenses[tx.categoryId] = (catExpenses[tx.categoryId] ?? 0.0) + tx.amount;
        }
      }

      final profit = mInc > mExp ? mInc - mExp : 0.0;
      final loss = mExp > mInc ? mExp - mInc : 0.0;

      String highestDay = 'N/A';
      double maxDaySpend = 0.0;
      for (final e in dayExpenses.entries) {
        if (e.value > maxDaySpend) {
          maxDaySpend = e.value;
          highestDay = '${e.key} ($currency${maxDaySpend.toStringAsFixed(2)})';
        }
      }

      String topCat = 'N/A';
      double maxCatSpend = 0.0;
      for (final e in catExpenses.entries) {
        if (e.value > maxCatSpend) {
          maxCatSpend = e.value;
          final c = ExpenseCategory.findById(e.key);
          topCat = '${c.name} ($currency${maxCatSpend.toStringAsFixed(2)})';
        }
      }

      dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentMonthRow)).value =
          TextCellValue(monthDisplay);
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentMonthRow))
        ..value = DoubleCellValue(mInc)
        ..cellStyle = incomeValueStyle;
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentMonthRow))
        ..value = DoubleCellValue(mExp)
        ..cellStyle = expenseValueStyle;
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentMonthRow))
        ..value = DoubleCellValue(profit)
        ..cellStyle = profit > 0 ? incomeValueStyle : kpiValueStyle;
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentMonthRow))
        ..value = DoubleCellValue(loss)
        ..cellStyle = loss > 0 ? expenseValueStyle : kpiValueStyle;
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentMonthRow)).value =
          TextCellValue(highestDay);
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentMonthRow)).value =
          TextCellValue(topCat);
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentMonthRow)).value =
          IntCellValue(mList.length);

      currentMonthRow++;
    }

    // ---------------------------------------------------------
    // 2. MONTH-WISE SHEETS
    // ---------------------------------------------------------
    // Group transactions by Year-Month (e.g. "Sep 2026")
    final Map<String, List<TransactionModel>> monthGroups = {};
    for (final tx in transactions) {
      final key = DateFormat('MMM yyyy').format(tx.dateTime);
      monthGroups.putIfAbsent(key, () => []).add(tx);
    }

    // Account map for quick lookup
    final accountMap = {for (var a in accounts) a.id: a.name};

    for (final entry in monthGroups.entries) {
      final monthName = entry.key;
      final mTransactions = entry.value
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

      final sheet = excel[monthName];

      // Month Header Summary
      double mIncome = 0.0;
      double mExpense = 0.0;
      for (final tx in mTransactions) {
        if (tx.type == TransactionType.income) mIncome += tx.amount;
        if (tx.type == TransactionType.expense) mExpense += tx.amount;
      }
      final mNet = mIncome - mExpense;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('$monthName Overview')
        ..cellStyle = titleStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
          TextCellValue('Income: $currency${mIncome.toStringAsFixed(2)}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value =
          TextCellValue('Expense: $currency${mExpense.toStringAsFixed(2)}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value =
          TextCellValue('Net: $currency${mNet.toStringAsFixed(2)}');

      // Table Headers
      final headers = [
        'Date',
        'Time',
        'Type',
        'Title',
        'Category',
        'Amount ($currency)',
        'Payment Mode',
        'Account',
        'Note'
      ];

      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2))
          ..value = TextCellValue(headers[c])
          ..cellStyle = tableHeaderStyle;
      }

      // Rows
      for (int r = 0; r < mTransactions.length; r++) {
        final tx = mTransactions[r];
        final rowNum = 3 + r;
        final cat = ExpenseCategory.findById(tx.categoryId);
        final accName = accountMap[tx.accountId] ?? 'Account';
        final toAccName = tx.toAccountId != null ? accountMap[tx.toAccountId] : null;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum)).value =
            TextCellValue(DateFormat('yyyy-MM-dd').format(tx.dateTime));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowNum)).value =
            TextCellValue(DateFormat('HH:mm').format(tx.dateTime));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowNum)).value =
            TextCellValue(tx.type.name.toUpperCase());
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowNum)).value =
            TextCellValue(tx.title);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowNum)).value =
            TextCellValue(cat.name);

        final amtCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowNum));
        amtCell.value = DoubleCellValue(tx.amount);
        if (tx.type == TransactionType.income) {
          amtCell.cellStyle = incomeValueStyle;
        } else if (tx.type == TransactionType.expense) {
          amtCell.cellStyle = expenseValueStyle;
        }

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowNum)).value =
            TextCellValue(tx.paymentMode.displayName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowNum)).value =
            TextCellValue(tx.type == TransactionType.transfer && toAccName != null
                ? '$accName → $toAccName'
                : accName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowNum)).value =
            TextCellValue(tx.note);
      }

      // Grouped Spends by Category for this month
      final Map<String, double> mCatSums = {};
      final Map<String, int> mCatCounts = {};
      for (final tx in mTransactions) {
        if (tx.type == TransactionType.expense) {
          mCatSums[tx.categoryId] = (mCatSums[tx.categoryId] ?? 0.0) + tx.amount;
          mCatCounts[tx.categoryId] = (mCatCounts[tx.categoryId] ?? 0) + 1;
        }
      }

      final catSummaryStartRow = 3 + mTransactions.length + 2;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: catSummaryStartRow))
        ..value = TextCellValue('SPENDS GROUPED BY CATEGORY')
        ..cellStyle = sectionHeaderStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: catSummaryStartRow))
        ..value = TextCellValue('COUNT')
        ..cellStyle = sectionHeaderStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: catSummaryStartRow))
        ..value = TextCellValue('TOTAL SPENT ($currency)')
        ..cellStyle = sectionHeaderStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: catSummaryStartRow))
        ..value = TextCellValue('% OF MONTH SPENDS')
        ..cellStyle = sectionHeaderStyle;

      final mSortedCats = mCatSums.keys.toList()
        ..sort((a, b) => (mCatSums[b] ?? 0).compareTo(mCatSums[a] ?? 0));

      int mCatRow = catSummaryStartRow + 1;
      for (final catId in mSortedCats) {
        final cat = ExpenseCategory.findById(catId);
        final sum = mCatSums[catId] ?? 0.0;
        final count = mCatCounts[catId] ?? 0;
        final pct = mExpense > 0 ? (sum / mExpense) * 100 : 0.0;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: mCatRow)).value =
            TextCellValue(cat.name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: mCatRow)).value =
            IntCellValue(count);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: mCatRow)).value =
            DoubleCellValue(sum);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: mCatRow)).value =
            TextCellValue('${pct.toStringAsFixed(1)}%');
        mCatRow++;
      }
    }

    // ---------------------------------------------------------
    // 3. ALL_TRANSACTIONS (MASTER DATABASE SHEET)
    // ---------------------------------------------------------
    final masterSheet = excel['All_Transactions'];
    final masterHeaders = [
      'ID',
      'DateTime',
      'Type',
      'Amount',
      'Title',
      'CategoryId',
      'AccountId',
      'ToAccountId',
      'PaymentMode',
      'Note'
    ];

    for (int c = 0; c < masterHeaders.length; c++) {
      masterSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        ..value = TextCellValue(masterHeaders[c])
        ..cellStyle = tableHeaderStyle;
    }

    for (int r = 0; r < transactions.length; r++) {
      final tx = transactions[r];
      final rowNum = 1 + r;
      masterSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum)).value =
          TextCellValue(tx.id);
      masterSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowNum)).value =
          TextCellValue(tx.dateTime.toIso8601String());
      masterSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowNum)).value =
          TextCellValue(tx.type.name);
      masterSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowNum)).value =
          DoubleCellValue(tx.amount);
      masterSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowNum)).value =
          TextCellValue(tx.title);
      masterSheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowNum)).value =
          TextCellValue(tx.categoryId);
      masterSheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowNum)).value =
          TextCellValue(tx.accountId);
      masterSheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowNum)).value =
          TextCellValue(tx.toAccountId ?? '');
      masterSheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowNum)).value =
          TextCellValue(tx.paymentMode.name);
      masterSheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowNum)).value =
          TextCellValue(tx.note);
    }

    // ---------------------------------------------------------
    // 4. ACCOUNTS SHEET
    // ---------------------------------------------------------
    final accSheet = excel['Accounts'];
    final accHeaders = ['ID', 'Name', 'Type', 'Balance', 'ColorValue'];
    for (int c = 0; c < accHeaders.length; c++) {
      accSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        ..value = TextCellValue(accHeaders[c])
        ..cellStyle = tableHeaderStyle;
    }

    for (int r = 0; r < accounts.length; r++) {
      final acc = accounts[r];
      final rowNum = 1 + r;
      accSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum)).value =
          TextCellValue(acc.id);
      accSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowNum)).value =
          TextCellValue(acc.name);
      accSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowNum)).value =
          TextCellValue(acc.type.name);
      accSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowNum)).value =
          DoubleCellValue(acc.balance);
      accSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowNum)).value =
          IntCellValue(acc.colorValue);
    }

    // Clean up empty default Sheet1 if exists and unused
    if (defaultSheetName == 'Sheet1' && excel.tables.containsKey('Sheet1')) {
      final s1 = excel['Sheet1'];
      if (s1.maxRows <= 0) {
        excel.delete('Sheet1');
      }
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }

  /// Export workbook, write to local file, and trigger native share sheet
  /// (e.g. Save to Google Drive, WhatsApp, Files, Gmail, etc.)
  static Future<ExcelExportResult> exportAndShare({
    required List<TransactionModel> transactions,
    required List<Account> accounts,
    required String currency,
  }) async {
    final bytes = generateWorkbook(
      transactions: transactions,
      accounts: accounts,
      currency: currency,
    );

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'ExpenseTracker_$timestamp.xlsx';
    final filePath = '${tempDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    // Calculate unique months
    final monthSet = transactions
        .map((t) => DateFormat('MMM yyyy').format(t.dateTime))
        .toSet();

    // Open native share sheet so user can save to Google Drive or share
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      text: 'Expense Tracker Excel Backup ($timestamp) with Dashboard & Monthly Sheets',
      subject: 'Expense Tracker Backup ($timestamp)',
    );

    return ExcelExportResult(
      filePath: filePath,
      transactionCount: transactions.length,
      monthCount: monthSet.length,
    );
  }

  /// Import & restore data from an existing Excel file (.xlsx)
  static Future<ExcelImportResult?> pickAndImportExcel() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result.isEmpty) {
      return null;
    }

    final picked = result.first;
    if (picked.path == null) {
      throw Exception('Selected file path could not be resolved.');
    }

    final file = File(picked.path!);
    final fileBytes = await file.readAsBytes();

    if (fileBytes.isEmpty) {
      throw Exception('Selected file is empty or could not be read.');
    }

    final excel = Excel.decodeBytes(fileBytes);
    final List<TransactionModel> parsedTransactions = [];
    final List<Account> parsedAccounts = [];

    // 1. Try reading All_Transactions master sheet
    if (excel.tables.containsKey('All_Transactions')) {
      final sheet = excel['All_Transactions'];
      for (int r = 1; r < sheet.maxRows; r++) {
        final row = sheet.row(r);
        if (row.isEmpty || row[0]?.value == null) continue;

        try {
          final id = row[0]?.value?.toString().trim() ?? '';
          if (id.isEmpty) continue;

          final dtStr = row[1]?.value?.toString().trim() ?? '';
          final typeStr = row[2]?.value?.toString().trim() ?? 'expense';
          final amount = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0.0;
          final title = row[4]?.value?.toString().trim() ?? 'Untitled';
          final categoryId = row[5]?.value?.toString().trim() ?? 'others';
          final accountId = row[6]?.value?.toString().trim() ?? '';
          final toAccountId = row[7]?.value?.toString().trim();
          final payModeStr = row[8]?.value?.toString().trim() ?? 'onlineUpi';
          final note = row[9]?.value?.toString().trim() ?? '';

          final dateTime = DateTime.tryParse(dtStr) ?? DateTime.now();

          final txType = TransactionType.values.firstWhere(
            (t) => t.name == typeStr,
            orElse: () => TransactionType.expense,
          );

          final payMode = PaymentMode.values.firstWhere(
            (m) => m.name == payModeStr,
            orElse: () => PaymentMode.onlineUpi,
          );

          parsedTransactions.add(
            TransactionModel(
              id: id,
              title: title,
              amount: amount,
              type: txType,
              categoryId: categoryId,
              accountId: accountId,
              toAccountId: (toAccountId != null && toAccountId.isNotEmpty) ? toAccountId : null,
              paymentMode: payMode,
              dateTime: dateTime,
              note: note,
            ),
          );
        } catch (_) {
          // Skip malformed row
        }
      }
    }

    // 2. Try reading Accounts sheet
    if (excel.tables.containsKey('Accounts')) {
      final sheet = excel['Accounts'];
      for (int r = 1; r < sheet.maxRows; r++) {
        final row = sheet.row(r);
        if (row.isEmpty || row[0]?.value == null) continue;

        try {
          final id = row[0]?.value?.toString().trim() ?? '';
          if (id.isEmpty) continue;

          final name = row[1]?.value?.toString().trim() ?? 'Account';
          final typeStr = row[2]?.value?.toString().trim() ?? 'bank';
          final balance = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0.0;
          final colorVal = int.tryParse(row[4]?.value?.toString() ?? '0xFF0D9488') ?? 0xFF0D9488;

          final accType = AccountType.values.firstWhere(
            (t) => t.name == typeStr,
            orElse: () => AccountType.bank,
          );

          parsedAccounts.add(
            Account(
              id: id,
              name: name,
              type: accType,
              balance: balance,
              colorValue: colorVal,
            ),
          );
        } catch (_) {
          // Skip malformed row
        }
      }
    }

    return ExcelImportResult(
      transactions: parsedTransactions,
      accounts: parsedAccounts,
      fileName: picked.name,
    );
  }
}
