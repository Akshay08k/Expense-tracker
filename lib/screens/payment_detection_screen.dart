import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/payment_detector_service.dart';
import '../theme/app_colors.dart';
import '../widgets/quick_add_sheet.dart';

class PaymentDetectionScreen extends StatefulWidget {
  const PaymentDetectionScreen({super.key});

  @override
  State<PaymentDetectionScreen> createState() => _PaymentDetectionScreenState();
}

class _PaymentDetectionScreenState extends State<PaymentDetectionScreen>
    with WidgetsBindingObserver {
  bool _isPermissionGranted = false;
  bool _isPostNotificationGranted = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    setState(() => _isLoading = true);
    final granted = await PaymentDetectorService.isPermissionGranted();
    final postGranted =
        await PaymentDetectorService.isPostNotificationPermissionGranted();
    if (mounted) {
      setState(() {
        _isPermissionGranted = granted;
        _isPostNotificationGranted = postGranted;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment Auto-Detection',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Status Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isPermissionGranted
                    ? [const Color(0xFF0D9488), const Color(0xFF047857)]
                    : [const Color(0xFF475569), const Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (_isPermissionGranted
                          ? const Color(0xFF0D9488)
                          : const Color(0xFF334155))
                      .withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPermissionGranted
                            ? Icons.verified_rounded
                            : Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _isPermissionGranted
                            ? const Color(0xFF047857)
                            : Colors.amber.shade800,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isLoading
                            ? 'Checking...'
                            : (_isPermissionGranted ? 'ACTIVE' : 'PERMISSION NEEDED'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  _isPermissionGranted
                      ? 'Listening for UPI & Card Spends'
                      : 'Enable Notification Access',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isPermissionGranted
                      ? 'As soon as you pay via Google Pay, PhonePe, or Paytm, FinFlow pops up a prefilled prompt to record your expense.'
                      : 'FinFlow needs Android Notification Access to detect transaction alerts from your payment apps in real-time.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                if (!_isPermissionGranted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        await PaymentDetectorService.openPermissionSettings();
                      },
                      icon: const Icon(Icons.settings_rounded, size: 20),
                      label: const Text(
                        'Grant Access in Android Settings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (!_isPostNotificationGranted) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.amber.shade700.withOpacity(0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notification_important_rounded,
                          color: Colors.amber.shade400, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'App Notifications Needed',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'To show the [⚡ Quick Save] popup banner when payments occur, FinFlow needs permission to post notifications on Android 13+.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade300,
                        side: BorderSide(color: Colors.amber.shade700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await PaymentDetectorService
                            .requestPostNotificationPermission();
                        await _checkPermission();
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Allow Notifications'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Privacy & Battery Assurance
          Text(
            'PRIVACY & EFFICIENCY',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.battery_charging_full_rounded,
            color: const Color(0xFF10B981),
            title: 'Zero Battery Drain',
            subtitle:
                'Event-driven Android OS callback. No polling loop, no background wake-locks.',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.shield_rounded,
            color: const Color(0xFF0284C7),
            title: '100% Private (No SMS Reading)',
            subtitle:
                'Never reads your SMS inbox, OTPs, or chats. Processes transaction alerts locally.',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.edit_note_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'Pre-filled, User Confirmed',
            subtitle:
                'Detects Amount, Payee & Time. You simply verify the category and tap Save.',
            isDark: isDark,
          ),

          const SizedBox(height: 24),

          // Supported Payment Apps
          Text(
            'SUPPORTED PAYMENT APPS',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAppChip('Google Pay', Icons.payments_rounded, isDark),
              _buildAppChip('PhonePe', Icons.account_balance_wallet_rounded, isDark),
              _buildAppChip('Paytm', Icons.qr_code_scanner_rounded, isDark),
              _buildAppChip('BHIM UPI', Icons.flash_on_rounded, isDark),
              _buildAppChip('CRED', Icons.credit_card_rounded, isDark),
              _buildAppChip('Amazon Pay', Icons.shopping_cart_rounded, isDark),
              _buildAppChip('HDFC / ICICI / SBI / Axis', Icons.account_balance_rounded, isDark),
            ],
          ),

          const SizedBox(height: 28),

          // Test Payment Simulation Section
          Text(
            'TEST DETECTION SIMULATOR',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Test how FinFlow automatically catches transactions without spending money.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),

          _buildTestButton(
            title: 'Simulate GPay Payment',
            subtitle: 'Paid ₹150 to Starbucks Coffee',
            amount: 150.0,
            payee: 'Starbucks Coffee',
            sourceApp: 'Google Pay',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildTestButton(
            title: 'Simulate PhonePe Payment',
            subtitle: 'Paid ₹45 to Chai Point',
            amount: 45.0,
            payee: 'Chai Point',
            sourceApp: 'PhonePe',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildTestButton(
            title: 'Simulate Swiggy Order',
            subtitle: 'Paid ₹380 to Swiggy via UPI',
            amount: 380.0,
            payee: 'Swiggy',
            sourceApp: 'Google Pay',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildTestButton(
            title: 'Simulate Bank of Baroda UPI',
            subtitle: 'Rs.10.00 Dr. to komaleakshay7@oksbi',
            amount: 10.0,
            payee: 'komaleakshay7 (SBI)',
            sourceApp: 'Bank of Baroda / Truecaller',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildTestButton(
            title: 'Simulate Income Received',
            subtitle: 'Received ₹2,500 from Amit Patel',
            amount: 2500.0,
            payee: 'Amit Patel',
            sourceApp: 'Google Pay',
            isIncome: true,
            isDark: isDark,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppChip(String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton({
    required String title,
    required String subtitle,
    required double amount,
    required String payee,
    required String sourceApp,
    bool isIncome = false,
    required bool isDark,
  }) {
    final themeColor = isIncome ? AppColors.income : AppColors.primary;
    return InkWell(
      onTap: () {
        PaymentDetectorService.simulateTestPayment(
          amount: amount,
          payee: payee,
          sourceApp: sourceApp,
          isIncome: isIncome,
        );
        // Also open directly if desired
        QuickAddSheet.show(
          context,
          initialType:
              isIncome ? TransactionType.income : TransactionType.expense,
          prefilledAmount: amount,
          prefilledTitle: payee,
          prefilledDate: DateTime.now(),
          prefilledCategoryId: isIncome
              ? 'salary'
              : PaymentDetectorService.predictCategoryId(payee),
          detectedSourceApp: sourceApp,
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: themeColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bolt_rounded, color: themeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: themeColor),
          ],
        ),
      ),
    );
  }
}
