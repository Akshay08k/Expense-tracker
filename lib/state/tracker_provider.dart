import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/storage_service.dart';

class TrackerProvider extends ChangeNotifier {
  final StorageService _storage;

  List<TransactionModel> _transactions = [];
  List<Account> _accounts = [];
  String _currency = '₹';
  ThemeMode _themeMode = ThemeMode.system;

  TrackerProvider(this._storage) {
    _loadFromStorage();
  }

  // Getters
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<Account> get accounts => List.unmodifiable(_accounts);
  String get currency => _currency;
  ThemeMode get themeMode => _themeMode;

  void _loadFromStorage() {
    _transactions = _storage.loadTransactions();
    _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    _accounts = _storage.loadAccounts();
    _currency = _storage.loadCurrency();

    final themeStr = _storage.loadThemeMode();
    if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Account? getAccountById(String id) {
    try {
      return _accounts.firstWhere((acc) => acc.id == id);
    } catch (_) {
      return null;
    }
  }

  // Net Worth & Balance Helpers
  double get totalBalance {
    return _accounts.fold(0.0, (sum, acc) => sum + acc.balance);
  }

  double get savingsBalance {
    return _accounts
        .where((acc) => acc.type == AccountType.savings)
        .fold(0.0, (sum, acc) => sum + acc.balance);
  }

  double get bankBalance {
    return _accounts
        .where((acc) => acc.type == AccountType.bank)
        .fold(0.0, (sum, acc) => sum + acc.balance);
  }

  double get cashBalance {
    return _accounts
        .where((acc) => acc.type == AccountType.cash)
        .fold(0.0, (sum, acc) => sum + acc.balance);
  }

  List<TransactionModel> getRecentTransactions({int limit = 6}) {
    return _transactions.take(limit).toList();
  }

  // --- Transactions Operations ---
  Future<void> addTransaction(TransactionModel tx) async {
    _transactions.insert(0, tx);
    _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // Update account balances
    _applyBalanceChange(tx, isReverse: false);

    await _storage.saveTransactions(_transactions);
    await _storage.saveAccounts(_accounts);
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    final index = _transactions.indexWhere((tx) => tx.id == id);
    if (index == -1) return;

    final tx = _transactions[index];
    // Reverse the balance impact
    _applyBalanceChange(tx, isReverse: true);

    _transactions.removeAt(index);

    await _storage.saveTransactions(_transactions);
    await _storage.saveAccounts(_accounts);
    notifyListeners();
  }

  Future<void> updateTransaction(TransactionModel updatedTx) async {
    final index = _transactions.indexWhere((tx) => tx.id == updatedTx.id);
    if (index == -1) return;

    final oldTx = _transactions[index];
    // Revert old effect
    _applyBalanceChange(oldTx, isReverse: true);
    // Apply new effect
    _applyBalanceChange(updatedTx, isReverse: false);

    _transactions[index] = updatedTx;
    _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    await _storage.saveTransactions(_transactions);
    await _storage.saveAccounts(_accounts);
    notifyListeners();
  }

  void _applyBalanceChange(TransactionModel tx, {required bool isReverse}) {
    final multiplier = isReverse ? -1.0 : 1.0;

    if (tx.type == TransactionType.expense) {
      _modifyAccountBalance(tx.accountId, -tx.amount * multiplier);
    } else if (tx.type == TransactionType.income) {
      _modifyAccountBalance(tx.accountId, tx.amount * multiplier);
    } else if (tx.type == TransactionType.transfer) {
      _modifyAccountBalance(tx.accountId, -tx.amount * multiplier);
      if (tx.toAccountId != null) {
        _modifyAccountBalance(tx.toAccountId!, tx.amount * multiplier);
      }
    }
  }

  void _modifyAccountBalance(String accountId, double delta) {
    final index = _accounts.indexWhere((acc) => acc.id == accountId);
    if (index != -1) {
      final acc = _accounts[index];
      _accounts[index] = acc.copyWith(balance: acc.balance + delta);
    }
  }

  // --- Account Operations ---
  Future<void> addAccount(Account account) async {
    _accounts.add(account);
    await _storage.saveAccounts(_accounts);
    notifyListeners();
  }

  Future<void> updateAccount(Account updatedAccount) async {
    final index = _accounts.indexWhere((acc) => acc.id == updatedAccount.id);
    if (index != -1) {
      _accounts[index] = updatedAccount;
      await _storage.saveAccounts(_accounts);
      notifyListeners();
    }
  }

  Future<void> deleteAccount(String accountId) async {
    _accounts.removeWhere((acc) => acc.id == accountId);
    await _storage.saveAccounts(_accounts);
    notifyListeners();
  }

  // --- Settings & Preferences ---
  Future<void> setCurrency(String newCurrency) async {
    _currency = newCurrency;
    await _storage.saveCurrency(newCurrency);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final modeStr = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await _storage.saveThemeMode(modeStr);
    notifyListeners();
  }

  // --- Monthly & Yearly Analytics Helpers ---
  List<TransactionModel> getTransactionsForMonth(int year, int month) {
    return _transactions.where((tx) {
      return tx.dateTime.year == year && tx.dateTime.month == month;
    }).toList();
  }

  double getMonthlyExpense(int year, int month) {
    return getTransactionsForMonth(year, month)
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double getMonthlyIncome(int year, int month) {
    return getTransactionsForMonth(year, month)
        .where((tx) => tx.type == TransactionType.income)
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double getMonthlySavingsTransfers(int year, int month) {
    return getTransactionsForMonth(year, month).where((tx) {
      if (tx.type != TransactionType.transfer) return false;
      final toAcc = getAccountById(tx.toAccountId ?? '');
      return toAcc?.type == AccountType.savings;
    }).fold(0.0, (sum, tx) => sum + tx.amount);
  }

  Map<ExpenseCategory, double> getCategoryBreakdown(int year, int month) {
    final monthTxs = getTransactionsForMonth(year, month)
        .where((tx) => tx.type == TransactionType.expense);
    final Map<ExpenseCategory, double> breakdown = {};

    for (final tx in monthTxs) {
      final category = ExpenseCategory.findById(tx.categoryId);
      breakdown[category] = (breakdown[category] ?? 0.0) + tx.amount;
    }
    return breakdown;
  }

  Map<PaymentMode, double> getPaymentModeBreakdown(int year, int month) {
    final monthTxs = getTransactionsForMonth(year, month)
        .where((tx) => tx.type == TransactionType.expense);
    final Map<PaymentMode, double> breakdown = {};

    for (final tx in monthTxs) {
      breakdown[tx.paymentMode] = (breakdown[tx.paymentMode] ?? 0.0) + tx.amount;
    }
    return breakdown;
  }

  // 12 months array for yearly summary [Jan..Dec]
  List<double> getYearlyExpenses(int year) {
    final List<double> monthlyTotals = List.filled(12, 0.0);
    for (final tx in _transactions) {
      if (tx.dateTime.year == year && tx.type == TransactionType.expense) {
        final monthIdx = tx.dateTime.month - 1;
        monthlyTotals[monthIdx] += tx.amount;
      }
    }
    return monthlyTotals;
  }

  List<double> getYearlyIncome(int year) {
    final List<double> monthlyTotals = List.filled(12, 0.0);
    for (final tx in _transactions) {
      if (tx.dateTime.year == year && tx.type == TransactionType.income) {
        final monthIdx = tx.dateTime.month - 1;
        monthlyTotals[monthIdx] += tx.amount;
      }
    }
    return monthlyTotals;
  }

  double getYearlyTotalExpense(int year) {
    return getYearlyExpenses(year).fold(0.0, (sum, val) => sum + val);
  }

  double getYearlyTotalIncome(int year) {
    return getYearlyIncome(year).fold(0.0, (sum, val) => sum + val);
  }
}
