import 'package:flutter/material.dart';

import '../data/transaction_store.dart';
import '../models/transaction_model.dart';
import '../widgets/weekly_expense_chart.dart';

enum _ReportPeriod { all, today, thisWeek, thisMonth, custom }

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  _ReportPeriod period = _ReportPeriod.all;
  DateTime? customStart;
  DateTime? customEnd;
  late DateTime weekStart;

  @override
  void initState() {
    super.initState();
    weekStart = _startOfWeek(DateTime.now());
  }

  Future<void> selectWeek() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: weekStart,
    );
    if (picked != null && mounted) {
      setState(() => weekStart = _startOfWeek(picked));
    }
  }

  Future<void> selectCustomPeriod() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: customStart != null && customEnd != null
          ? DateTimeRange(start: customStart!, end: customEnd!)
          : DateTimeRange(start: now, end: now),
    );
    if (picked != null && mounted) {
      setState(() {
        customStart = _dayStart(picked.start);
        customEnd = _dayStart(picked.end);
      });
    }
  }

  DateTimeRange? get selectedRange {
    final now = DateTime.now();
    final today = _dayStart(now);
    return switch (period) {
      _ReportPeriod.all => null,
      _ReportPeriod.today => DateTimeRange(
        start: today,
        end: today.add(const Duration(days: 1)),
      ),
      _ReportPeriod.thisWeek => DateTimeRange(
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today
            .subtract(Duration(days: today.weekday - 1))
            .add(const Duration(days: 7)),
      ),
      _ReportPeriod.thisMonth => DateTimeRange(
        start: DateTime(now.year, now.month),
        end: DateTime(now.year, now.month + 1),
      ),
      _ReportPeriod.custom when customStart != null && customEnd != null =>
        DateTimeRange(
          start: customStart!,
          end: customEnd!.add(const Duration(days: 1)),
        ),
      _ReportPeriod.custom => null,
    };
  }

  static DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _startOfWeek(DateTime date) {
    final day = _dayStart(date);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static int _weekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 4);
    return 1 + thursday.difference(_startOfWeek(firstThursday)).inDays ~/ 7;
  }

  String _weekLabel() {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return 'Week ${_weekNumber(weekStart)} • '
        '${weekStart.day}/${weekStart.month} - '
        '${weekEnd.day}/${weekEnd.month}/${weekEnd.year}';
  }

  @override
  Widget build(BuildContext context) {
    final store = PitieScope.of(context);
    final range = selectedRange;
    final transactions = range == null
        ? store.transactions
        : store.transactions
              .where(
                (transaction) =>
                    !transaction.date.isBefore(range.start) &&
                    transaction.date.isBefore(range.end),
              )
              .toList();
    final expenses = transactions
        .where((item) => item.type == TransactionType.expense)
        .toList();
    final income = transactions
        .where((item) => item.type == TransactionType.income)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final expenseTotal = expenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final weeklyExpenses = List<double>.generate(7, (index) {
      final day = weekStart.add(Duration(days: index));
      final nextDay = day.add(const Duration(days: 1));
      return store.transactions
          .where(
            (transaction) =>
                transaction.type == TransactionType.expense &&
                !transaction.date.isBefore(day) &&
                transaction.date.isBefore(nextDay),
          )
          .fold<double>(0, (sum, item) => sum + item.amount);
    });
    final weeklyTotal = weeklyExpenses.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );
    final categories = <String, double>{};
    for (final transaction in expenses) {
      categories.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
      children: [
        const Text(
          'Reports',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your financial overview',
          style: TextStyle(color: Color(0xFF8B91A4), fontSize: 11),
        ),
        const SizedBox(height: 22),
        DropdownButtonFormField<_ReportPeriod>(
          initialValue: period,
          decoration: const InputDecoration(
            labelText: 'Period',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: _ReportPeriod.all, child: Text('All')),
            DropdownMenuItem(value: _ReportPeriod.today, child: Text('Today')),
            DropdownMenuItem(
              value: _ReportPeriod.thisWeek,
              child: Text('This Week'),
            ),
            DropdownMenuItem(
              value: _ReportPeriod.thisMonth,
              child: Text('This Month'),
            ),
            DropdownMenuItem(
              value: _ReportPeriod.custom,
              child: Text('Custom'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            if (value == _ReportPeriod.custom) {
              setState(() => period = value);
              selectCustomPeriod();
            } else {
              setState(() => period = value);
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Income',
                value: income,
                color: const Color(0xFF00B879),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Metric(
                label: 'Expense',
                value: expenseTotal,
                color: const Color(0xFFFF4B4B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Metric(
          label: 'Balance',
          value: income - expenseTotal,
          color: const Color(0xFF5265F5),
        ),
        const SizedBox(height: 12),
        _Metric(
          label: 'Transactions',
          value: transactions.length.toDouble(),
          color: const Color(0xFFF59E0B),
          isCurrency: false,
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Weekly expenses',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: selectWeek,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              tooltip: 'Choose week',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        Text(
          _weekLabel(),
          style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 11),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$${weeklyTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFFF4B4B),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              WeeklyExpenseChart(values: weeklyExpenses),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Expenses by category',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ...categories.entries.map(
          (entry) => _CategoryBar(
            label: entry.key,
            amount: entry.value,
            total: expenseTotal,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
    this.isCurrency = true,
  });
  final String label;
  final double value;
  final Color color;
  final bool isCurrency;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE7E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 10),
        ),
        const SizedBox(height: 5),
        Text(
          isCurrency
              ? '\$${value.toStringAsFixed(2)}'
              : value.toInt().toString(),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.label,
    required this.amount,
    required this.total,
  });
  final String label;
  final double amount;
  final double total;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: total == 0 ? 0 : amount / total,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF5B48F5),
          backgroundColor: const Color(0xFFE9EAF4),
        ),
      ],
    ),
  );
}
