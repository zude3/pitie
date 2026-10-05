// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
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

    expect(find.text('Welcome Back,'), findsOneWidget);
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
    expect(find.text('\$ -'), findsNWidgets(2));
    expect(find.byTooltip('Tampilkan saldo'), findsOneWidget);
  });

  testWidgets('transactions can be searched and added from their tab', (
    tester,
  ) async {
    final store = TransactionStore()
      ..transactions = [
        _transaction('Tagihan listrik', 20),
        _transaction('Belanja mingguan', 30),
      ];
    await tester.pumpWidget(PitieApp(store: store));

    await tester.tap(find.text('Transaksi'));
    await tester.pumpAndSettle();
    expect(find.text('Tagihan listrik'), findsOneWidget);
    expect(find.text('Belanja mingguan'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'listrik');
    await tester.pumpAndSettle();
    expect(find.text('Tagihan listrik'), findsOneWidget);
    expect(find.text('Belanja mingguan'), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Save Transaction'), findsOneWidget);
  });

  testWidgets('debt list filters by type and supports search', (tester) async {
    final store = TransactionStore()
      ..debts = [
        _debt(recipient: 'Pinjaman Andi', type: DebtType.loan),
        _debt(recipient: 'Hutang Budi'),
      ];
    await tester.pumpWidget(PitieApp(store: store));

    await tester.tap(find.text('Hutang'));
    await tester.pumpAndSettle();
    expect(find.text('Pinjaman Andi'), findsOneWidget);
    expect(find.text('Hutang Budi'), findsOneWidget);

    await tester.tap(find.text('Semua jenis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pinjaman').last);
    await tester.pumpAndSettle();
    expect(find.text('Pinjaman Andi'), findsOneWidget);
    expect(find.text('Hutang Budi'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Andi');
    await tester.pumpAndSettle();
    expect(find.text('Pinjaman Andi'), findsOneWidget);
  });

  testWidgets('debt list filters by date period', (tester) async {
    final today = DateTime.now();
    final store = TransactionStore()
      ..debts = [
        _debt(recipient: 'Catatan hari ini', date: today),
        _debt(
          recipient: 'Catatan kemarin',
          date: today.subtract(const Duration(days: 1)),
        ),
      ];
    await tester.pumpWidget(PitieApp(store: store));

    await tester.tap(find.text('Hutang'));
    await tester.pumpAndSettle();
    expect(find.text('Catatan hari ini'), findsOneWidget);
    expect(find.text('Catatan kemarin'), findsOneWidget);

    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hari ini').last);
    await tester.pumpAndSettle();
    expect(find.text('Catatan hari ini'), findsOneWidget);
    expect(find.text('Catatan kemarin'), findsNothing);
  });

  testWidgets('back from a non-home tab first returns to Home', (tester) async {
    await tester.pumpWidget(PitieApp(store: TransactionStore()));
    await tester.tap(find.text('Transaksi'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back,'), findsOneWidget);
  });

  testWidgets('savings target detail shows only its linked transactions', (
    tester,
  ) async {
    final goal = SavingsGoalModel(
      id: 7,
      name: 'Mobil',
      targetAmount: 100,
      savedAmount: 25,
      createdAt: DateTime(2026, 10, 1),
    );
    final store = TransactionStore()
      ..savingsGoals = [goal]
      ..transactions = [
        TransactionModel(
          id: 1,
          type: TransactionType.expense,
          amount: 25,
          category: 'Tabungan',
          description: 'Setoran tabungan: Mobil',
          date: DateTime(2026, 10, 2),
          savingsGoalId: 7,
        ),
        TransactionModel(
          id: 2,
          type: TransactionType.expense,
          amount: 10,
          category: 'Tabungan',
          description: 'Setoran tabungan: Rumah',
          date: DateTime(2026, 10, 3),
          savingsGoalId: 8,
        ),
      ];
    await tester.pumpWidget(PitieApp(store: store));

    await tester.tap(find.text('Tabungan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mobil'));
    await tester.pumpAndSettle();
    expect(find.text('Riwayat aktivitas'), findsOneWidget);
    expect(find.text('Setoran tabungan'), findsOneWidget);
    expect(find.text('\$25.00'), findsNWidgets(2));
    expect(find.text('\$10.00'), findsNothing);
  });

  testWidgets('savings-account usage is excluded from report expenses', (
    tester,
  ) async {
    final store = TransactionStore()
      ..transactions = [
        _transaction('Belanja', 10),
        TransactionModel(
          type: TransactionType.expense,
          amount: 50,
          category: 'Makanan',
          description: 'Pemakaian tabungan: Makanan',
          date: DateTime.now(),
          account: TransactionAccount.savings,
        ),
      ];
    await tester.pumpWidget(PitieApp(store: store));

    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();
    expect(find.text('\$50.00'), findsNothing);
    expect(find.text('\$10.00'), findsWidgets);
  });
}

TransactionModel _transaction(String description, double amount) =>
    TransactionModel(
      type: TransactionType.expense,
      amount: amount,
      category: 'Belanja',
      description: description,
      date: DateTime.now(),
    );

DebtModel _debt({
  DateTime? dueDate,
  bool isPaid = false,
  String recipient = 'Penerima',
  DebtType type = DebtType.debt,
  DateTime? date,
}) => DebtModel(
  amount: 10,
  recipient: recipient,
  category: 'Pribadi',
  date: date ?? DateTime(2026, 10, 1),
  note: '',
  isPaid: isPaid,
  dueDate: dueDate,
  type: type,
);
