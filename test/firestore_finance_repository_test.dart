import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitie/repositories/firestore_finance_repository.dart';
import 'package:pitie/models/debt_model.dart';
import 'package:pitie/models/savings_goal_model.dart';
import 'package:pitie/models/transaction_model.dart';

void main() {
  test(
    'clearDebts only removes transactions linked to existing debts',
    () async {
      final firestore = FakeFirebaseFirestore();
      final user = firestore.collection('users').doc('user-1');
      final debts = user.collection('debts');
      final transactions = user.collection('transactions');
      final activities = user.collection('financial_activities');

      await debts.doc('debt-1').set({});
      await transactions.doc('ordinary').set({'debtId': null});
      await transactions.doc('linked').set({'debtId': 'debt-1'});
      await transactions.doc('orphaned').set({'debtId': 'deleted-debt'});
      await activities.doc('repayment').set({'kind': 'debt_repayment'});
      await activities.doc('savings').set({'kind': 'savings_deposit'});

      final repository = FirestoreFinanceRepository(firestore, uid: 'user-1');
      await repository.clearDebts();

      final remainingTransactions = await transactions.get();
      final remainingActivities = await activities.get();
      final remainingDebts = await debts.get();

      expect(
        remainingTransactions.docs.map((document) => document.id),
        containsAll(['ordinary', 'orphaned']),
      );
      expect(remainingTransactions.docs, hasLength(2));
      expect(remainingActivities.docs.map((document) => document.id), [
        'savings',
      ]);
      expect(remainingDebts.docs, isEmpty);
    },
  );

  test('clearDebts handles more than one debt-ID query chunk', () async {
    final firestore = FakeFirebaseFirestore();
    final user = firestore.collection('users').doc('user-1');
    final debts = user.collection('debts');
    final transactions = user.collection('transactions');

    for (var index = 0; index < 31; index++) {
      final debtId = 'debt-$index';
      await debts.doc(debtId).set({});
      await transactions.doc('transaction-$index').set({'debtId': debtId});
    }
    await transactions.doc('ordinary').set({'debtId': null});

    final repository = FirestoreFinanceRepository(firestore, uid: 'user-1');
    await repository.clearDebts();

    expect((await debts.get()).docs, isEmpty);
    final remainingTransactions = await transactions.get();
    expect(remainingTransactions.docs, hasLength(1));
    expect(remainingTransactions.docs.single.id, 'ordinary');
  });

  test(
    'editing a paid debt updates its opening and repayment transactions',
    () async {
      final firestore = FakeFirebaseFirestore();
      final user = firestore.collection('users').doc('user-1');
      final repository = FirestoreFinanceRepository(firestore, uid: 'user-1');
      final loan = DebtModel(
        amount: 100,
        recipient: 'Bank',
        category: 'Pribadi',
        date: DateTime(2026, 1, 1),
        note: '',
        isPaid: false,
        type: DebtType.loan,
      );
      await repository.addDebt(
        loan,
        openingTransaction: TransactionModel(
          type: TransactionType.income,
          amount: loan.amount,
          category: 'Pinjaman',
          description: 'Pinjaman: ${loan.recipient}',
          date: loan.date,
        ),
      );
      final debtSnapshot = (await user.collection('debts').get()).docs.single;
      final debt = DebtModel.fromFirestore(debtSnapshot);
      await repository.repayDebt(debt, DateTime(2026, 2, 1));

      await repository.updateDebt(
        DebtModel(
          id: debt.id,
          amount: 125,
          recipient: 'Bank Baru',
          category: debt.category,
          date: debt.date,
          note: 'Dikoreksi',
          isPaid: true,
          paidAt: DateTime(2026, 2, 1),
          type: DebtType.receivable,
        ),
      );

      final transactions =
          (await user
                  .collection('transactions')
                  .where('debtId', isEqualTo: debt.id)
                  .get())
              .docs;
      expect(transactions, hasLength(2));
      final opening = transactions.singleWhere(
        (document) => document.data()['category'] == 'Piutang',
      );
      final repayment = transactions.singleWhere(
        (document) => document.data()['category'] == 'Pelunasan piutang',
      );
      expect(opening.data()['type'], 'expense');
      expect(opening.data()['amount'], 125);
      expect(opening.data()['description'], 'Piutang: Bank Baru');
      expect(repayment.data()['type'], 'income');
      expect(repayment.data()['amount'], 125);
      expect(repayment.data()['description'], 'Pelunasan piutang: Bank Baru');

      final activities =
          (await user
                  .collection('financial_activities')
                  .where('kind', isEqualTo: 'debt_repayment')
                  .get())
              .docs;
      expect(activities, hasLength(1));
      expect(activities.single.data()['amount'], 125);
      expect(activities.single.data()['title'], 'Bank Baru');
    },
  );

  test(
    'deleting a debt removes its linked transactions and repayment activity',
    () async {
      final firestore = FakeFirebaseFirestore();
      final user = firestore.collection('users').doc('user-1');
      final repository = FirestoreFinanceRepository(firestore, uid: 'user-1');
      final loan = DebtModel(
        amount: 100,
        recipient: 'Bank',
        category: 'Pribadi',
        date: DateTime(2026, 1, 1),
        note: '',
        isPaid: false,
        type: DebtType.loan,
      );
      await repository.addDebt(
        loan,
        openingTransaction: TransactionModel(
          type: TransactionType.income,
          amount: loan.amount,
          category: 'Pinjaman',
          description: 'Pinjaman: ${loan.recipient}',
          date: loan.date,
        ),
      );
      final debt = DebtModel.fromFirestore(
        (await user.collection('debts').get()).docs.single,
      );
      await repository.repayDebt(debt, DateTime(2026, 2, 1));
      await repository.deleteDebt(debt);

      expect((await user.collection('debts').get()).docs, isEmpty);
      expect((await user.collection('transactions').get()).docs, isEmpty);
      expect(
        (await user.collection('financial_activities').get()).docs,
        isEmpty,
      );
    },
  );

  test(
    'editing and deleting savings activities keeps goal totals synchronized',
    () async {
      final firestore = FakeFirebaseFirestore();
      final user = firestore.collection('users').doc('user-1');
      final repository = FirestoreFinanceRepository(firestore, uid: 'user-1');
      await repository.addSavingsGoal(
        SavingsGoalModel(
          name: 'Dana darurat',
          targetAmount: 500,
          savedAmount: 0,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      final goal = SavingsGoalModel.fromFirestore(
        (await user.collection('savings_goals').get()).docs.single,
      );
      await repository.recordSavingsDeposit(goal, 100, DateTime(2026, 1, 2));
      await repository.recordSavingsUse(
        goal,
        20,
        'Belanja',
        DateTime(2026, 1, 3),
      );

      final linkedTransactions =
          (await user
                  .collection('transactions')
                  .where('savingsGoalId', isEqualTo: goal.id)
                  .get())
              .docs;
      final deposit = TransactionModel.fromFirestore(
        linkedTransactions.singleWhere(
          (document) => document.data()['account'] == 'main',
        ),
      );
      final use = TransactionModel.fromFirestore(
        linkedTransactions.singleWhere(
          (document) => document.data()['account'] == 'savings',
        ),
      );
      await repository.updateSavingsActivity(
        TransactionModel(
          id: deposit.id,
          type: deposit.type,
          amount: 120,
          category: deposit.category,
          description: deposit.description,
          date: DateTime(2026, 1, 2),
          createdAt: deposit.createdAt,
          account: deposit.account,
          savingsGoalId: goal.id,
          financialActivityId: deposit.financialActivityId,
        ),
      );
      await repository.updateSavingsActivity(
        TransactionModel(
          id: use.id,
          type: use.type,
          amount: 25,
          category: 'Transportasi',
          description: use.description,
          date: DateTime(2026, 1, 4),
          createdAt: use.createdAt,
          account: use.account,
          savingsGoalId: goal.id,
          financialActivityId: use.financialActivityId,
        ),
      );

      final savedAfterEdit =
          (await user.collection('savings_goals').doc(goal.id).get())
              .data()!['savedAmount'];
      expect(savedAfterEdit, 95);
      final updatedActivity =
          (await user
                  .collection('financial_activities')
                  .doc(use.financialActivityId)
                  .get())
              .data()!;
      expect(updatedActivity['amount'], 25);
      expect(updatedActivity['title'], 'Transportasi');
      final updatedDeposit =
          (await user
                  .collection('financial_activities')
                  .doc(deposit.financialActivityId)
                  .get())
              .data()!;
      expect(updatedDeposit['amount'], 120);

      await expectLater(
        repository.deleteSavingsActivity(deposit),
        throwsA(isA<StateError>()),
      );
      await repository.deleteSavingsActivity(use);
      final savedAfterDelete =
          (await user.collection('savings_goals').doc(goal.id).get())
              .data()!['savedAmount'];
      expect(savedAfterDelete, 120);
      await repository.deleteSavingsActivity(deposit);
      final savedAfterDeletingDeposit =
          (await user.collection('savings_goals').doc(goal.id).get())
              .data()!['savedAmount'];
      expect(savedAfterDeletingDeposit, 0);
      expect(
        (await user
                .collection('transactions')
                .where('savingsGoalId', isEqualTo: goal.id)
                .get())
            .docs,
        isEmpty,
      );
      expect(
        (await user.collection('financial_activities').get()).docs,
        isEmpty,
      );
    },
  );

  test(
    'deleting a savings goal returns its remaining amount to main account',
    () async {
      final firestore = FakeFirebaseFirestore();
      final user = firestore.collection('users').doc('user-1');
      final repository = FirestoreFinanceRepository(firestore, uid: 'user-1');
      await repository.addSavingsGoal(
        SavingsGoalModel(
          name: 'Dana darurat',
          targetAmount: 500,
          savedAmount: 0,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      final goal = SavingsGoalModel.fromFirestore(
        (await user.collection('savings_goals').get()).docs.single,
      );
      await repository.recordSavingsDeposit(goal, 100, DateTime(2026, 1, 2));
      final updatedGoal = SavingsGoalModel.fromFirestore(
        await user.collection('savings_goals').doc(goal.id).get(),
      );

      await repository.deleteSavingsGoal(updatedGoal);

      expect((await user.collection('savings_goals').get()).docs, isEmpty);
      final transactions = (await user.collection('transactions').get()).docs;
      expect(transactions, hasLength(2));
      expect(
        transactions
            .singleWhere(
              (document) =>
                  document.data()['description'] ==
                  'Pengembalian tabungan: Dana darurat',
            )
            .data()['amount'],
        100,
      );
    },
  );
}
