import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/debt_model.dart';
import '../models/financial_activity_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';
import 'finance_repository.dart';

class FirestoreFinanceRepository implements FinanceRepository {
  FirestoreFinanceRepository(FirebaseFirestore firestore, {required String uid})
    : _user = firestore.collection('users').doc(uid);

  static const _commitTimeout = Duration(seconds: 15);

  final DocumentReference<Map<String, dynamic>> _user;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _user.collection('transactions');

  CollectionReference<Map<String, dynamic>> get _debts =>
      _user.collection('debts');

  CollectionReference<Map<String, dynamic>> get _savingsGoals =>
      _user.collection('savings_goals');

  CollectionReference<Map<String, dynamic>> get _financialActivities =>
      _user.collection('financial_activities');

  @override
  Stream<List<TransactionModel>> watchTransactions() => _transactions
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) {
        final transactions = snapshot.docs
            .map(TransactionModel.fromFirestore)
            .toList();
        transactions.sort((first, second) {
          final dateOrder = second.date.compareTo(first.date);
          if (dateOrder != 0) return dateOrder;
          final firstCreatedAt =
              first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final secondCreatedAt =
              second.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return secondCreatedAt.compareTo(firstCreatedAt);
        });
        return transactions;
      });

  @override
  Stream<List<DebtModel>> watchDebts() => _debts
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(DebtModel.fromFirestore).toList(growable: false),
      );

  @override
  Stream<List<SavingsGoalModel>> watchSavingsGoals() => _savingsGoals
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(SavingsGoalModel.fromFirestore)
            .toList(growable: false),
      );

  @override
  Stream<List<FinancialActivityModel>> watchFinancialActivities() =>
      _financialActivities
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(FinancialActivityModel.fromFirestore)
                .toList(growable: false),
          );

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> addTransaction(TransactionModel transaction) async {
    _validateTransaction(transaction);
    final id = transaction.id;
    final reference = id == null ? _transactions.doc() : _transactions.doc(id);
    transaction.id = reference.id;
    transaction.createdAt ??= DateTime.now();
    await reference
        .set(Map<String, dynamic>.from(transaction.toFirestore()))
        .timeout(_commitTimeout);
  }

  @override
  Future<void> updateTransaction(TransactionModel transaction) async {
    _validateTransaction(transaction, requireId: true);
    transaction.createdAt ??= DateTime.now();
    final id = transaction.id!;
    await _transactions
        .doc(id)
        .update(Map<String, dynamic>.from(transaction.toFirestore()))
        .timeout(_commitTimeout);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _transactions.doc(id).delete().timeout(_commitTimeout);
  }

  @override
  Future<void> addDebt(
    DebtModel debt, {
    TransactionModel? openingTransaction,
  }) async {
    final debtReference = _debts.doc();
    final batch = _user.firestore.batch()
      ..set(debtReference, Map<String, dynamic>.from(debt.toFirestore()));

    if (openingTransaction != null) {
      _validateTransaction(openingTransaction);
      final transactionReference = _transactions.doc();
      openingTransaction
        ..id = transactionReference.id
        ..debtId = debtReference.id
        ..createdAt ??= DateTime.now();
      batch.set(
        transactionReference,
        Map<String, dynamic>.from(openingTransaction.toFirestore()),
      );
    }

    await batch.commit().timeout(_commitTimeout);
  }

  @override
  Future<void> updateDebt(DebtModel debt) async {
    final debtId = debt.id;
    if (debtId == null) throw ArgumentError('Debt id is required.');
    final debtReference = _debts.doc(debtId);
    final debtSnapshot = await debtReference.get();
    if (!debtSnapshot.exists) throw StateError('Debt not found.');
    final linkedTransactions = (await _transactions
            .where('debtId', isEqualTo: debtId)
            .get())
        .docs;
    final openings = linkedTransactions.where(
      (document) =>
          !(document.data()['category'] as String? ?? '').startsWith(
            'Pelunasan ',
          ),
    );
    final repayments = linkedTransactions.where(
      (document) =>
          (document.data()['category'] as String? ?? '').startsWith(
            'Pelunasan ',
          ),
    );
    final opening = openings.firstOrNull;
    final batch = _user.firestore.batch()
      ..update(debtReference, Map<String, dynamic>.from(debt.toFirestore()));

    final openingType = _openingType(debt.type);
    if (openingType == null) {
      for (final document in openings) {
        batch.delete(document.reference);
      }
    } else {
      final openingTransaction = opening == null
          ? null
          : TransactionModel.fromFirestore(opening);
      final transaction = (openingTransaction ??
          TransactionModel(
            type: openingType,
            amount: debt.amount,
            category: debt.type == DebtType.loan ? 'Pinjaman' : 'Piutang',
            description: '',
            date: debt.date,
            debtId: debtId,
          ))
        ..type = openingType
        ..amount = debt.amount
        ..category = debt.type == DebtType.loan ? 'Pinjaman' : 'Piutang'
        ..description = '${debt.type.label}: ${debt.recipient}'
        ..date = debt.date
        ..debtId = debtId;
      _validateTransaction(transaction);
      if (opening == null) {
        final reference = _transactions.doc();
        transaction
          ..id = reference.id
          ..createdAt = DateTime.now();
        batch.set(
          reference,
          Map<String, dynamic>.from(transaction.toFirestore()),
        );
      } else {
        batch.update(
          opening.reference,
          Map<String, dynamic>.from(transaction.toFirestore()),
        );
      }
    }

    for (final document in repayments) {
      final current = TransactionModel.fromFirestore(document);
      final activity = await _activityForTransaction(
        current,
        FinancialActivityType.debtRepayment,
        legacyTitle: debtSnapshot.data()?['recipient'] as String?,
      );
      final transaction = current
        ..type = debt.type == DebtType.receivable
            ? TransactionType.income
            : TransactionType.expense
        ..amount = debt.amount
        ..category = _repaymentCategory(debt.type)
        ..description = '${_repaymentCategory(debt.type)}: ${debt.recipient}'
        ..debtId = debtId
        ..financialActivityId = activity?.id;
      batch.update(
        document.reference,
        Map<String, dynamic>.from(transaction.toFirestore()),
      );
      if (activity != null) {
        batch.update(activity.reference, {
          'amount': debt.amount,
          'title': debt.recipient,
          'debtId': debtId,
          'transactionId': transaction.id,
        });
      }
    }

    await batch.commit().timeout(_commitTimeout);
  }

  @override
  Future<void> deleteDebt(DebtModel debt) async {
    final debtId = debt.id;
    if (debtId == null) throw ArgumentError('Debt id is required.');
    final debtReference = _debts.doc(debtId);
    final debtSnapshot = await debtReference.get();
    if (!debtSnapshot.exists) throw StateError('Debt not found.');
    final transactions = (await _transactions
            .where('debtId', isEqualTo: debtId)
            .get())
        .docs;
    final activityReferences = <DocumentReference<Map<String, dynamic>>>{};
    for (final document in transactions.where(
      (item) =>
          (item.data()['category'] as String? ?? '').startsWith('Pelunasan '),
    )) {
      final transaction = TransactionModel.fromFirestore(document);
      final activity = await _activityForTransaction(
        transaction,
        FinancialActivityType.debtRepayment,
        legacyTitle: debtSnapshot.data()?['recipient'] as String?,
      );
      if (activity != null) activityReferences.add(activity.reference);
    }

    final batch = _user.firestore.batch()
      ..delete(debtReference);
    for (final document in transactions) {
      batch.delete(document.reference);
    }
    for (final reference in activityReferences) {
      batch.delete(reference);
    }
    await batch.commit().timeout(_commitTimeout);
  }

  @override
  Future<bool> repayDebt(DebtModel debt, DateTime paidAt) async {
    final debtId = debt.id;
    if (debtId == null) throw ArgumentError('Debt id is required.');
    if (debt.isPaid) return false;

    final debtReference = _debts.doc(debtId);
    final activityReference = _financialActivities.doc();
    final transactionReference = _transactions.doc();
    final isIncome = debt.type == DebtType.receivable;
    final category = switch (debt.type) {
      DebtType.loan => 'Pelunasan pinjaman',
      DebtType.receivable => 'Pelunasan piutang',
      DebtType.debt => 'Pelunasan hutang',
    };
    final activity = FinancialActivityModel(
      id: activityReference.id,
      type: FinancialActivityType.debtRepayment,
      amount: debt.amount,
      title: debt.recipient,
      date: paidAt,
      debtId: debtId,
      transactionId: transactionReference.id,
    );
    final transaction = TransactionModel(
      id: transactionReference.id,
      type: isIncome ? TransactionType.income : TransactionType.expense,
      amount: debt.amount,
      category: category,
      description: '$category: ${debt.recipient}',
      date: paidAt,
      debtId: debtId,
      financialActivityId: activityReference.id,
    );
    transaction.createdAt ??= DateTime.now();

    final batch = _user.firestore.batch()
      ..update(debtReference, {
        'isPaid': true,
        'paidAt': Timestamp.fromDate(paidAt),
      })
      ..set(
        activityReference,
        Map<String, dynamic>.from(activity.toFirestore()),
      )
      ..set(
        transactionReference,
        Map<String, dynamic>.from(transaction.toFirestore()),
      );
    await batch.commit().timeout(_commitTimeout);
    return true;
  }

  @override
  Future<void> addSavingsGoal(SavingsGoalModel goal) async {
    final reference = goal.id == null
        ? _savingsGoals.doc()
        : _savingsGoals.doc(goal.id);
    await reference
        .set(Map<String, dynamic>.from(goal.toFirestore()))
        .timeout(_commitTimeout);
  }

  @override
  Future<void> updateSavingsGoal(SavingsGoalModel goal) async {
    final goalId = goal.id;
    if (goalId == null) throw ArgumentError('Savings goal id is required.');
    await _savingsGoals.doc(goalId).update({
      'name': goal.name,
      'targetAmount': goal.targetAmount,
    }).timeout(_commitTimeout);
  }

  @override
  Future<void> deleteSavingsGoal(SavingsGoalModel goal) async {
    final goalId = goal.id;
    if (goalId == null) throw ArgumentError('Savings goal id is required.');
    final reference = _savingsGoals.doc(goalId);
    final snapshot = await reference.get();
    if (!snapshot.exists) throw StateError('Savings goal not found.');
    final data = snapshot.data()!;
    final savedAmount = (data['savedAmount'] as num).toDouble();
    final batch = _user.firestore.batch()..delete(reference);
    if (savedAmount > 0) {
      final transactionReference = _transactions.doc();
      final transaction = TransactionModel(
        id: transactionReference.id,
        type: TransactionType.income,
        amount: savedAmount,
        category: 'Tabungan',
        description: 'Pengembalian tabungan: ${data['name']}',
        date: DateTime.now(),
      )..createdAt = DateTime.now();
      batch.set(
        transactionReference,
        Map<String, dynamic>.from(transaction.toFirestore()),
      );
    }
    await batch.commit().timeout(_commitTimeout);
  }

  @override
  Future<void> recordSavingsDeposit(
    SavingsGoalModel goal,
    double amount,
    DateTime date,
  ) async {
    final goalId = goal.id;
    if (goalId == null) throw ArgumentError('Savings goal id is required.');
    final activityReference = _financialActivities.doc();
    final transactionReference = _transactions.doc();
    final activity = FinancialActivityModel(
      id: activityReference.id,
      type: FinancialActivityType.savingsDeposit,
      amount: amount,
      title: goal.name,
      date: date,
      savingsGoalId: goalId,
      transactionId: transactionReference.id,
    );
    final transaction = TransactionModel(
      id: transactionReference.id,
      type: TransactionType.expense,
      amount: amount,
      category: 'Tabungan',
      description: 'Setoran tabungan: ${goal.name}',
      date: date,
      savingsGoalId: goalId,
      financialActivityId: activityReference.id,
    )..createdAt = DateTime.now();

    final batch = _user.firestore.batch()
      ..update(_savingsGoals.doc(goalId), {
        'savedAmount': FieldValue.increment(amount),
      })
      ..set(
        activityReference,
        Map<String, dynamic>.from(activity.toFirestore()),
      )
      ..set(
        transactionReference,
        Map<String, dynamic>.from(transaction.toFirestore()),
      );
    await batch.commit().timeout(_commitTimeout);
  }

  @override
  Future<void> recordSavingsUse(
    SavingsGoalModel goal,
    double amount,
    String category,
    DateTime date,
  ) async {
    final goalId = goal.id;
    if (goalId == null) throw ArgumentError('Savings goal id is required.');
    final activityReference = _financialActivities.doc();
    final transactionReference = _transactions.doc();
    final activity = FinancialActivityModel(
      id: activityReference.id,
      type: FinancialActivityType.savingsUse,
      amount: amount,
      title: category,
      date: date,
      savingsGoalId: goalId,
      transactionId: transactionReference.id,
    );
    final transaction = TransactionModel(
      id: transactionReference.id,
      type: TransactionType.expense,
      amount: amount,
      category: category,
      description: 'Pemakaian tabungan: $category',
      date: date,
      account: TransactionAccount.savings,
      savingsGoalId: goalId,
      financialActivityId: activityReference.id,
    )..createdAt = DateTime.now();

    final batch = _user.firestore.batch()
      ..update(_savingsGoals.doc(goalId), {
        'savedAmount': FieldValue.increment(-amount),
      })
      ..set(
        activityReference,
        Map<String, dynamic>.from(activity.toFirestore()),
      )
      ..set(
        transactionReference,
        Map<String, dynamic>.from(transaction.toFirestore()),
      );
    await batch.commit().timeout(_commitTimeout);
  }

  @override
  Future<void> updateSavingsActivity(TransactionModel transaction) async {
    _validateTransaction(transaction, requireId: true);
    final transactionReference = _transactions.doc(transaction.id!);
    final transactionSnapshot = await transactionReference.get();
    if (!transactionSnapshot.exists) {
      throw StateError('Savings transaction not found.');
    }
    final current = TransactionModel.fromFirestore(transactionSnapshot);
    final goalId = current.savingsGoalId;
    if (goalId == null) throw StateError('Savings goal reference is missing.');
    final goalReference = _savingsGoals.doc(goalId);
    final goalSnapshot = await goalReference.get();
    if (!goalSnapshot.exists) throw StateError('Savings goal not found.');
    final goalData = goalSnapshot.data()!;
    final savedAmount = (goalData['savedAmount'] as num).toDouble();
    final isDeposit = current.account == TransactionAccount.main;
    if (current.type != TransactionType.expense ||
        (!isDeposit &&
            current.account != TransactionAccount.savings) ||
        (isDeposit && current.category != 'Tabungan')) {
      throw StateError('Linked transaction is not a savings activity.');
    }
    final delta = transaction.amount - current.amount;
    final updatedSavedAmount = isDeposit
        ? savedAmount + delta
        : savedAmount - delta;
    if (updatedSavedAmount < 0) {
      throw StateError('Savings balance is insufficient.');
    }
    final activity = await _activityForTransaction(
      current,
      isDeposit
          ? FinancialActivityType.savingsDeposit
          : FinancialActivityType.savingsUse,
      legacyTitle: isDeposit
          ? current.description.replaceFirst('Setoran tabungan: ', '')
          : current.category,
    );
    final updated = TransactionModel(
      id: current.id,
      type: TransactionType.expense,
      amount: transaction.amount,
      category: isDeposit ? 'Tabungan' : transaction.category.trim(),
      description: isDeposit
          ? current.description
          : 'Pemakaian tabungan: ${transaction.category.trim()}',
      date: transaction.date,
      createdAt: current.createdAt,
      account: current.account,
      debtId: current.debtId,
      savingsGoalId: goalId,
      financialActivityId: activity?.id ?? current.financialActivityId,
    );
    _validateTransaction(updated, requireId: true);
    final batch = _user.firestore.batch()
      ..update(goalReference, {'savedAmount': updatedSavedAmount})
      ..update(
        transactionReference,
        Map<String, dynamic>.from(updated.toFirestore()),
      );
    if (activity != null) {
      batch.update(activity.reference, {
        'amount': updated.amount,
        'title': isDeposit ? goalData['name'] : updated.category,
        'date': Timestamp.fromDate(updated.date),
        'savingsGoalId': goalId,
        'transactionId': updated.id,
      });
    }
    await batch.commit().timeout(_commitTimeout);
  }

  @override
  Future<void> deleteSavingsActivity(TransactionModel transaction) async {
    final transactionId = transaction.id;
    if (transactionId == null) {
      throw ArgumentError('Savings transaction id is required.');
    }
    final transactionReference = _transactions.doc(transactionId);
    final transactionSnapshot = await transactionReference.get();
    if (!transactionSnapshot.exists) {
      throw StateError('Savings transaction not found.');
    }
    final current = TransactionModel.fromFirestore(transactionSnapshot);
    final goalId = current.savingsGoalId;
    if (goalId == null) throw StateError('Savings goal reference is missing.');
    final goalReference = _savingsGoals.doc(goalId);
    final goalSnapshot = await goalReference.get();
    if (!goalSnapshot.exists) throw StateError('Savings goal not found.');
    final savedAmount = (goalSnapshot.data()!['savedAmount'] as num)
        .toDouble();
    final isDeposit = current.account == TransactionAccount.main;
    if (current.type != TransactionType.expense ||
        (!isDeposit &&
            current.account != TransactionAccount.savings) ||
        (isDeposit && current.category != 'Tabungan')) {
      throw StateError('Linked transaction is not a savings activity.');
    }
    final updatedSavedAmount = isDeposit
        ? savedAmount - current.amount
        : savedAmount + current.amount;
    if (updatedSavedAmount < 0) {
      throw StateError('Savings balance is insufficient.');
    }
    final activity = await _activityForTransaction(
      current,
      isDeposit
          ? FinancialActivityType.savingsDeposit
          : FinancialActivityType.savingsUse,
      legacyTitle: isDeposit
          ? current.description.replaceFirst('Setoran tabungan: ', '')
          : current.category,
    );
    final batch = _user.firestore.batch()
      ..update(goalReference, {'savedAmount': updatedSavedAmount})
      ..delete(transactionReference);
    if (activity != null) batch.delete(activity.reference);
    await batch.commit().timeout(_commitTimeout);
  }

  @override
  Future<void> clearDebts() async {
    final debts = (await _debts.get()).docs;
    final debtIds = debts.map((debt) => debt.id).toSet();
    final debtIdsList = debtIds.toList();
    final transactionQueries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (var start = 0; start < debtIdsList.length; start += 30) {
      final end = start + 30 < debtIdsList.length
          ? start + 30
          : debtIdsList.length;
      transactionQueries.add(
        _transactions
            .where('debtId', whereIn: debtIdsList.sublist(start, end))
            .get(),
      );
    }

    final results = await Future.wait([
      ...transactionQueries,
      _financialActivities.where('kind', isEqualTo: 'debt_repayment').get(),
    ]);
    final debtTransactions = results
        .take(transactionQueries.length)
        .expand((snapshot) => snapshot.docs);
    final repaymentActivities = results[transactionQueries.length].docs;
    final references = <DocumentReference<Map<String, dynamic>>>[
      ...debtTransactions.map((document) => document.reference),
      ...repaymentActivities.map((document) => document.reference),
      ...debts.map((document) => document.reference),
    ];

    for (var start = 0; start < references.length; start += 500) {
      final batch = _user.firestore.batch();
      final end = (start + 500 < references.length)
          ? start + 500
          : references.length;
      for (final reference in references.sublist(start, end)) {
        batch.delete(reference);
      }
      await batch.commit().timeout(_commitTimeout);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _activityForTransaction(
    TransactionModel transaction,
    FinancialActivityType type, {
    String? legacyTitle,
  }) async {
    final activityId = transaction.financialActivityId;
    if (activityId != null) {
      final snapshot = await _financialActivities.doc(activityId).get();
      if (snapshot.exists) return snapshot;
    }

    final matchingId = await _financialActivities
        .where('transactionId', isEqualTo: transaction.id)
        .get();
    if (matchingId.docs.length == 1) return matchingId.docs.single;
    if (matchingId.docs.length > 1) {
      throw StateError('Multiple financial activities reference this transaction.');
    }

    final kind = switch (type) {
      FinancialActivityType.debtRepayment => 'debt_repayment',
      FinancialActivityType.savingsDeposit => 'savings_deposit',
      FinancialActivityType.savingsUse => 'savings_use',
    };
    final expectedTitle =
        legacyTitle ??
        switch (type) {
          FinancialActivityType.debtRepayment =>
            transaction.description.split(':').skip(1).join(':').trim(),
          FinancialActivityType.savingsDeposit => transaction.description
              .replaceFirst('Setoran tabungan: ', ''),
          FinancialActivityType.savingsUse => transaction.category,
        };
    final candidates = (await _financialActivities
            .where('kind', isEqualTo: kind)
            .get())
        .docs
        .where((document) {
          final data = document.data();
          final date = data['date'];
          return (data['amount'] as num?)?.toDouble() == transaction.amount &&
              data['title'] == expectedTitle &&
              date is Timestamp &&
              date.toDate().isAtSameMomentAs(transaction.date);
        })
        .toList();
    if (candidates.length > 1) {
      throw StateError(
        'Multiple legacy financial activities match this transaction.',
      );
    }
    return candidates.firstOrNull;
  }

  static TransactionType? _openingType(DebtType type) => switch (type) {
    DebtType.loan => TransactionType.income,
    DebtType.receivable => TransactionType.expense,
    DebtType.debt => null,
  };

  static String _repaymentCategory(DebtType type) => switch (type) {
    DebtType.loan => 'Pelunasan pinjaman',
    DebtType.receivable => 'Pelunasan piutang',
    DebtType.debt => 'Pelunasan hutang',
  };

  void _validateTransaction(
    TransactionModel transaction, {
    bool requireId = false,
  }) {
    if (requireId && transaction.id == null) {
      throw ArgumentError('Transaction id is required for update.');
    }
    if (!transaction.amount.isFinite || transaction.amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero.');
    }
    if (transaction.category.trim().isEmpty) {
      throw ArgumentError('Transaction category is required.');
    }
  }

  @override
  void dispose() {}
}
