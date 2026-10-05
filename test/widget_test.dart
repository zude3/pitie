// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:pitie/data/transaction_store.dart';
import 'package:pitie/models/debt_model.dart';
import 'package:pitie/models/savings_goal_model.dart';
import 'package:pitie/models/transaction_model.dart';
import 'package:pitie/main.dart';

void main() {
  testWidgets('renders the Pitie dashboard', (WidgetTester tester) async {
    final store = TransactionStore();
    await tester.pumpWidget(PitieApp(store: store));

    expect(find.text('Good Morning,'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);

    await tester.tap(find.text('Hutang'));
    await tester.pumpAndSettle();
    expect(find.text('Daftar hutang'), findsOneWidget);

    await tester.tap(find.text('Tabungan'));
    await tester.pumpAndSettle();
    expect(find.text('Target tabungan'), findsOneWidget);
  });

  test('balances are calculated independently from account transactions', () {
    final store = TransactionStore()
      ..transactions = [
        TransactionModel(
          type: TransactionType.income,
          amount: 100,
          category: 'Gaji',
          description: 'Gaji',
          date: DateTime(2026, 10, 4),
        ),
        TransactionModel(
          type: TransactionType.expense,
          amount: 5,
          category: 'Tabungan',
          description: 'Setoran tabungan: Mobil',
          date: DateTime(2026, 10, 4),
        ),
        TransactionModel(
          type: TransactionType.expense,
          amount: 2,
          category: 'Penggunaan tabungan',
          description: 'Keperluan',
          date: DateTime(2026, 10, 4),
          account: TransactionAccount.savings,
        ),
        TransactionModel(
          type: TransactionType.expense,
          amount: 20,
          category: 'Belanja',
          description: 'Belanja',
          date: DateTime(2026, 10, 4),
        ),
      ]
      ..debts = [
        DebtModel(
          amount: 10,
          recipient: 'Penerima',
          category: 'Pribadi',
          date: DateTime(2026, 10, 4),
          note: '',
          isPaid: false,
        ),
      ]
      ..savingsGoals = [
        SavingsGoalModel(
          name: 'Mobil',
          targetAmount: 50,
          savedAmount: 3,
          createdAt: DateTime(2026, 10, 4),
        ),
      ];

    expect(store.balance, 75);
    expect(store.savingsBalance, 3);
  });

  test('debt status reflects repayment and optional due date', () {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final overdue = _debt(dueDate: yesterday);
    final upcoming = _debt(dueDate: tomorrow);
    final noDeadline = _debt();
    final paid = _debt(dueDate: yesterday, isPaid: true);

    expect(overdue.status, 'Lewat batas waktu');
    expect(upcoming.status, 'Belum lunas');
    expect(noDeadline.status, 'Belum lunas');
    expect(paid.status, 'Lunas');
  });

  testWidgets('home hides balance and shows latest five mixed activities', (
    tester,
  ) async {
    final store = TransactionStore()
      ..transactions = List.generate(
        6,
        (index) => TransactionModel(
          type: TransactionType.income,
          amount: index + 1,
          category: 'Gaji',
          description: 'Aktivitas ${index + 1}',
          date: DateTime(2026, 10, index + 1),
        ),
      )
      ..transactions.addAll([
        TransactionModel(
          type: TransactionType.expense,
          amount: 7,
          category: 'Tabungan',
          description: 'Setoran tabungan: Mobil',
          date: DateTime(2026, 10, 7),
        ),
        TransactionModel(
          type: TransactionType.expense,
          amount: 5,
          category: 'Pelunasan hutang',
          description: 'Pelunasan hutang: Budi',
          date: DateTime(2026, 10, 5),
        ),
      ]);
    await tester.pumpWidget(PitieApp(store: store));

    expect(find.text('Setoran tabungan: Mobil'), findsOneWidget);
    expect(find.text('Pelunasan hutang: Budi'), findsOneWidget);
    expect(store.recentTransactions, hasLength(5));
    expect(
      store.recentTransactions.first.description,
      'Setoran tabungan: Mobil',
    );
    expect(
      store.recentTransactions.any((item) => item.description == 'Aktivitas 2'),
      isFalse,
    );

    await tester.tap(find.byTooltip('Sembunyikan saldo'));
    await tester.pump();
    expect(find.text('\$******'), findsNWidgets(2));
    expect(find.byTooltip('Tampilkan saldo'), findsOneWidget);
  });
}

DebtModel _debt({DateTime? dueDate, bool isPaid = false}) => DebtModel(
  amount: 10,
  recipient: 'Penerima',
  category: 'Pribadi',
  date: DateTime(2026, 10, 1),
  note: '',
  isPaid: isPaid,
  dueDate: dueDate,
);
