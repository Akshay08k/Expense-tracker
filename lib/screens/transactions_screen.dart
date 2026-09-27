import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../state/tracker_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/quick_add_sheet.dart';
import '../widgets/transaction_tile.dart';
import 'spreadsheet_sync_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  TransactionType? _filterType; // null = all
  PaymentMode? _filterPaymentMode; // null = all
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrackerProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTransactions = provider.transactions;

    // Apply Filters
    final filtered = allTransactions.where((tx) {
      if (_filterType != null && tx.type != _filterType) return false;
      if (_filterPaymentMode != null && tx.paymentMode != _filterPaymentMode) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = tx.title.toLowerCase().contains(q);
        final matchesNote = tx.note.toLowerCase().contains(q);
        final matchesCat = tx.categoryId.toLowerCase().contains(q);
        if (!matchesTitle && !matchesNote && !matchesCat) return false;
      }
      return true;
    }).toList();

    // Calculate totals of filtered list
    double filteredExpense = 0.0;
    double filteredIncome = 0.0;
    for (final tx in filtered) {
      if (tx.type == TransactionType.expense) filteredExpense += tx.amount;
      if (tx.type == TransactionType.income) filteredIncome += tx.amount;
    }

    final formatter = NumberFormat('#,##,##0.00', 'en_IN');

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_rounded, color: AppColors.primary),
            tooltip: 'Spreadsheet & Cloud DB',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SpreadsheetSyncScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Transaction',
            onPressed: () => QuickAddSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by title, note, or category...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),

                const SizedBox(height: 10),

                // Transaction Type Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', _filterType == null, () => setState(() => _filterType = null)),
                      const SizedBox(width: 6),
                      _buildFilterChip('Expenses', _filterType == TransactionType.expense, () => setState(() => _filterType = TransactionType.expense)),
                      const SizedBox(width: 6),
                      _buildFilterChip('Income', _filterType == TransactionType.income, () => setState(() => _filterType = TransactionType.income)),
                      const SizedBox(width: 6),
                      _buildFilterChip('Transfers', _filterType == TransactionType.transfer, () => setState(() => _filterType = TransactionType.transfer)),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Payment Mode Filter Chips (Cash vs Online UPI vs Cards)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPaymentChip('All Modes', _filterPaymentMode == null, () => setState(() => _filterPaymentMode = null)),
                      const SizedBox(width: 6),
                      _buildPaymentChip('💵 Offline Cash', _filterPaymentMode == PaymentMode.offlineCash, () => setState(() => _filterPaymentMode = PaymentMode.offlineCash)),
                      const SizedBox(width: 6),
                      _buildPaymentChip('📱 Online UPI', _filterPaymentMode == PaymentMode.onlineUpi, () => setState(() => _filterPaymentMode = PaymentMode.onlineUpi)),
                      const SizedBox(width: 6),
                      _buildPaymentChip('💳 Cards', _filterPaymentMode == PaymentMode.creditCard, () => setState(() => _filterPaymentMode = PaymentMode.creditCard)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Total Bar for filtered results
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} entries found',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                Row(
                  children: [
                    if (filteredExpense > 0)
                      Text(
                        '-${provider.currency}${formatter.format(filteredExpense)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.expense,
                        ),
                      ),
                    if (filteredExpense > 0 && filteredIncome > 0) const Text('  •  ', style: TextStyle(color: Colors.grey)),
                    if (filteredIncome > 0)
                      Text(
                        '+${provider.currency}${formatter.format(filteredIncome)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.income,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Filtered Transactions List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_alt_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 12),
                        Text(
                          'No matching transactions found',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try clearing search or filter chips',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return TransactionTile(
                        transaction: filtered[index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? AppColors.darkCard : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentChip(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.transparent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
    );
  }
}
