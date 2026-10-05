import 'package:flutter/material.dart';

import '../data/transaction_store.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) => const TransactionFormScreen();
}

class EditTransactionScreen extends StatelessWidget {
  const EditTransactionScreen({required this.transaction, super.key});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) =>
      TransactionFormScreen(transaction: transaction);
}

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({this.transaction, super.key});
  final TransactionModel? transaction;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  TransactionType? type;
  String? category;
  late DateTime date;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    type = transaction?.type ?? TransactionType.expense;
    category = transaction?.category;
    date = transaction?.date ?? DateTime.now();
    amountController.text = transaction?.amount.toStringAsFixed(2) ?? '';
    descriptionController.text = transaction?.description ?? '';
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
    final validationMessage = amount == null || !amount.isFinite
        ? 'Masukkan jumlah yang valid.'
        : amount <= 0
        ? 'Jumlah harus lebih besar dari 0.'
        : type == null
        ? 'Pilih income atau expense.'
        : category == null
        ? 'Pilih kategori transaksi.'
        : date.isBefore(DateTime(2020))
        ? 'Pilih tanggal yang valid.'
        : null;
    if (validationMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }
    final transaction = TransactionModel(
      id: widget.transaction?.id,
      type: type!,
      amount: amount!,
      category: category!,
      description: descriptionController.text.trim().isEmpty
          ? category!
          : descriptionController.text.trim(),
      date: date,
      createdAt: widget.transaction?.createdAt,
    );
    final store = PitieScope.of(context);
    try {
      if (widget.transaction == null) {
        await store.add(transaction);
      } else {
        await store.update(transaction);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil disimpan.')),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi gagal disimpan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = transactionCategories.where((item) {
      if (type == null) return false;
      return type == TransactionType.income
          ? ['Gaji', 'Freelance', 'Bonus'].contains(item.name)
          : !['Gaji', 'Freelance', 'Bonus'].contains(item.name);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction == null ? 'Add Transaction' : 'Edit Transaction',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          SegmentedButton<TransactionType>(
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(
                value: TransactionType.income,
                label: Text('Income'),
              ),
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('Expense'),
              ),
            ],
            selected: type == null ? <TransactionType>{} : {type!},
            onSelectionChanged: (value) => setState(() {
              type = value.isEmpty ? null : value.first;
              category = null;
            }),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: categories.any((item) => item.name == category)
                ? category
                : null,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: categories
                .map(
                  (item) => DropdownMenuItem(
                    value: item.name,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => category = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: date,
              );
              if (picked != null) setState(() => date = picked);
            },
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text('Date: ${date.day}/${date.month}/${date.year}'),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: save, child: const Text('Save Transaction')),
        ],
      ),
    );
  }
}
