import 'package:flutter/material.dart';

enum TransactionType {
  expense,
  income,
  transfer,
}

enum PaymentMode {
  offlineCash,
  onlineUpi,
  creditCard,
  debitCard,
  netBanking,
}

extension PaymentModeExtension on PaymentMode {
  String get displayName {
    switch (this) {
      case PaymentMode.offlineCash:
        return 'Offline (Cash)';
      case PaymentMode.onlineUpi:
        return 'Online (UPI / GPay / PhonePe)';
      case PaymentMode.creditCard:
        return 'Credit Card';
      case PaymentMode.debitCard:
        return 'Debit Card';
      case PaymentMode.netBanking:
        return 'Net Banking';
    }
  }

  String get shortName {
    switch (this) {
      case PaymentMode.offlineCash:
        return 'Cash';
      case PaymentMode.onlineUpi:
        return 'UPI';
      case PaymentMode.creditCard:
        return 'Credit Card';
      case PaymentMode.debitCard:
        return 'Debit Card';
      case PaymentMode.netBanking:
        return 'NetBank';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMode.offlineCash:
        return Icons.money_rounded;
      case PaymentMode.onlineUpi:
        return Icons.qr_code_scanner_rounded;
      case PaymentMode.creditCard:
        return Icons.credit_card_rounded;
      case PaymentMode.debitCard:
        return Icons.payment_rounded;
      case PaymentMode.netBanking:
        return Icons.account_balance_rounded;
    }
  }

  bool get isOnline => this != PaymentMode.offlineCash;
}

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String accountId;
  final String? toAccountId; // For transfers
  final PaymentMode paymentMode;
  final DateTime dateTime;
  final String note;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.toAccountId,
    required this.paymentMode,
    required this.dateTime,
    this.note = '',
  });

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    String? toAccountId,
    PaymentMode? paymentMode,
    DateTime? dateTime,
    String? note,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      paymentMode: paymentMode ?? this.paymentMode,
      dateTime: dateTime ?? this.dateTime,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'categoryId': categoryId,
      'accountId': accountId,
      'toAccountId': toAccountId,
      'paymentMode': paymentMode.name,
      'dateTime': dateTime.toIso8601String(),
      'note': note,
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TransactionType.expense,
      ),
      categoryId: json['categoryId'] as String? ?? 'others',
      accountId: json['accountId'] as String? ?? '',
      toAccountId: json['toAccountId'] as String?,
      paymentMode: PaymentMode.values.firstWhere(
        (m) => m.name == json['paymentMode'],
        orElse: () => PaymentMode.onlineUpi,
      ),
      dateTime: DateTime.parse(json['dateTime'] as String),
      note: json['note'] as String? ?? '',
    );
  }
}
