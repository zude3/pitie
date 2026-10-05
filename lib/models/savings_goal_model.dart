class SavingsGoalModel {
  const SavingsGoalModel({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime createdAt;

  factory SavingsGoalModel.fromMap(Map<String, Object?> map) =>
      SavingsGoalModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        targetAmount: (map['target_amount'] as num).toDouble(),
        savedAmount: (map['saved_amount'] as num).toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
    'name': name,
    'target_amount': targetAmount,
    'saved_amount': savedAmount,
    'created_at': createdAt.toIso8601String(),
  };
}
