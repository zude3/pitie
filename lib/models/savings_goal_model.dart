import 'package:cloud_firestore/cloud_firestore.dart';

class SavingsGoalModel {
  const SavingsGoalModel({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.createdAt,
  });

  final String? id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime createdAt;

  factory SavingsGoalModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final map = snapshot.data();
    if (map == null) {
      throw StateError('Savings goal document ${snapshot.id} has no data.');
    }
    return SavingsGoalModel(
      id: snapshot.id,
      name: map['name'] as String,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      savedAmount: (map['savedAmount'] as num).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, Object?> toFirestore() => {
    'name': name,
    'targetAmount': targetAmount,
    'savedAmount': savedAmount,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory SavingsGoalModel.fromLegacyMap(Map<String, Object?> map) =>
      SavingsGoalModel(
        id: map['id']?.toString(),
        name: map['name'] as String,
        targetAmount: (map['target_amount'] as num).toDouble(),
        savedAmount: (map['saved_amount'] as num).toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, Object?> toLegacyMap() => {
    'name': name,
    'target_amount': targetAmount,
    'saved_amount': savedAmount,
    'created_at': createdAt.toIso8601String(),
  };
}
