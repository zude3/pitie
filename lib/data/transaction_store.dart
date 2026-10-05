import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/debt_model.dart';
import '../models/financial_activity_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';

class TransactionStore extends ChangeNotifier {
  TransactionStore({DatabaseHelper? database})
    : _database = database ?? DatabaseHelper.instance;

  final DatabaseHelper _database;
  List<TransactionModel> transactions = [];
  List<DebtModel> debts = [];
  List<SavingsGoalModel> savingsGoals = [];
  List<FinancialActivityModel> financialActivities = [];

  Future<void> initialize() async {
    await _database.initDatabase();
    await refresh();
  }

  Future<void> refresh() async {
    transactions = await _database.getTransactions();
    debts = (await _database.getDebts()).map(DebtModel.fromMap).toList();
    savingsGoals = (await _database.getSavingsGoals())
        .map(SavingsGoalModel.fromMap)
        .toList();
    financialActivities = (await _database.getFinancialActivities())
        .map(FinancialActivityModel.fromMap)
        .toList();
    notifyListeners();
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
    await _database.insertTransaction(transaction);
    await refresh();
  }

  Future<void> update(TransactionModel transaction) async {
    await _database.updateTransaction(transaction);
    await refresh();
  }

  Future<void> remove(int id) async {
    await _database.deleteTransaction(id);
    await refresh();
  }

  Future<void> addDebt(DebtModel debt) async {
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
    await _database.insertDebt(
      debt.toMap(),
      openingTransaction: openingTransaction?.toMap(),
    );
    await refresh();
  }

  Future<void> repayDebt(DebtModel debt) async {
    if (debt.id == null) throw ArgumentError('Debt id is required.');
    final updated = await _database.repayDebt(debt.id!, DateTime.now());
    if (updated) await refresh();
  }

  Future<void> addSavingsGoal(SavingsGoalModel goal) async {
    await _database.insertSavingsGoal(goal.toMap());
    await refresh();
  }

  Future<void> addSavingsAmount(SavingsGoalModel goal, double amount) async {
    if (goal.id == null) throw ArgumentError('Savings goal id is required.');
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Savings deposit must be greater than zero.');
    }
    await _database.recordSavingsDeposit(goal.id!, amount, DateTime.now());
    await refresh();
  }

  Future<void> useSavings(
    SavingsGoalModel goal,
    double amount,
    String purpose,
    DateTime date,
  ) async {
    if (goal.id == null) throw ArgumentError('Savings goal id is required.');
    if (!amount.isFinite || amount <= 0 || amount > goal.savedAmount) {
      throw ArgumentError('Savings amount is invalid or insufficient.');
    }
    if (purpose.trim().isEmpty) {
      throw ArgumentError('Savings use purpose is required.');
    }
    await _database.recordSavingsUse(goal.id!, amount, purpose.trim(), date);
    await refresh();
  }
}

class PitieScope extends InheritedNotifier<TransactionStore> {
  const PitieScope({required super.notifier, required super.child, super.key});

  static TransactionStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PitieScope>()!.notifier!;
}
