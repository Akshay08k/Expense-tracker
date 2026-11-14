import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/payment_detector_service.dart';

void main() {
  group('PaymentDetectorService Tests', () {
    test('DetectedPayment.fromMap parses numeric and timestamp properly', () {
      final map = {
        'amount': 450.50,
        'title': 'Starbucks Coffee',
        'sourceApp': 'Google Pay',
        'timestamp': 1700000000000,
        'rawText': 'Paid ₹450.50 to Starbucks Coffee',
      };

      final payment = DetectedPayment.fromMap(map);
      expect(payment.amount, 450.50);
      expect(payment.title, 'Starbucks Coffee');
      expect(payment.sourceApp, 'Google Pay');
      expect(payment.timestamp.millisecondsSinceEpoch, 1700000000000);
      expect(payment.rawText, 'Paid ₹450.50 to Starbucks Coffee');
    });

    test('DetectedPayment.fromMap handles string amount gracefully', () {
      final map = {
        'amount': '125.0',
        'title': 'Chai Point',
        'sourceApp': 'PhonePe',
      };

      final payment = DetectedPayment.fromMap(map);
      expect(payment.amount, 125.0);
      expect(payment.title, 'Chai Point');
      expect(payment.sourceApp, 'PhonePe');
    });

    test('predictCategoryId categorizes common merchants accurately', () {
      expect(PaymentDetectorService.predictCategoryId('Starbucks Coffee'), 'food');
      expect(PaymentDetectorService.predictCategoryId('Zomato Order'), 'food');
      expect(PaymentDetectorService.predictCategoryId('Swiggy Instamart'), 'food'); // or groceries depending on precedence
      expect(PaymentDetectorService.predictCategoryId('Blinkit Groceries'), 'groceries');
      expect(PaymentDetectorService.predictCategoryId('DMart Supermarket'), 'groceries');
      expect(PaymentDetectorService.predictCategoryId('Uber India Rides'), 'transport');
      expect(PaymentDetectorService.predictCategoryId('HPCL Petrol Pump'), 'transport');
      expect(PaymentDetectorService.predictCategoryId('Amazon Retail'), 'shopping');
      expect(PaymentDetectorService.predictCategoryId('Netflix Subscription'), 'entertainment');
      expect(PaymentDetectorService.predictCategoryId('Apollo Pharmacy'), 'health');
      expect(PaymentDetectorService.predictCategoryId('Airtel Postpaid Recharge'), 'bills');
    });
  });
}

