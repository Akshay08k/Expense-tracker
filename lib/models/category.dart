import 'package:flutter/material.dart';

class ExpenseCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  static const List<ExpenseCategory> defaultCategories = [
    ExpenseCategory(
      id: 'food',
      name: 'Food & Dining',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFF97316), // Warm Orange
    ),
    ExpenseCategory(
      id: 'groceries',
      name: 'Groceries',
      icon: Icons.local_grocery_store_rounded,
      color: Color(0xFF10B981), // Fresh Emerald
    ),
    ExpenseCategory(
      id: 'shopping',
      name: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFEC4899), // Pink
    ),
    ExpenseCategory(
      id: 'transport',
      name: 'Transport',
      icon: Icons.directions_subway_rounded,
      color: Color(0xFF06B6D4), // Cyan
    ),
    ExpenseCategory(
      id: 'bills',
      name: 'Bills & Utilities',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF8B5CF6), // Purple
    ),
    ExpenseCategory(
      id: 'entertainment',
      name: 'Entertainment',
      icon: Icons.movie_filter_rounded,
      color: Color(0xFFEAB308), // Amber
    ),
    ExpenseCategory(
      id: 'health',
      name: 'Health & Medical',
      icon: Icons.favorite_rounded,
      color: Color(0xFFEF4444), // Crimson
    ),
    ExpenseCategory(
      id: 'salary',
      name: 'Salary & Income',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF22C55E), // Vibrant Green
    ),
    ExpenseCategory(
      id: 'savings',
      name: 'Savings & Deposit',
      icon: Icons.savings_rounded,
      color: Color(0xFF14B8A6), // Teal
    ),
    ExpenseCategory(
      id: 'others',
      name: 'Others',
      icon: Icons.category_rounded,
      color: Color(0xFF64748B), // Slate
    ),
  ];

  static ExpenseCategory findById(String id) {
    return defaultCategories.firstWhere(
      (cat) => cat.id == id,
      orElse: () => const ExpenseCategory(
        id: 'others',
        name: 'Others',
        icon: Icons.category_rounded,
        color: Color(0xFF64748B),
      ),
    );
  }
}
