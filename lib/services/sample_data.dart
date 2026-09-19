import '../models/account.dart';
import '../models/transaction.dart';

class SampleData {
  // Default clean accounts ready with 0 balance
  static final List<Account> initialAccounts = [
    const Account(
      id: 'acc_bank',
      name: 'Primary Bank Account',
      type: AccountType.bank,
      balance: 0.0,
      colorValue: 0xFF0284C7, // Blue
    ),
    const Account(
      id: 'acc_savings',
      name: 'Savings & Emergency Fund',
      type: AccountType.savings,
      balance: 0.0,
      colorValue: 0xFF0D9488, // Teal
    ),
    const Account(
      id: 'acc_cash',
      name: 'Cash in Hand',
      type: AccountType.cash,
      balance: 0.0,
      colorValue: 0xFFD97706, // Amber
    ),
  ];

  // Completely clean - no dummy transactions
  static List<TransactionModel> get initialTransactions {
    return [];
  }
}
