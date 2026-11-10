import 'package:flutter/material.dart';

import '../data/transaction_store.dart';
import '../models/transaction_model.dart';
import '../utils/currency_formatter.dart';

class SavingsActivityFormScreen extends StatefulWidget {
  const SavingsActivityFormScreen({required this.transaction, super.key});

  final TransactionModel transaction;

  @override
  State<SavingsActivityFormScreen> createState() =>
      _SavingsActivityFormScreenState();
}

class _SavingsActivityFormScreenState extends State<SavingsActivityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late DateTime _date;
  bool _saving = false;

  bool get _isDeposit => widget.transaction.account == TransactionAccount.main;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(0),
    );
    _categoryController = TextEditingController(
      text: widget.transaction.category,
    );
    _date = widget.transaction.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final category = _isDeposit ? 'Tabungan' : _categoryController.text.trim();
    final updated = TransactionModel(
      id: widget.transaction.id,
      type: TransactionType.expense,
      amount: double.parse(_amountController.text.trim()),
      category: category,
      description: widget.transaction.description,
      date: _date,
      createdAt: widget.transaction.createdAt,
      account: widget.transaction.account,
      debtId: widget.transaction.debtId,
      savingsGoalId: widget.transaction.savingsGoalId,
      financialActivityId: widget.transaction.financialActivityId,
    );
    try {
      await PitieScope.of(context).updateSavingsActivity(updated);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perubahan aktivitas tabungan gagal disimpan.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit aktivitas tabungan')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _isDeposit ? 'Setoran tabungan' : 'Pemakaian tabungan',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Nominal saat ini: ${formatRupiah(widget.transaction.amount)}',
            style: const TextStyle(color: Color(0xFF687183), fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final amount = double.tryParse(value?.trim() ?? '');
              return amount == null || !amount.isFinite || amount <= 0
                  ? 'Masukkan nominal yang valid'
                  : null;
            },
          ),
          if (!_isDeposit) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Kategori pemakaian',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Kategori wajib diisi'
                  : null,
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text('Tanggal: ${_date.day}/${_date.month}/${_date.year}'),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Menyimpan...' : 'Simpan perubahan'),
          ),
        ],
      ),
    ),
  );
}
