import 'package:flutter/material.dart';

import '../data/transaction_store.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../widgets/transaction_item.dart';
import 'transaction_detail_screen.dart';

const _primary = Color(0xFF5B48F5);
const _ink = Color(0xFF111631);
const _muted = Color(0xFF8B91A4);
const _border = Color(0xFFE3E6EF);

enum _TypeFilter { all, income, expense }

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  _TypeFilter _type = _TypeFilter.all;
  String? _category;
  DateTimeRange? _range;

  Future<void> _pickCategory() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Text(
                'Select Category',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.apps, color: _muted),
              title: const Text('All categories'),
              trailing: _category == null
                  ? const Icon(Icons.check, color: _primary)
                  : null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final item in transactionCategories)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: item.color,
                  child: Icon(item.icon, color: Colors.white, size: 18),
                ),
                title: Text(item.name),
                trailing: item.name == _category
                    ? const Icon(Icons.check, color: _primary)
                    : null,
                onTap: () => Navigator.pop(context, item.name),
              ),
          ],
        ),
      ),
    );
    if (result == null) return; // sheet ditutup tanpa memilih
    setState(() => _category = result.isEmpty ? null : result);
  }

  Future<void> _pickDate() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  String get _dateLabel {
    final range = _range;
    if (range == null) return 'Date';
    if (isSameDay(range.start, range.end)) return formatShortDate(range.start);
    return '${formatShortDate(range.start)} - ${formatShortDate(range.end)}';
  }

  bool _matches(TransactionModel t) {
    if (_type == _TypeFilter.income && t.type != TransactionType.income) {
      return false;
    }
    if (_type == _TypeFilter.expense && t.type != TransactionType.expense) {
      return false;
    }
    if (_category != null && t.category != _category) return false;
    final range = _range;
    if (range != null) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      if (day.isBefore(start) || day.isAfter(end)) return false;
    }
    return true;
  }

  /// Ubah daftar transaksi menjadi baris campuran: header tanggal (DateTime)
  /// dan item transaksi (TransactionModel), urut terbaru dulu.
  List<Object> _buildRows(List<TransactionModel> transactions) {
    final sorted = List<TransactionModel>.of(transactions)
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) return byDate;
        return (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date);
      });
    final rows = <Object>[];
    DateTime? currentDay;
    for (final t in sorted) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (currentDay == null || currentDay != day) {
        currentDay = day;
        rows.add(day);
      }
      rows.add(t);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final store = PitieScope.of(context);
    final rows = _buildRows(store.transactions.where(_matches).toList());

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text(
              'Transactions',
              style: TextStyle(
                color: _ink,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _type == _TypeFilter.all,
                  onTap: () => setState(() => _type = _TypeFilter.all),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: 'Income',
                  selected: _type == _TypeFilter.income,
                  onTap: () => setState(() => _type = _TypeFilter.income),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: 'Expense',
                  selected: _type == _TypeFilter.expense,
                  onTap: () => setState(() => _type = _TypeFilter.expense),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: _category ?? 'Category',
                  selected: _category != null,
                  onTap: _pickCategory,
                  onClear: _category == null
                      ? null
                      : () => setState(() => _category = null),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: _dateLabel,
                  selected: _range != null,
                  onTap: _pickDate,
                  onClear: _range == null
                      ? null
                      : () => setState(() => _range = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'Transaksi tidak ditemukan.',
                      style: TextStyle(color: _muted, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is DateTime) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 8 : 18,
                            bottom: 4,
                          ),
                          child: Text(
                            dayLabel(row),
                            style: const TextStyle(
                              color: Color(0xFF4B5266),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      final transaction = row as TransactionModel;
                      return TransactionItem.fromModel(
                        transaction,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TransactionDetailScreen(
                              transaction: transaction,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : const Color(0xFF3A4057);
    return Material(
      color: selected ? _primary : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? _primary : _border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close, size: 16, color: foreground),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}