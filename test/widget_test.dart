import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/services/storage_service.dart';
import 'package:expense_tracker/state/tracker_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expense Tracker Provider & Logic Tests', () {
    late StorageService storageService;
    late TrackerProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      await storageService.ensureInitialized();
      provider = TrackerProvider(storageService);
    });

    test('Initial seeded accounts load correctly', () {
      expect(provider.accounts.isNotEmpty, true);
      expect(provider.transactions.isEmpty, true);
    });

    test('Adding an expense deducts from the specified account balance', () async {
      final initialBank = provider.accounts.firstWhere((a) => a.id == 'acc_bank');
      final initialBalance = initialBank.balance;

      final expenseTx = TransactionModel(
        id: 'test_exp_1',
        title: 'Coffee and Donut',
        amount: 250.0,
        type: TransactionType.expense,
        categoryId: 'food',
        accountId: 'acc_bank',
        paymentMode: PaymentMode.onlineUpi,
        dateTime: DateTime.now(),
      );

      await provider.addTransaction(expenseTx);

      final updatedBank = provider.accounts.firstWhere((a) => a.id == 'acc_bank');
      expect(updatedBank.balance, equals(initialBalance - 250.0));
      expect(provider.transactions.first.id, equals('test_exp_1'));
    });

    test('Transferring to savings updates both source and destination accounts', () async {
      final bank = provider.accounts.firstWhere((a) => a.id == 'acc_bank');
      final savings = provider.accounts.firstWhere((a) => a.id == 'acc_savings');

      final initialBankBal = bank.balance;
      final initialSavingsBal = savings.balance;

      final transferTx = TransactionModel(
        id: 'test_tx_save',
        title: 'Save 5000',
        amount: 5000.0,
        type: TransactionType.transfer,
        categoryId: 'savings',
        accountId: 'acc_bank',
        toAccountId: 'acc_savings',
        paymentMode: PaymentMode.netBanking,
        dateTime: DateTime.now(),
      );

      await provider.addTransaction(transferTx);

      final updatedBank = provider.accounts.firstWhere((a) => a.id == 'acc_bank');
      final updatedSavings = provider.accounts.firstWhere((a) => a.id == 'acc_savings');

      expect(updatedBank.balance, equals(initialBankBal - 5000.0));
      expect(updatedSavings.balance, equals(initialSavingsBal + 5000.0));
    });

    test('Deleting a transaction restores original account balance', () async {
      final initialBank = provider.accounts.firstWhere((a) => a.id == 'acc_bank');
      final originalBalance = initialBank.balance;

      final expenseTx = TransactionModel(
        id: 'test_to_delete',
        title: 'Temporary Spend',
        amount: 1200.0,
        type: TransactionType.expense,
        categoryId: 'shopping',
        accountId: 'acc_bank',
        paymentMode: PaymentMode.creditCard,
        dateTime: DateTime.now(),
      );

      await provider.addTransaction(expenseTx);
      expect(provider.accounts.firstWhere((a) => a.id == 'acc_bank').balance, equals(originalBalance - 1200.0));

      await provider.deleteTransaction('test_to_delete');
      expect(provider.accounts.firstWhere((a) => a.id == 'acc_bank').balance, equals(originalBalance));
    });

    test('Editing an existing transaction updates details and adjusts balances correctly', () async {
      final initialBank = provider.accounts.firstWhere((a) => a.id == 'acc_bank');
      final originalBalance = initialBank.balance;

      final originalTx = TransactionModel(
        id: 'tx_edit_test',
        title: 'Original Lunch',
        amount: 200.0,
        type: TransactionType.expense,
        categoryId: 'food',
        accountId: 'acc_bank',
        paymentMode: PaymentMode.onlineUpi,
        dateTime: DateTime.now(),
      );

      await provider.addTransaction(originalTx);
      expect(provider.accounts.firstWhere((a) => a.id == 'acc_bank').balance, equals(originalBalance - 200.0));

      // Now edit the transaction: change title to "Dinner with Team" and amount to 500
      final updatedTx = originalTx.copyWith(
        title: 'Dinner with Team',
        amount: 500.0,
      );

      await provider.updateTransaction(updatedTx);

      expect(provider.transactions.first.title, equals('Dinner with Team'));
      expect(provider.transactions.first.amount, equals(500.0));
      // Balance should be originalBalance - 500.0 (reverted 200, applied 500)
      expect(provider.accounts.firstWhere((a) => a.id == 'acc_bank').balance, equals(originalBalance - 500.0));
    });

    test('Bulk data restoration properly sets transactions and accounts', () async {
      final newTx = TransactionModel(
        id: 'restored_1',
        title: 'Restored Item',
        amount: 350.0,
        type: TransactionType.expense,
        categoryId: 'shopping',
        accountId: 'acc_bank',
        paymentMode: PaymentMode.creditCard,
        dateTime: DateTime.now(),
      );

      await provider.restoreData(transactions: [newTx]);
      expect(provider.transactions.length, equals(1));
      expect(provider.transactions.first.id, equals('restored_1'));
    });
  });
}
