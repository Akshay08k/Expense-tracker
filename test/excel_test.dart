import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/services/excel_service.dart';

void main() {
  test('ExcelService generates Dashboard, Monthly Sheets, All_Transactions, and Accounts', () {
    final accounts = [
      const Account(
        id: 'acc_bank',
        name: 'HDFC Bank',
        type: AccountType.bank,
        balance: 25000.0,
        colorValue: 0xFF0D9488,
      ),
      const Account(
        id: 'acc_cash',
        name: 'Cash Wallet',
        type: AccountType.cash,
        balance: 3000.0,
        colorValue: 0xFFF59E0B,
      ),
    ];

    final transactions = [
      TransactionModel(
        id: 'tx_1',
        title: 'Grocery Supermarket',
        amount: 1450.0,
        type: TransactionType.expense,
        categoryId: 'groceries',
        accountId: 'acc_bank',
        paymentMode: PaymentMode.onlineUpi,
        dateTime: DateTime(2026, 9, 15, 14, 30),
        note: 'Weekly essentials',
      ),
      TransactionModel(
        id: 'tx_2',
        title: 'Salary Credit',
        amount: 85000.0,
        type: TransactionType.income,
        categoryId: 'salary',
        accountId: 'acc_bank',
        paymentMode: PaymentMode.netBanking,
        dateTime: DateTime(2026, 9, 1, 10, 0),
        note: 'September salary',
      ),
      TransactionModel(
        id: 'tx_3',
        title: 'Dinner at Restaurant',
        amount: 980.0,
        type: TransactionType.expense,
        categoryId: 'food',
        accountId: 'acc_cash',
        paymentMode: PaymentMode.offlineCash,
        dateTime: DateTime(2026, 8, 20, 21, 15),
        note: 'Family dinner',
      ),
    ];

    final bytes = ExcelService.generateWorkbook(
      transactions: transactions,
      accounts: accounts,
      currency: '₹',
    );

    expect(bytes, isNotEmpty);

    final readExcel = Excel.decodeBytes(bytes);
    expect(readExcel.tables.containsKey('📊 Dashboard'), isTrue);
    expect(readExcel.tables.containsKey('Sep 2026'), isTrue);
    expect(readExcel.tables.containsKey('Aug 2026'), isTrue);
    expect(readExcel.tables.containsKey('All_Transactions'), isTrue);
    expect(readExcel.tables.containsKey('Accounts'), isTrue);

    // Verify Dashboard contains financial metrics
    final dash = readExcel['📊 Dashboard'];
    expect(dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value.toString(), contains('EXPENSE TRACKER FINANCIAL DASHBOARD'));

    // Verify Month sheet contains transaction
    final sepSheet = readExcel['Sep 2026'];
    expect(sepSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 3)).value.toString(), contains('Grocery Supermarket'));
  });
}
