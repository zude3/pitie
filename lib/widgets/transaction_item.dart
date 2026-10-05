import 'package:flutter/material.dart';

import '../models/transaction_model.dart';

class TransactionItem extends StatelessWidget {
  const TransactionItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.iconColor,
    required this.isIncome,
    this.onTap,
    super.key,
  });

  factory TransactionItem.fromModel(
    TransactionModel transaction, {
    VoidCallback? onTap,
  }) => TransactionItem(
    title: transaction.description,
    subtitle:
        '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
    amount: transaction.amount.toStringAsFixed(2),
    icon: transaction.icon,
    iconColor: const Color(0xFF80C88B),
    isIncome: transaction.type == TransactionType.income,
    onTap: onTap,
  );

  final String title;
  final String subtitle;
  final String amount;
  final IconData icon;
  final Color iconColor;
  final bool isIncome;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF9BA0B2),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'}$amount',
              style: TextStyle(
                color: isIncome
                    ? const Color(0xFF00B879)
                    : const Color(0xFFFF4B4B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
