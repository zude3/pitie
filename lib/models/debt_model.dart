import 'package:cloud_firestore/cloud_firestore.dart';

enum DebtType { loan, debt, receivable }

extension DebtTypeLabel on DebtType {
  String get label => switch (this) {
    DebtType.loan => 'Pinjaman',
    DebtType.debt => 'Hutang',
    DebtType.receivable => 'Piutang',
  };
}

class DebtModel {
  const DebtModel({
    this.id,
    required this.amount,
    required this.recipient,
    required this.category,
    required this.date,
    required this.note,
    required this.isPaid,
    this.dueDate,
    this.paidAt,
    this.type = DebtType.debt,
  });

  final String? id;
  final double amount;
  final String recipient;
  final String category;
  final DateTime date;
  final String note;
  final bool isPaid;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final DebtType type;

  bool get isOverdue {
    if (isPaid || dueDate == null) return false;
    final today = DateTime.now();
    final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final currentDay = DateTime(today.year, today.month, today.day);
    return dueDay.isBefore(currentDay);
  }

  String get status => isPaid
      ? 'Lunas'
      : isOverdue
      ? 'Lewat batas waktu'
      : 'Belum lunas';

  factory DebtModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final map = snapshot.data();
    if (map == null) {
      throw StateError('Debt document ${snapshot.id} has no data.');
    }
    return DebtModel(
      id: snapshot.id,
      amount: (map['amount'] as num).toDouble(),
      recipient: map['recipient'] as String,
      category: map['category'] as String,
      date: (map['date'] as Timestamp).toDate(),
      note: (map['note'] as String?) ?? '',
      isPaid: map['isPaid'] as bool,
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      paidAt: (map['paidAt'] as Timestamp?)?.toDate(),
      type: switch (map['type']) {
        'loan' => DebtType.loan,
        'receivable' => DebtType.receivable,
        _ => DebtType.debt,
      },
    );
  }

  Map<String, Object?> toFirestore() => {
    'amount': amount,
    'recipient': recipient,
    'category': category,
    'date': Timestamp.fromDate(date),
    'note': note,
    'isPaid': isPaid,
    'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
    'paidAt': paidAt == null ? null : Timestamp.fromDate(paidAt!),
    'type': type.name,
  };

  factory DebtModel.fromLegacyMap(Map<String, Object?> map) => DebtModel(
    id: map['id']?.toString(),
    amount: (map['amount'] as num).toDouble(),
    recipient: map['recipient'] as String,
    category: map['category'] as String,
    date: DateTime.parse(map['date'] as String),
    note: (map['note'] as String?) ?? '',
    isPaid: (map['is_paid'] as int) == 1,
    dueDate: map['due_date'] == null
        ? null
        : DateTime.parse(map['due_date'] as String),
    paidAt: map['paid_at'] == null
        ? null
        : DateTime.parse(map['paid_at'] as String),
    type: switch (map['type']) {
      'loan' => DebtType.loan,
      'receivable' => DebtType.receivable,
      _ => DebtType.debt,
    },
  );

  Map<String, Object?> toLegacyMap() => {
    'amount': amount,
    'recipient': recipient,
    'category': category,
    'date': date.toIso8601String(),
    'note': note,
    'is_paid': isPaid ? 1 : 0,
    'due_date': dueDate?.toIso8601String(),
    'paid_at': paidAt?.toIso8601String(),
    'type': type.name,
  };
}
