enum FinancialActivityType { debtRepayment, savingsDeposit, savingsUse }

class FinancialActivityModel {
  const FinancialActivityModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.title,
    required this.date,
  });

  final int id;
  final FinancialActivityType type;
  final double amount;
  final String title;
  final DateTime date;

  factory FinancialActivityModel.fromMap(Map<String, Object?> map) {
    final type = switch (map['kind']) {
      'debt_repayment' => FinancialActivityType.debtRepayment,
      'savings_deposit' => FinancialActivityType.savingsDeposit,
      'savings_use' => FinancialActivityType.savingsUse,
      final value => throw FormatException('Invalid activity type: $value'),
    };
    return FinancialActivityModel(
      id: map['id'] as int,
      type: type,
      amount: (map['amount'] as num).toDouble(),
      title: map['title'] as String,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
