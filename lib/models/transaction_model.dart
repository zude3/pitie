import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  String? id;
  TransactionType type;
  double amount;
  String category;
  String description;
  DateTime date;
  DateTime? createdAt;
  TransactionAccount account;
  String? debtId;
  String? savingsGoalId;

  IconData get icon => categoryFor(category).icon;

  factory TransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final map = snapshot.data();
    if (map == null) {
      throw StateError('Transaction document ${snapshot.id} has no data.');
    }
    final typeValue = map['type'] as String?;
    final type = switch (typeValue) {
      'income' => TransactionType.income,
      'expense' => TransactionType.expense,
      _ => throw FormatException('Invalid transaction type: $typeValue'),
    };
    return TransactionModel(
      id: snapshot.id,
      type: type,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      description: (map['description'] as String?) ?? '',
      date: (map['date'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      account: switch (map['account']) {
        'savings' => TransactionAccount.savings,
        _ => TransactionAccount.main,
      },
      debtId: map['debtId'] as String?,
      savingsGoalId: map['savingsGoalId'] as String?,
    );
  }

  Map<String, Object?> toFirestore() => {
    'type': type.name,
    'amount': amount,
    'category': category,
    'description': description,
    'date': Timestamp.fromDate(date),
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    'account': account.name,
    'debtId': debtId,
    'savingsGoalId': savingsGoalId,
  };

  factory TransactionModel.fromLegacyMap(Map<String, Object?> map) {
    final typeValue = map['type'] as String?;
    final type = switch (typeValue) {
      'income' => TransactionType.income,
      'expense' => TransactionType.expense,
      _ => throw FormatException('Invalid transaction type: $typeValue'),
    };
    return TransactionModel(
      id: map['id']?.toString(),
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
      debtId: map['debt_id']?.toString(),
      savingsGoalId: map['savings_goal_id']?.toString(),
    );
  }

  Map<String, Object?> toLegacyMap() {
    final map = <String, Object?>{
      'type': type.name,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.toIso8601String(),
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'account': account.name,
      'debt_id': debtId == null ? null : int.parse(debtId!),
      'savings_goal_id': savingsGoalId == null
          ? null
          : int.parse(savingsGoalId!),
    };
    if (id != null) map['id'] = int.parse(id!);
    return map;
  }
}
