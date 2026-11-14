import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents a payment detected from an incoming notification
class DetectedPayment {
  final double amount;
  final String title;
  final String sourceApp;
  final DateTime timestamp;
  final String? rawText;

  DetectedPayment({
    required this.amount,
    required this.title,
    required this.sourceApp,
    required this.timestamp,
    this.rawText,
  });

  factory DetectedPayment.fromMap(Map<dynamic, dynamic> map) {
    final amt = map['amount'];
    final double amount = (amt is num)
        ? amt.toDouble()
        : (double.tryParse(amt?.toString() ?? '') ?? 0.0);

    final ts = map['timestamp'];
    final DateTime timestamp = (ts is num)
        ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
        : DateTime.now();

    return DetectedPayment(
      amount: amount,
      title: (map['title'] as String?)?.trim() ?? 'Payment',
      sourceApp: (map['sourceApp'] as String?)?.trim() ?? 'UPI',
      timestamp: timestamp,
      rawText: map['rawText'] as String?,
    );
  }
}

/// Service to interact with native Android PaymentNotificationListenerService
class PaymentDetectorService {
  static const MethodChannel _channel =
      MethodChannel('com.finflow/payment_detector');

  static final StreamController<DetectedPayment> _controller =
      StreamController<DetectedPayment>.broadcast();

  static Stream<DetectedPayment> get paymentStream => _controller.stream;

  static bool _isInitialized = false;

  /// Initialize listener channel
  static void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPaymentDetected') {
        if (call.arguments is Map) {
          final payment = DetectedPayment.fromMap(call.arguments as Map);
          _controller.add(payment);
        }
      }
    });
  }

  /// Check whether Android Notification Access is granted to FinFlow
  static Future<bool> isPermissionGranted() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isNotificationPermissionGranted');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
      return false;
    }
  }

  /// Open Android "Notification Access" system settings page
  static Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('Error opening notification settings: $e');
    }
  }

  /// Check if the app was opened/launched by clicking a payment notification
  static Future<DetectedPayment?> getPendingPayment() async {
    try {
      final result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getPendingPayment');
      if (result != null) {
        return DetectedPayment.fromMap(result);
      }
    } catch (e) {
      debugPrint('Error getting pending payment: $e');
    }
    return null;
  }

  /// Simulate a test payment notification for testing without spending money
  static Future<void> simulateTestPayment({
    double amount = 150.0,
    String payee = 'Starbucks Coffee',
    String sourceApp = 'Google Pay',
  }) async {
    try {
      await _channel.invokeMethod('simulatePaymentNotification', {
        'amount': amount,
        'payee': payee,
        'sourceApp': sourceApp,
      });
    } catch (e) {
      debugPrint('Error simulating payment: $e');
    }
  }

  /// Intelligent category predictor based on merchant/payee name
  static String predictCategoryId(String payee) {
    final lower = payee.toLowerCase();

    // Food & Dining
    if (lower.contains('zomato') ||
        lower.contains('swiggy') ||
        lower.contains('starbucks') ||
        lower.contains('mcdonald') ||
        lower.contains('burger') ||
        lower.contains('pizza') ||
        lower.contains('cafe') ||
        lower.contains('tea') ||
        lower.contains('chai') ||
        lower.contains('restaurant') ||
        lower.contains('dhaba') ||
        lower.contains('bakery') ||
        lower.contains('food')) {
      return 'food';
    }

    // Groceries
    if (lower.contains('blinkit') ||
        lower.contains('zepto') ||
        lower.contains('instamart') ||
        lower.contains('dmart') ||
        lower.contains('bigbasket') ||
        lower.contains('grocery') ||
        lower.contains('supermarket') ||
        lower.contains('vegetable') ||
        lower.contains('fruit') ||
        lower.contains('dairy')) {
      return 'groceries';
    }

    // Transport & Fuel
    if (lower.contains('uber') ||
        lower.contains('ola') ||
        lower.contains('rapido') ||
        lower.contains('metro') ||
        lower.contains('petrol') ||
        lower.contains('fuel') ||
        lower.contains('shell') ||
        lower.contains('hpcl') ||
        lower.contains('bpcl') ||
        lower.contains('ioc') ||
        lower.contains('toll') ||
        lower.contains('irctc') ||
        lower.contains('railway')) {
      return 'transport';
    }

    // Shopping
    if (lower.contains('amazon') ||
        lower.contains('flipkart') ||
        lower.contains('myntra') ||
        lower.contains('zara') ||
        lower.contains('h&m') ||
        lower.contains('ajio') ||
        lower.contains('shopping') ||
        lower.contains('mall')) {
      return 'shopping';
    }

    // Bills & Utilities
    if (lower.contains('bescom') ||
        lower.contains('airtel') ||
        lower.contains('jio') ||
        lower.contains('vodafone') ||
        lower.contains('electricity') ||
        lower.contains('broadband') ||
        lower.contains('wifi') ||
        lower.contains('gas') ||
        lower.contains('bill') ||
        lower.contains('recharge')) {
      return 'bills';
    }

    // Entertainment
    if (lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('hotstar') ||
        lower.contains('prime') ||
        lower.contains('pvr') ||
        lower.contains('inox') ||
        lower.contains('cinema') ||
        lower.contains('movie') ||
        lower.contains('steam')) {
      return 'entertainment';
    }

    // Health & Medical
    if (lower.contains('pharmacy') ||
        lower.contains('apollo') ||
        lower.contains('medplus') ||
        lower.contains('1mg') ||
        lower.contains('hospital') ||
        lower.contains('clinic') ||
        lower.contains('doctor') ||
        lower.contains('dental')) {
      return 'health';
    }

    return 'food';
  }
}

