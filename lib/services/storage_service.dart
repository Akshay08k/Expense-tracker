import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import 'sample_data.dart';

class StorageService {
  static const String _keyTransactions = 'exp_tracker_transactions';
  static const String _keyAccounts = 'exp_tracker_accounts';
  static const String _keyCurrency = 'exp_tracker_currency';
  static const String _keyThemeMode = 'exp_tracker_theme_mode';
  static const String _keyFirstRun = 'exp_tracker_first_run_done';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  SharedPreferences get prefsInstance => _prefs;

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Initial check & seed if brand new
  Future<void> ensureInitialized() async {
    final isFirstRunDone = _prefs.getBool(_keyFirstRun) ?? false;
    if (!isFirstRunDone) {
      await saveAccounts(SampleData.initialAccounts);
      await saveTransactions(SampleData.initialTransactions);
      await saveCurrency('₹');
      await _prefs.setBool(_keyFirstRun, true);
    }
  }

  // Transactions
  List<TransactionModel> loadTransactions() {
    final jsonString = _prefs.getString(_keyTransactions);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((item) => TransactionModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveTransactions(List<TransactionModel> transactions) async {
    final encoded = jsonEncode(transactions.map((t) => t.toJson()).toList());
    return await _prefs.setString(_keyTransactions, encoded);
  }

  // Accounts
  List<Account> loadAccounts() {
    final jsonString = _prefs.getString(_keyAccounts);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((item) => Account.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveAccounts(List<Account> accounts) async {
    final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
    return await _prefs.setString(_keyAccounts, encoded);
  }

  // Currency
  String loadCurrency() {
    return _prefs.getString(_keyCurrency) ?? '₹';
  }

  Future<bool> saveCurrency(String currency) async {
    return await _prefs.setString(_keyCurrency, currency);
  }

  // Theme mode ('system', 'light', 'dark')
  String loadThemeMode() {
    return _prefs.getString(_keyThemeMode) ?? 'system';
  }

  Future<bool> saveThemeMode(String mode) async {
    return await _prefs.setString(_keyThemeMode, mode);
  }

  // Google Sheets Sync Configuration
  static const String _keyGoogleSheetsUrl = 'exp_tracker_google_sheets_url';
  static const String _keyLastSheetsSync = 'exp_tracker_google_sheets_last_sync';

  String? loadGoogleSheetsUrl() {
    return _prefs.getString(_keyGoogleSheetsUrl);
  }

  Future<bool> saveGoogleSheetsUrl(String url) async {
    return await _prefs.setString(_keyGoogleSheetsUrl, url.trim());
  }

  Future<bool> clearGoogleSheetsUrl() async {
    await _prefs.remove(_keyLastSheetsSync);
    return await _prefs.remove(_keyGoogleSheetsUrl);
  }

  String? loadLastSheetsSync() {
    return _prefs.getString(_keyLastSheetsSync);
  }

  Future<bool> saveLastSheetsSync(String timestamp) async {
    return await _prefs.setString(_keyLastSheetsSync, timestamp);
  }

  // Reset / Clear Data
  Future<void> clearAll() async {
    await _prefs.remove(_keyTransactions);
    await _prefs.remove(_keyAccounts);
    await _prefs.remove(_keyFirstRun);
    await _prefs.remove(_keyGoogleSheetsUrl);
    await _prefs.remove(_keyLastSheetsSync);
  }
}
