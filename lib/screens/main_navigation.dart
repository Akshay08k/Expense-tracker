import 'dart:async';
import 'package:flutter/material.dart';
import '../services/payment_detector_service.dart';
import '../theme/app_colors.dart';
import '../widgets/quick_add_sheet.dart';
import 'accounts_screen.dart';
import 'analytics_screen.dart';
import 'home_screen.dart';
import 'transactions_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription<DetectedPayment>? _paymentSubscription;
  bool _isPromptOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to real-time detected payments (while app is in foreground)
    _paymentSubscription =
        PaymentDetectorService.paymentStream.listen(_handleDetectedPayment);

    // Check if app was opened/launched via a payment notification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingPayment();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingPayment();
    }
  }

  Future<void> _checkPendingPayment() async {
    final pending = await PaymentDetectorService.getPendingPayment();
    if (pending != null && mounted) {
      _handleDetectedPayment(pending);
    }
  }

  void _handleDetectedPayment(DetectedPayment payment) {
    if (_isPromptOpen || !mounted) return;
    _isPromptOpen = true;

    final predictedCategory =
        PaymentDetectorService.predictCategoryId(payment.title);

    QuickAddSheet.show(
      context,
      prefilledAmount: payment.amount,
      prefilledTitle: payment.title,
      prefilledDate: payment.timestamp,
      prefilledCategoryId: predictedCategory,
      detectedSourceApp: payment.sourceApp,
    ).then((_) {
      if (mounted) {
        setState(() => _isPromptOpen = false);
      }
    });
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> screens = [
      HomeScreen(onNavigateTab: _onTabTapped),
      const TransactionsScreen(),
      const AnalyticsScreen(),
      const AccountsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => QuickAddSheet.show(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              _buildNavItem(1, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'History'),
              const SizedBox(width: 44), // space for central FAB
              _buildNavItem(2, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Analytics'),
              _buildNavItem(3, Icons.account_balance_rounded, Icons.account_balance_outlined, 'Accounts'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary);

    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
