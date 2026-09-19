import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../state/tracker_provider.dart';
import '../theme/app_colors.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(dt.year, dt.month, dt.day);

    final timeStr = DateFormat('h:mm a').format(dt);

    if (txDate == today) {
      return 'Today, $timeStr';
    } else if (txDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $timeStr';
    } else {
      return '${DateFormat('dd MMM').format(dt)}, $timeStr';
    }
  }

  Color _getPaymentModeColor(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.offlineCash:
        return AppColors.cash;
      case PaymentMode.onlineUpi:
        return AppColors.upi;
      case PaymentMode.creditCard:
      case PaymentMode.debitCard:
        return AppColors.card;
      case PaymentMode.netBanking:
        return const Color(0xFF0284C7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrackerProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = provider.currency;
    final account = provider.getAccountById(transaction.accountId);
    final toAccount = transaction.toAccountId != null
        ? provider.getAccountById(transaction.toAccountId!)
        : null;

    final category = ExpenseCategory.findById(transaction.categoryId);

    // Styling based on transaction type
    Color amountColor;
    String prefix;
    if (transaction.type == TransactionType.income) {
      amountColor = AppColors.income;
      prefix = '+';
    } else if (transaction.type == TransactionType.transfer) {
      amountColor = AppColors.transfer;
      prefix = '⇄ ';
    } else {
      amountColor = isDark ? const Color(0xFFFB7185) : AppColors.expense;
      prefix = '-';
    }

    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    final formattedAmount = '$prefix$currency${formatter.format(transaction.amount)}';

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Transaction?'),
            content: Text('Are you sure you want to delete "${transaction.title}"? The account balance will be restored.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        provider.deleteTransaction(transaction.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${transaction.title}"'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              // Icon with category background tint
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  transaction.type == TransactionType.transfer
                      ? Icons.swap_horiz_rounded
                      : category.icon,
                  color: category.color,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              // Title, Account, Payment Badge & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Payment mode badge (e.g. Offline Cash vs Online UPI)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPaymentModeColor(transaction.paymentMode).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                transaction.paymentMode.icon,
                                size: 10,
                                color: _getPaymentModeColor(transaction.paymentMode),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                transaction.paymentMode.shortName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getPaymentModeColor(transaction.paymentMode),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 6),

                        // Account name or Transfer destination
                        Flexible(
                          child: Text(
                            transaction.type == TransactionType.transfer
                                ? '${account?.name ?? 'Acc'} → ${toAccount?.name ?? 'Savings'}'
                                : (account?.name ?? 'Account'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Amount & Date/Time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formattedAmount,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(transaction.dateTime),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
