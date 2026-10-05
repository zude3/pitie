import 'package:flutter/material.dart';

import '../data/transaction_store.dart';
import '../models/debt_model.dart';

class DebtScreen extends StatelessWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PitieScope.of(context);
    final unpaid = store.debts.where((debt) => !debt.isPaid).toList();
    final total = unpaid.fold<double>(0, (sum, debt) => sum + debt.amount);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
      children: [
        const Text(
          'Debt',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Catat dan pantau hutang yang belum lunas',
          style: TextStyle(color: Color(0xFF8B91A4), fontSize: 11),
        ),
        const SizedBox(height: 18),
        _DebtSummary(total: total, count: unpaid.length),
        const SizedBox(height: 22),
        const Text(
          'Daftar hutang',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (store.debts.isEmpty)
          const _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada catatan hutang',
            message: 'Tambahkan catatan pertama lewat tombol +.',
          )
        else
          ...store.debts.map(
            (debt) => _DebtItem(
              debt: debt,
              onRepay: () => _confirmRepayment(context, store, debt),
            ),
          ),
      ],
    );
  }
}

class AddDebtScreen extends StatefulWidget {
  const AddDebtScreen({super.key});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _recipientController = TextEditingController();
  final _noteController = TextEditingController();
  DebtType _type = DebtType.debt;
  DateTime _date = DateTime.now();
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool selectDueDate}) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: selectDueDate ? _date : DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: selectDueDate ? (_dueDate ?? _date) : _date,
    );
    if (selected != null && mounted) {
      setState(() {
        if (selectDueDate) {
          _dueDate = selected;
        } else {
          _date = selected;
          if (_dueDate != null && _dueDate!.isBefore(_date)) {
            _dueDate = null;
          }
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await PitieScope.of(context).addDebt(
        DebtModel(
          amount: double.parse(_amountController.text.trim()),
          recipient: _recipientController.text.trim(),
          category: 'Pribadi',
          date: _date,
          note: _noteController.text.trim(),
          isPaid: false,
          dueDate: _dueDate,
          type: _type,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catatan hutang gagal disimpan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tambah hutang')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final amount = double.tryParse(value?.trim() ?? '');
              return amount == null || amount <= 0
                  ? 'Masukkan nominal yang valid'
                  : null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _recipientController,
            decoration: const InputDecoration(
              labelText: 'Nama penerima',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nama penerima wajib diisi'
                : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<DebtType>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Jenis',
              border: OutlineInputBorder(),
            ),
            items: DebtType.values
                .map(
                  (type) =>
                      DropdownMenuItem(value: type, child: Text(type.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _selectDate(selectDueDate: false),
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text('Tanggal mulai: ${_formatDate(_date)}'),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(selectDueDate: true),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _dueDate == null
                        ? 'Tenggat waktu (opsional)'
                        : 'Tenggat: ${_formatDate(_dueDate!)}',
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              if (_dueDate != null)
                IconButton(
                  onPressed: () => setState(() => _dueDate = null),
                  tooltip: 'Hapus tenggat',
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Catatan',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Menyimpan...' : 'Simpan hutang'),
          ),
        ],
      ),
    ),
  );
}

class _DebtSummary extends StatelessWidget {
  const _DebtSummary({required this.total, required this.count});
  final double total;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1EC),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          color: Color(0xFFE36A4A),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Belum lunas', style: TextStyle(fontSize: 11)),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Text('$count catatan', style: const TextStyle(fontSize: 10)),
      ],
    ),
  );
}

class _DebtItem extends StatelessWidget {
  const _DebtItem({required this.debt, required this.onRepay});
  final DebtModel debt;
  final VoidCallback onRepay;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFE7E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                debt.recipient,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '\$${debt.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: debt.isPaid
                    ? const Color(0xFF8B91A4)
                    : const Color(0xFFE36A4A),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _DebtStatusLabel(debt: debt),
            Text(
              debt.type.label,
              style: const TextStyle(color: Color(0xFF687183), fontSize: 9),
            ),
            Text(
              'Mulai ${_formatDate(debt.date)}',
              style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 9),
            ),
            if (debt.dueDate != null)
              Text(
                'Tenggat ${_formatDate(debt.dueDate!)}',
                style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 9),
              ),
          ],
        ),
        if (debt.note.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            debt.note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF687183), fontSize: 10),
          ),
        ],
        if (!debt.isPaid) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRepay,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Lunasi'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),
        ],
      ],
    ),
  );
}

class _DebtStatusLabel extends StatelessWidget {
  const _DebtStatusLabel({required this.debt});
  final DebtModel debt;

  @override
  Widget build(BuildContext context) {
    final color = debt.isPaid
        ? const Color(0xFF00A66A)
        : debt.isOverdue
        ? const Color(0xFFE36A4A)
        : const Color(0xFFE29A18);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        debt.status,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<void> _confirmRepayment(
  BuildContext context,
  TransactionStore store,
  DebtModel debt,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Konfirmasi pelunasan'),
      content: const Text('Apakah anda yakin melunasi hutang ini?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Ya, lunasi'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await store.repayDebt(debt);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pelunasan gagal disimpan.')),
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 44),
    child: Column(
      children: [
        Icon(icon, color: const Color(0xFF9AA0B1), size: 34),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 10),
        ),
      ],
    ),
  );
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
