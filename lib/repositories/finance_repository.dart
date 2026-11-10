import '../models/debt_model.dart';
import '../models/financial_activity_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';

abstract class FinanceRepository {
  Stream<List<TransactionModel>> watchTransactions();
  Stream<List<DebtModel>> watchDebts();
  Stream<List<SavingsGoalModel>> watchSavingsGoals();
  Stream<List<FinancialActivityModel>> watchFinancialActivities();

  Future<void> initialize();
  Future<void> refresh();
  Future<void> addTransaction(TransactionModel transaction);
  Future<void> updateTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(String id);
  Future<void> addDebt(DebtModel debt, {TransactionModel? openingTransaction});
  Future<void> updateDebt(DebtModel debt);
  Future<void> deleteDebt(DebtModel debt);
  Future<bool> repayDebt(DebtModel debt, DateTime paidAt);
  Future<void> addSavingsGoal(SavingsGoalModel goal);
  Future<void> updateSavingsGoal(SavingsGoalModel goal);
  Future<void> deleteSavingsGoal(SavingsGoalModel goal);
  Future<void> recordSavingsDeposit(
    SavingsGoalModel goal,
    double amount,
    DateTime date,
  );
  Future<void> recordSavingsUse(
    SavingsGoalModel goal,
    double amount,
    String category,
    DateTime date,
  );
  Future<void> updateSavingsActivity(TransactionModel transaction);
  Future<void> deleteSavingsActivity(TransactionModel transaction);
  Future<void> clearDebts();
  void dispose();
}
