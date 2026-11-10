import 'dart:async';

import '../database/database_helper.dart';
import '../models/debt_model.dart';
import '../models/financial_activity_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';
import 'finance_repository.dart';

class SqliteFinanceRepository implements FinanceRepository {
  SqliteFinanceRepository({DatabaseHelper? database})
    : _database = database ?? DatabaseHelper.instance;

  final DatabaseHelper _database;
  final StreamController<List<TransactionModel>> _transactions =
      StreamController.broadcast(sync: true);
  final StreamController<List<DebtModel>> _debts = StreamController.broadcast(
    sync: true,
  );
  final StreamController<List<SavingsGoalModel>> _savingsGoals =
      StreamController.broadcast(sync: true);
  final StreamController<List<FinancialActivityModel>> _financialActivities =
      StreamController.broadcast(sync: true);

  @override
  Stream<List<TransactionModel>> watchTransactions() => _transactions.stream;

  @override
  Stream<List<DebtModel>> watchDebts() => _debts.stream;

  @override
  Stream<List<SavingsGoalModel>> watchSavingsGoals() => _savingsGoals.stream;

  @override
  Stream<List<FinancialActivityModel>> watchFinancialActivities() =>
      _financialActivities.stream;

  @override
  Future<void> initialize() async {
    await _database.initDatabase();
    await refresh();
  }

  @override
  Future<void> refresh() async {
    final transactions = await _database.getTransactions();
    final debts = (await _database.getDebts()).map(DebtModel.fromMap).toList();
    final savingsGoals = (await _database.getSavingsGoals())
        .map(SavingsGoalModel.fromMap)
        .toList();
    final financialActivities = (await _database.getFinancialActivities())
        .map(FinancialActivityModel.fromMap)
        .toList();

    _transactions.add(transactions);
    _debts.add(debts);
    _savingsGoals.add(savingsGoals);
    _financialActivities.add(financialActivities);
  }

  @override
  Future<void> addTransaction(TransactionModel transaction) async {
    await _database.insertTransaction(transaction);
    await refresh();
  }

  @override
  Future<void> updateTransaction(TransactionModel transaction) async {
    await _database.updateTransaction(transaction);
    await refresh();
  }

  @override
  Future<void> deleteTransaction(int id) async {
    await _database.deleteTransaction(id);
    await refresh();
  }

  @override
  Future<void> addDebt(
    DebtModel debt, {
    TransactionModel? openingTransaction,
  }) async {
    await _database.insertDebt(
      debt.toMap(),
      openingTransaction: openingTransaction?.toMap(),
    );
    await refresh();
  }

  @override
  Future<bool> repayDebt(int id, DateTime paidAt) async {
    final updated = await _database.repayDebt(id, paidAt);
    if (updated) await refresh();
    return updated;
  }

  @override
  Future<void> addSavingsGoal(SavingsGoalModel goal) async {
    await _database.insertSavingsGoal(goal.toMap());
    await refresh();
  }

  @override
  Future<void> recordSavingsDeposit(
    int goalId,
    double amount,
    DateTime date,
  ) async {
    await _database.recordSavingsDeposit(goalId, amount, date);
    await refresh();
  }

  @override
  Future<void> recordSavingsUse(
    int goalId,
    double amount,
    String category,
    DateTime date,
  ) async {
    await _database.recordSavingsUse(goalId, amount, category, date);
    await refresh();
  }

  @override
  Future<void> clearDebts() async {
    await _database.clearDebts();
    await refresh();
  }

  @override
  void dispose() {
    unawaited(_transactions.close());
    unawaited(_debts.close());
    unawaited(_savingsGoals.close());
    unawaited(_financialActivities.close());
  }
}
