import 'package:flutter/material.dart';

import '../data/transaction_store.dart';
import '../models/transaction_model.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({required this.transaction, super.key});
  final TransactionModel transaction;

  Future<void> delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This transaction will be removed from your records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted && transaction.id != null) {
      try {
        await PitieScope.of(context).remove(transaction.id!);
        if (context.mounted) Navigator.pop(context);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi gagal dihapus.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PitieScope.of(context);
    final current = store.transactions.firstWhere(
      (item) => item.id == transaction.id,
      orElse: () => transaction,
    );
    final isIncome = current.type == TransactionType.income;
    final isLinked = current.debtId != null || current.savingsGoalId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Detail')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isIncome
                  ? const Color(0xFFE9FAF3)
                  : const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  current.icon,
                  size: 30,
                  color: isIncome
                      ? const Color(0xFF00B879)
                      : const Color(0xFFFF4B4B),
                ),
                const SizedBox(height: 10),
                Text(
                  isIncome ? 'Income' : 'Expense',
                  style: const TextStyle(
                    color: Color(0xFF6E7488),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isIncome ? '+' : '-'}\$${current.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: isIncome
                        ? const Color(0xFF00B879)
                        : const Color(0xFFFF4B4B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _DetailRow(label: 'Category', value: current.category),
          _DetailRow(label: 'Description', value: current.description),
          _DetailRow(
            label: 'Date',
            value:
                '${current.date.day}/${current.date.month}/${current.date.year}',
          ),
          const SizedBox(height: 24),
          if (isLinked)
            const Text(
              'Aktivitas ini dikelola dari catatan hutang atau target tabungan.',
              style: TextStyle(color: Color(0xFF8B91A4), fontSize: 11),
              textAlign: TextAlign.center,
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditTransactionScreen(transaction: current),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => delete(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
