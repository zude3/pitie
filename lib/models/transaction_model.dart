import 'package:flutter/material.dart';

import '../models/category_model.dart';

enum TransactionType { income, expense }

enum TransactionAccount { main, savings }

class TransactionModel {
  TransactionModel({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    this.createdAt,
    this.account = TransactionAccount.main,
    this.debtId,
    this.savingsGoalId,
  });

  int? id;
  TransactionType type;
  double amount;
  String category;
  String description;
  DateTime date;
  DateTime? createdAt;
  TransactionAccount account;
  int? debtId;
  int? savingsGoalId;

  IconData get icon => categoryFor(category).icon;

  factory TransactionModel.fromMap(Map<String, Object?> map) {
    final typeValue = map['type'] as String?;
    final type = switch (typeValue) {
      'income' => TransactionType.income,
      'expense' => TransactionType.expense,
      _ => throw FormatException('Invalid transaction type: $typeValue'),
    };
    return TransactionModel(
      id: map['id'] as int?,
      type: type,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      description: (map['description'] as String?) ?? '',
      date: DateTime.parse(map['date'] as String),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
      account: switch (map['account']) {
        'savings' => TransactionAccount.savings,
        _ => TransactionAccount.main,
      },
      debtId: map['debt_id'] as int?,
      savingsGoalId: map['savings_goal_id'] as int?,
    );
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'type': type.name,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.toIso8601String(),
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'account': account.name,
      'debt_id': debtId,
      'savings_goal_id': savingsGoalId,
    };
    if (id != null) map['id'] = id!;
    return map;
  }
}
