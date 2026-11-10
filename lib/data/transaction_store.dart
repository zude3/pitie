import 'dart:async';

import 'package:flutter/material.dart';

import '../models/debt_model.dart';
import '../models/financial_activity_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';
import '../repositories/finance_repository.dart';
import '../repositories/sqlite_finance_repository.dart';

class TransactionStore extends ChangeNotifier {
  TransactionStore({FinanceRepository? repository})
    : _repository = repository ?? SqliteFinanceRepository();

  final FinanceRepository _repository;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<TransactionModel> transactions = [];
  List<DebtModel> debts = [];
  List<SavingsGoalModel> savingsGoals = [];
  List<FinancialActivityModel> financialActivities = [];

  Future<void> initialize() async {
    _listenToRepository();
    await _repository.initialize();
  }

  Future<void> refresh() async {
    _listenToRepository();
    await _repository.refresh();
  }

  double get income => _total(TransactionType.income);
  double get expenses => _total(TransactionType.expense);
  double get balance => income - expenses;
  double get savingsBalance =>
      savingsGoals.fold<double>(0, (sum, goal) => sum + goal.savedAmount);

  List<TransactionModel> get recentTransactions {
    final recent = List<TransactionModel>.of(transactions)
      ..sort((first, second) => second.date.compareTo(first.date));
    return recent.take(5).toList();
  }

  double _total(TransactionType type) => transactions
      .where(
        (transaction) =>
            transaction.type == type &&
            transaction.account == TransactionAccount.main,
      )
      .fold(0, (sum, transaction) => sum + transaction.amount);

  Future<void> add(TransactionModel transaction) async {
    _listenToRepository();
    await _repository.addTransaction(transaction);
  }

  Future<void> update(TransactionModel transaction) async {
    _listenToRepository();
    await _repository.updateTransaction(transaction);
  }

  Future<void> remove(String id) async {
    _listenToRepository();
    await _repository.deleteTransaction(id);
  }

  Future<void> addDebt(DebtModel debt) async {
    _validateDebt(debt);
    _listenToRepository();
    final openingTransaction = switch (debt.type) {
      DebtType.loan => TransactionModel(
        type: TransactionType.income,
        amount: debt.amount,
        category: 'Pinjaman',
        description: 'Pinjaman: ${debt.recipient}',
        date: debt.date,
      ),
      DebtType.debt => null,
      DebtType.receivable => TransactionModel(
        type: TransactionType.expense,
        amount: debt.amount,
        category: 'Piutang',
        description: 'Piutang: ${debt.recipient}',
        date: debt.date,
      ),
    };
    await _repository.addDebt(debt, openingTransaction: openingTransaction);
  }

  Future<void> updateDebt(DebtModel debt) async {
    if (debt.id == null) throw ArgumentError('Debt id is required.');
    _validateDebt(debt);
    _listenToRepository();
    await _repository.updateDebt(debt);
  }

  Future<void> removeDebt(DebtModel debt) async {
    if (debt.id == null) throw ArgumentError('Debt id is required.');
    _listenToRepository();
    await _repository.deleteDebt(debt);
  }

  Future<bool> repayDebt(DebtModel debt) async {
    if (debt.id == null) throw ArgumentError('Debt id is required.');
    if (debt.isPaid) return false;
    _listenToRepository();
    return _repository.repayDebt(debt, DateTime.now());
  }

  Future<void> addSavingsGoal(SavingsGoalModel goal) async {
    _validateSavingsGoal(goal);
    _listenToRepository();
    await _repository.addSavingsGoal(goal);
  }

  Future<void> updateSavingsGoal(SavingsGoalModel goal) async {
    if (goal.id == null) throw ArgumentError('Savings goal id is required.');
    _validateSavingsGoal(goal);
    _listenToRepository();
    await _repository.updateSavingsGoal(goal);
  }

  Future<void> removeSavingsGoal(SavingsGoalModel goal) async {
    if (goal.id == null) throw ArgumentError('Savings goal id is required.');
    _listenToRepository();
    await _repository.deleteSavingsGoal(goal);
  }

  Future<void> addSavingsAmount(SavingsGoalModel goal, double amount) async {
    if (goal.id == null) throw ArgumentError('Savings goal id is required.');
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Savings deposit must be greater than zero.');
    }
    _listenToRepository();
    await _repository.recordSavingsDeposit(goal, amount, DateTime.now());
  }

  Future<void> useSavings(
    SavingsGoalModel goal,
    double amount,
    String category,
    DateTime date,
  ) async {
    if (goal.id == null) throw ArgumentError('Savings goal id is required.');
    if (!amount.isFinite || amount <= 0 || amount > goal.savedAmount) {
      throw ArgumentError('Savings amount is invalid or insufficient.');
    }
    if (category.trim().isEmpty) {
      throw ArgumentError('Savings use category is required.');
    }
    _listenToRepository();
    await _repository.recordSavingsUse(goal, amount, category.trim(), date);
  }

  Future<void> updateSavingsActivity(TransactionModel transaction) async {
    if (transaction.id == null) {
      throw ArgumentError('Savings transaction id is required.');
    }
    if (!transaction.amount.isFinite || transaction.amount <= 0) {
      throw ArgumentError('Savings activity amount must be greater than zero.');
    }
    if (transaction.category.trim().isEmpty) {
      throw ArgumentError('Savings activity category is required.');
    }
    _listenToRepository();
    await _repository.updateSavingsActivity(transaction);
  }

  Future<void> removeSavingsActivity(TransactionModel transaction) async {
    if (transaction.id == null) {
      throw ArgumentError('Savings transaction id is required.');
    }
    _listenToRepository();
    await _repository.deleteSavingsActivity(transaction);
  }

  void _validateDebt(DebtModel debt) {
    if (!debt.amount.isFinite || debt.amount <= 0) {
      throw ArgumentError('Debt amount must be greater than zero.');
    }
    if (debt.recipient.trim().isEmpty) {
      throw ArgumentError('Debt recipient is required.');
    }
  }

  void _validateSavingsGoal(SavingsGoalModel goal) {
    if (goal.name.trim().isEmpty) {
      throw ArgumentError('Savings goal name is required.');
    }
    if (!goal.targetAmount.isFinite || goal.targetAmount <= 0) {
      throw ArgumentError('Savings target must be greater than zero.');
    }
    if (!goal.savedAmount.isFinite || goal.savedAmount < 0) {
      throw ArgumentError('Savings balance cannot be negative.');
    }
  }

  Future<void> clearDebts() async {
    _listenToRepository();
    await _repository.clearDebts();
  }

  void _listenToRepository() {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions
      ..add(
        _repository.watchTransactions().listen((items) {
          transactions = items;
          notifyListeners();
        }),
      )
      ..add(
        _repository.watchDebts().listen((items) {
          debts = items;
          notifyListeners();
        }),
      )
      ..add(
        _repository.watchSavingsGoals().listen((items) {
          savingsGoals = items;
          notifyListeners();
        }),
      )
      ..add(
        _repository.watchFinancialActivities().listen((items) {
          financialActivities = items;
          notifyListeners();
        }),
      );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _repository.dispose();
    super.dispose();
  }
}

class PitieScope extends InheritedNotifier<TransactionStore> {
  const PitieScope({required super.notifier, required super.child, super.key});

  static TransactionStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PitieScope>()!.notifier!;
}
