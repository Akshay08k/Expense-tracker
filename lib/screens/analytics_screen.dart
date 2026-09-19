import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/tracker_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/spending_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _selectedYear = now.year;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Summaries', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: isDark ? Colors.white : AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          tabs: const [
            Tab(text: 'Monthly Summary'),
            Tab(text: 'Yearly Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMonthlyTab(),
          _buildYearlyTab(),
        ],
      ),
    );
  }

  Widget _buildMonthlyTab() {
    final provider = context.watch<TrackerProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = provider.currency;

    final expense = provider.getMonthlyExpense(_selectedMonth.year, _selectedMonth.month);
    final income = provider.getMonthlyIncome(_selectedMonth.year, _selectedMonth.month);
    final netSaved = income - expense;
    final savingsRate = income > 0 ? ((netSaved / income) * 100).clamp(-100.0, 100.0) : 0.0;

    final categoryBreakdown = provider.getCategoryBreakdown(_selectedMonth.year, _selectedMonth.month);
    final paymentBreakdown = provider.getPaymentModeBreakdown(_selectedMonth.year, _selectedMonth.month);

    final formatter = NumberFormat('#,##,##0', 'en_IN');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Selector Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _previousMonth,
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _nextMonth,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 4 Summary Metric Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Spent',
                  '$currency${formatter.format(expense)}',
                  Icons.trending_down_rounded,
                  AppColors.expense,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Total Income',
                  '$currency${formatter.format(income)}',
                  Icons.trending_up_rounded,
                  AppColors.income,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Net Saved',
                  '$currency${formatter.format(netSaved)}',
                  Icons.savings_rounded,
                  netSaved >= 0 ? AppColors.savings : AppColors.expense,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Savings Rate',
                  '${savingsRate.toStringAsFixed(1)}%',
                  Icons.pie_chart_rounded,
                  AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Online vs Offline Spend Distribution
          PaymentModeComparisonWidget(
            paymentBreakdown: paymentBreakdown,
            currency: currency,
          ),

          const SizedBox(height: 24),

          // Category Donut Chart
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Spending by Category',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                MonthlyCategoryChart(
                  breakdown: categoryBreakdown,
                  currency: currency,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyTab() {
    final provider = context.watch<TrackerProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = provider.currency;

    final yearlyExpenses = provider.getYearlyExpenses(_selectedYear);
    final yearlyIncome = provider.getYearlyIncome(_selectedYear);
    final totalExpense = provider.getYearlyTotalExpense(_selectedYear);
    final totalIncome = provider.getYearlyTotalIncome(_selectedYear);
    final yearlyNetSaved = totalIncome - totalExpense;
    final avgMonthlySpend = totalExpense / 12;

    // Find highest spending month
    int highestMonthIdx = 0;
    double highestMonthAmount = 0.0;
    for (int i = 0; i < 12; i++) {
      if (yearlyExpenses[i] > highestMonthAmount) {
        highestMonthAmount = yearlyExpenses[i];
        highestMonthIdx = i;
      }
    }
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final highestMonthName = months[highestMonthIdx];

    final formatter = NumberFormat('#,##,##0', 'en_IN');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() => _selectedYear--),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Text(
                  'Year $_selectedYear',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => setState(() => _selectedYear++),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 12-Month Bar Chart Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '12-Month Expense vs Income',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Row(
                      children: [
                        _buildLegendDot(AppColors.expense, 'Spend'),
                        const SizedBox(width: 8),
                        _buildLegendDot(AppColors.income, 'Income'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                YearlyBarChart(
                  monthlyExpenses: yearlyExpenses,
                  monthlyIncome: yearlyIncome,
                  currency: currency,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // High-Spending Month Insight Banner
          if (highestMonthAmount > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.expense.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.expense.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.expense, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Highest spending month in $_selectedYear was $highestMonthName ($currency${formatter.format(highestMonthAmount)}).',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Yearly Total Metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Spent ($_selectedYear)',
                  '$currency${formatter.format(totalExpense)}',
                  Icons.money_off_rounded,
                  AppColors.expense,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Total Income ($_selectedYear)',
                  '$currency${formatter.format(totalIncome)}',
                  Icons.account_balance_rounded,
                  AppColors.income,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Net Accumulated Savings',
                  '$currency${formatter.format(yearlyNetSaved)}',
                  Icons.savings_rounded,
                  yearlyNetSaved >= 0 ? AppColors.savings : AppColors.expense,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Monthly Average Spend',
                  '$currency${formatter.format(avgMonthlySpend)}',
                  Icons.calendar_view_month_rounded,
                  AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
