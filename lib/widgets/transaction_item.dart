import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';

const _ink = Color(0xFF111631);
const _muted = Color(0xFF9BA0B2);
const _income = Color(0xFF00B879);
const _expense = Color(0xFFFF4B4B);

const _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// 1234.5 -> "1,234.50"
String formatMoney(double value) {
  final parts = value.abs().toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '$whole.${parts[1]}';
}

/// "Sep 20, 2025"
String formatShortDate(DateTime d) =>
    '${_monthsShort[d.month - 1]} ${d.day}, ${d.year}';

/// "4:10 PM"
String formatTime(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today" / "Yesterday" / "Sep 20, 2025"
String dayLabel(DateTime d, {DateTime? now}) {
  final today = now ?? DateTime.now();
  if (isSameDay(d, today)) return 'Today';
  if (isSameDay(d, today.subtract(const Duration(days: 1)))) return 'Yesterday';
  return formatShortDate(d);
}

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
  }) {
    // `date` hanya berisi tanggal; jam diambil dari createdAt.
    final time = transaction.createdAt ?? transaction.date;
    return TransactionItem(
      title: transaction.description,
      subtitle: '${dayLabel(transaction.date)}, ${formatTime(time)}',
      amount: formatMoney(transaction.amount),
      icon: transaction.icon,
      iconColor: categoryFor(transaction.category).color,
      isIncome: transaction.type == TransactionType.income,
      onTap: onTap,
    );
  }

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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${isIncome ? '+' : '-'}\$$amount',
              style: TextStyle(
                color: isIncome ? _income : _expense,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
