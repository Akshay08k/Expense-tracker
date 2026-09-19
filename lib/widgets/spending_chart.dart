import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';

class MonthlyCategoryChart extends StatefulWidget {
  final Map<ExpenseCategory, double> breakdown;
  final String currency;

  const MonthlyCategoryChart({
    super.key,
    required this.breakdown,
    required this.currency,
  });

  @override
  State<MonthlyCategoryChart> createState() => _MonthlyCategoryChartState();
}

class _MonthlyCategoryChartState extends State<MonthlyCategoryChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = widget.breakdown.values.fold(0.0, (sum, val) => sum + val);

    if (total == 0) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline_rounded, size: 44, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 8),
            Text(
              'No expenses recorded for this month',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final entries = widget.breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        // Donut Chart
        SizedBox(
          height: 190,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 3,
              centerSpaceRadius: 46,
              sections: List.generate(entries.length, (i) {
                final isTouched = i == _touchedIndex;
                final fontSize = isTouched ? 14.0 : 11.0;
                final radius = isTouched ? 48.0 : 40.0;
                final entry = entries[i];
                final percent = (entry.value / total) * 100;

                return PieChartSectionData(
                  color: entry.key.color,
                  value: entry.value,
                  title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Breakdown items list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const Divider(height: 12, thickness: 0.5),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final percent = (entry.value / total) * 100;
            final formatter = NumberFormat('#,##,##0', 'en_IN');

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: entry.key.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(entry.key.icon, size: 14, color: entry.key.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.key.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${widget.currency}${formatter.format(entry.value)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class YearlyBarChart extends StatelessWidget {
  final List<double> monthlyExpenses;
  final List<double> monthlyIncome;
  final String currency;

  const YearlyBarChart({
    super.key,
    required this.monthlyExpenses,
    required this.monthlyIncome,
    required this.currency,
  });

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxSpend = monthlyExpenses.fold(0.0, (max, val) => val > max ? val : max);
    final maxIncome = monthlyIncome.fold(0.0, (max, val) => val > max ? val : max);
    final overallMax = (maxSpend > maxIncome ? maxSpend : maxIncome);
    final maxY = overallMax > 0 ? overallMax * 1.2 : 1000.0;

    return Container(
      height: 230,
      padding: const EdgeInsets.only(top: 16, right: 8, left: 4),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final monthName = _months[group.x.toInt()];
                final type = rodIndex == 0 ? 'Expense' : 'Income';
                final val = NumberFormat('#,##,##0', 'en_IN').format(rod.toY);
                return BarTooltipItem(
                  '$monthName $type\n$currency$val',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < _months.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        _months[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 24,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 3,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.white10 : Colors.black12,
              strokeWidth: 0.8,
              dashArray: [5, 5],
            ),
          ),
          barGroups: List.generate(12, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: monthlyExpenses[i],
                  color: isDark ? const Color(0xFFFB7185) : AppColors.expense,
                  width: 7,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: monthlyIncome[i],
                  color: AppColors.income,
                  width: 7,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class PaymentModeComparisonWidget extends StatelessWidget {
  final Map<PaymentMode, double> paymentBreakdown;
  final String currency;

  const PaymentModeComparisonWidget({
    super.key,
    required this.paymentBreakdown,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = paymentBreakdown.values.fold(0.0, (sum, val) => sum + val);

    if (total == 0) return const SizedBox.shrink();

    final cashSpend = paymentBreakdown[PaymentMode.offlineCash] ?? 0.0;
    final onlineSpend = total - cashSpend;

    final cashPercent = (cashSpend / total) * 100;
    final onlinePercent = (onlineSpend / total) * 100;

    final formatter = NumberFormat('#,##,##0', 'en_IN');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
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
                'Spending Mode: Online vs Offline',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              Icon(Icons.compare_arrows_rounded, size: 18, color: isDark ? Colors.white54 : Colors.black54),
            ],
          ),
          const SizedBox(height: 12),

          // Stacked Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: onlinePercent.round().clamp(1, 100),
                    child: Container(color: AppColors.upi),
                  ),
                  Expanded(
                    flex: cashPercent.round().clamp(1, 100),
                    child: Container(color: AppColors.cash),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Details Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.upi, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Online (UPI / Card)', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                      Text('$currency${formatter.format(onlineSpend)} (${onlinePercent.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.cash, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Offline Cash', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                      Text('$currency${formatter.format(cashSpend)} (${cashPercent.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
