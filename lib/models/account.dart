import 'package:flutter/material.dart';

enum AccountType {
  savings,
  bank,
  cash,
  creditCard,
}

extension AccountTypeExtension on AccountType {
  String get displayName {
    switch (this) {
      case AccountType.savings:
        return 'Savings Account';
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.cash:
        return 'Cash in Hand';
      case AccountType.creditCard:
        return 'Credit Card';
    }
  }

  IconData get icon {
    switch (this) {
      case AccountType.savings:
        return Icons.savings_rounded;
      case AccountType.bank:
        return Icons.account_balance_rounded;
      case AccountType.cash:
        return Icons.payments_rounded;
      case AccountType.creditCard:
        return Icons.credit_card_rounded;
    }
  }
}

class Account {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final int colorValue;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    int? colorValue,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'balance': balance,
      'colorValue': colorValue,
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AccountType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AccountType.bank,
      ),
      balance: (json['balance'] as num).toDouble(),
      colorValue: json['colorValue'] as int? ?? 0xFF0D9488,
    );
  }
}
