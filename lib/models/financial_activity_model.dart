import 'package:cloud_firestore/cloud_firestore.dart';

enum FinancialActivityType { debtRepayment, savingsDeposit, savingsUse }

class FinancialActivityModel {
  const FinancialActivityModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.title,
    required this.date,
  });

  final String? id;
  final FinancialActivityType type;
  final double amount;
  final String title;
  final DateTime date;

  factory FinancialActivityModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final map = snapshot.data();
    if (map == null) {
      throw StateError(
        'Financial activity document ${snapshot.id} has no data.',
      );
    }
    final type = switch (map['kind']) {
      'debt_repayment' => FinancialActivityType.debtRepayment,
      'savings_deposit' => FinancialActivityType.savingsDeposit,
      'savings_use' => FinancialActivityType.savingsUse,
      final value => throw FormatException('Invalid activity type: $value'),
    };
    return FinancialActivityModel(
      id: snapshot.id,
      type: type,
      amount: (map['amount'] as num).toDouble(),
      title: map['title'] as String,
      date: (map['date'] as Timestamp).toDate(),
    );
  }

  Map<String, Object?> toFirestore() => {
    'kind': switch (type) {
      FinancialActivityType.debtRepayment => 'debt_repayment',
      FinancialActivityType.savingsDeposit => 'savings_deposit',
      FinancialActivityType.savingsUse => 'savings_use',
    },
    'amount': amount,
    'title': title,
    'date': Timestamp.fromDate(date),
  };

  factory FinancialActivityModel.fromLegacyMap(Map<String, Object?> map) {
    final type = switch (map['kind']) {
      'debt_repayment' => FinancialActivityType.debtRepayment,
      'savings_deposit' => FinancialActivityType.savingsDeposit,
      'savings_use' => FinancialActivityType.savingsUse,
      final value => throw FormatException('Invalid activity type: $value'),
    };
    final id = map['id'];
    if (id == null) throw FormatException('Financial activity id is required.');
    return FinancialActivityModel(
      id: id.toString(),
      type: type,
      amount: (map['amount'] as num).toDouble(),
      title: map['title'] as String,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
