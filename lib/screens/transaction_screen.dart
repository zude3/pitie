import 'package:flutter/material.dart';

import '../data/transaction_store.dart';
import '../widgets/transaction_item.dart';
import 'transaction_detail_screen.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PitieScope.of(context);
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
            '${store.transactions.length} recorded transactions',
            style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 11),
          ),
          const SizedBox(height: 22),
          ...store.transactions.map(
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
