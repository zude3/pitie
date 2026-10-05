import 'package:flutter/material.dart';

import '../data/transaction_store.dart';
import '../models/debt_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';
import '../widgets/balance_card.dart';
import 'add_transaction_screen.dart';
import 'debt_screen.dart';
import 'report_screen.dart';
import 'savings_screen.dart';
import 'transaction_detail_screen.dart';
import 'transaction_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardContent(
        onNavigate: (index) => setState(() => selectedIndex = index),
      ),
      const TransactionScreen(),
      const DebtScreen(),
      const SavingsScreen(),
      const ReportScreen(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: pages[selectedIndex]),
      floatingActionButton:
          selectedIndex == 0 || selectedIndex == 2 || selectedIndex == 3
          ? FloatingActionButton(
              onPressed: () {
                final page = switch (selectedIndex) {
                  0 => const AddTransactionScreen(),
                  2 => const AddDebtScreen(),
                  _ => const AddSavingsGoalScreen(),
                };
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => page),
                );
              },
              backgroundColor: const Color(0xFF5B48F5),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 8, fontWeight: FontWeight.w500),
        ),
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Hutang',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Tabungan',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  bool _showBalance = true;

  @override
  Widget build(BuildContext context) {
    final store = PitieScope.of(context);
    final activities = <_HomeActivity>[
      ...store.recentTransactions.map(
        (transaction) => _HomeActivity(
          date: transaction.date,
          amount: transaction.amount,
          title: transaction.description,
          subtitle:
              '${transaction.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran'} · ${_formatHomeDate(transaction.date)}',
          icon: transaction.icon,
          isCredit: transaction.type == TransactionType.income,
          color: transaction.type == TransactionType.income
              ? const Color(0xFF00A66A)
              : const Color(0xFFE36A4A),
          transaction: transaction,
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 92),
      children: [
        const Text(
          'Welcome Back,',
          style: TextStyle(color: Color(0xFF6E7488), fontSize: 10),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Text(
              'Zuhdi',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE1E4ED)),
              ),
              child: const Icon(
                Icons.notifications_none_outlined,
                color: Color(0xFF667085),
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BalanceCard(
          amount: store.balance,
          showAmount: _showBalance,
          onToggleVisibility: () =>
              setState(() => _showBalance = !_showBalance),
        ),
        _HomeSavingsBalance(
          amount: store.savingsBalance,
          visible: _showBalance,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Income',
                amount: store.income,
                color: const Color(0xFF00B879),
                icon: Icons.arrow_upward,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Expenses',
                amount: store.expenses,
                color: const Color(0xFFFF4B4B),
                icon: Icons.arrow_downward,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => widget.onNavigate(1),
              child: const Text('see all'),
            ),
          ],
        ),
        if (activities.isEmpty)
          const _HomeEmptyLine(text: 'Belum ada riwayat.'),
        ...activities
            .take(5)
            .map(
              (activity) => _HomeActivityItem(
                activity: activity,
                onTap: activity.transaction == null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransactionDetailScreen(
                            transaction: activity.transaction!,
                          ),
                        ),
                      ),
              ),
            ),
        const SizedBox(height: 12),
        _HomeSectionHeader(
          title: 'Catatan hutang',
          onTap: () => widget.onNavigate(2),
        ),
        if (store.debts.isEmpty)
          const _HomeEmptyLine(text: 'Belum ada catatan hutang.'),
        ...store.debts.take(3).map((debt) => _HomeDebtItem(debt: debt)),
        const SizedBox(height: 12),
        _HomeSectionHeader(
          title: 'Target tabungan',
          onTap: () => widget.onNavigate(3),
        ),
        if (store.savingsGoals.isEmpty)
          const _HomeEmptyLine(text: 'Belum ada target tabungan.'),
        ...store.savingsGoals
            .take(3)
            .map(
              (goal) => _HomeSavingsItem(
                goal: goal,
                onAdd: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddSavingsAmountScreen(goal: goal),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _HomeActivity {
  const _HomeActivity({
    required this.date,
    required this.amount,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCredit,
    required this.color,
    this.transaction,
  });

  final DateTime date;
  final double amount;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCredit;
  final Color color;
  final TransactionModel? transaction;
}

class _HomeActivityItem extends StatelessWidget {
  const _HomeActivityItem({required this.activity, this.onTap});
  final _HomeActivity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: activity.color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(activity.icon, color: activity.color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  activity.subtitle,
                  style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${activity.isCredit ? '+' : '-'}\$${activity.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: activity.color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
      TextButton(onPressed: onTap, child: const Text('see all')),
    ],
  );
}

class _HomeSavingsBalance extends StatelessWidget {
  const _HomeSavingsBalance({required this.amount, required this.visible});
  final double amount;
  final bool visible;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
    child: Row(
      children: [
        const Icon(Icons.savings_outlined, color: Color(0xFF00A66A), size: 15),
        const SizedBox(width: 6),
        const Text(
          'Saldo tabungan',
          style: TextStyle(color: Color(0xFF6E7488), fontSize: 10),
        ),
        const Spacer(),
        Text(
          visible ? '\$${amount.toStringAsFixed(2)}' : '\$ -',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _HomeDebtItem extends StatelessWidget {
  const _HomeDebtItem({required this.debt});
  final DebtModel debt;

  @override
  Widget build(BuildContext context) {
    final statusColor = debt.isPaid
        ? const Color(0xFF00A66A)
        : debt.isOverdue
        ? const Color(0xFFE36A4A)
        : const Color(0xFFE29A18);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: Color(0xFFE36A4A),
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debt.recipient,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  debt.status,
                  style: TextStyle(color: statusColor, fontSize: 9),
                ),
              ],
            ),
          ),
          Text(
            '\$${debt.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _HomeSavingsItem extends StatelessWidget {
  const _HomeSavingsItem({required this.goal, required this.onAdd});
  final SavingsGoalModel goal;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final progress = goal.targetAmount == 0
        ? 0.0
        : (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const Icon(
            Icons.savings_outlined,
            color: Color(0xFF00A66A),
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0xFF00B879),
                  backgroundColor: const Color(0xFFE9F1ED),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${goal.savedAmount.toStringAsFixed(0)} / \$${goal.targetAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: onAdd,
                tooltip: 'Tambah tabungan ke ${goal.name}',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF00A66A),
                  size: 17,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeEmptyLine extends StatelessWidget {
  const _HomeEmptyLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 10),
    ),
  );
}

String _formatHomeDate(DateTime date) =>
    '${date.day}/${date.month}/${date.year}';

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFE7E8F0)),
    ),
    child: Row(
      children: [
        Container(
          width: 23,
          height: 23,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 13),
        ),
        const SizedBox(width: 9),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9)),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
