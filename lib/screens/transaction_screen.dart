import 'package:flutter/material.dart';

import '../data/transaction_store.dart';
import '../widgets/transaction_item.dart';
import 'transaction_detail_screen.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = PitieScope.of(context);
    final query = _query.trim().toLowerCase();
    final transactions = store.transactions.where((transaction) {
      if (query.isEmpty) return true;
      return transaction.description.toLowerCase().contains(query) ||
          transaction.category.toLowerCase().contains(query) ||
          transaction.amount.toString().contains(query);
    }).toList();
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
        children: [
          const Text(
            'Transactions',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${transactions.length} recorded transactions',
            style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 11),
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cari transaksi',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Text(
                  'Transaksi tidak ditemukan.',
                  style: TextStyle(color: Color(0xFF8B91A4), fontSize: 11),
                ),
              ),
            ),
          ...transactions.map(
            (transaction) => TransactionItem.fromModel(
              transaction,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TransactionDetailScreen(transaction: transaction),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
