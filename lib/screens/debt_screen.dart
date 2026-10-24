import 'package:flutter/material.dart';

import '../data/transaction_store.dart';
import '../models/debt_model.dart';
import 'transaction_detail_screen.dart';

enum _DebtPeriod { all, today, thisWeek, thisMonth }

class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key});

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  String _query = '';
  DebtType? _type;
  _DebtPeriod _period = _DebtPeriod.all;

  @override
  Widget build(BuildContext context) {
    final store = PitieScope.of(context);
    final range = _selectedRange();
    final query = _query.trim().toLowerCase();
    final debts = store.debts.where((debt) {
      if (_type != null && debt.type != _type) return false;
      if (range != null &&
          (debt.date.isBefore(range.start) || !debt.date.isBefore(range.end))) {
        return false;
      }
      return query.isEmpty ||
          debt.recipient.toLowerCase().contains(query) ||
          debt.note.toLowerCase().contains(query) ||
          debt.type.label.toLowerCase().contains(query) ||
          debt.amount.toString().contains(query);
    }).toList();
    final unpaid = debts.where((debt) => !debt.isPaid).toList();
    final total = unpaid.fold<double>(0, (sum, debt) => sum + debt.amount);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
      children: [
        const Text(
          'Debt',
          style: TextStyle(
            color: Color(0xFF111631),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Catat dan pantau hutang yang belum lunas',
          style: TextStyle(color: Color(0xFF8B91A4), fontSize: 13),
        ),
        const SizedBox(height: 14),
        _DebtSummary(total: total, count: unpaid.length),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Daftar hutang',
                style: TextStyle(
                  color: Color(0xFF111631),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (store.debts.isNotEmpty)
              IconButton(
                onPressed: () => _confirmClear(context, store),
                tooltip: 'Hapus semua catatan hutang',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Cari hutang',
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<DebtType?>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Jenis',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<DebtType?>(
                    value: null,
                    child: Text('Semua jenis'),
                  ),
                  ...DebtType.values.map(
                    (type) => DropdownMenuItem<DebtType?>(
                      value: type,
                      child: Text(type.label),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _type = value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<_DebtPeriod>(
                initialValue: _period,
                decoration: const InputDecoration(
                  labelText: 'Periode',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: _DebtPeriod.all,
                    child: Text('Semua'),
                  ),
                  DropdownMenuItem(
                    value: _DebtPeriod.today,
                    child: Text('Hari ini'),
                  ),
                  DropdownMenuItem(
                    value: _DebtPeriod.thisWeek,
                    child: Text('Minggu ini'),
                  ),
                  DropdownMenuItem(
                    value: _DebtPeriod.thisMonth,
                    child: Text('Bulan ini'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _period = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (debts.isEmpty)
          const _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Hutang tidak ditemukan',
            message: 'Ubah filter atau tambahkan catatan baru.',
          )
        else
          ...debts.map(
            (debt) => _DebtItem(
              debt: debt,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DebtDetailScreen(debt: debt)),
              ),
              onRepay: () => _confirmRepayment(context, store, debt),
            ),
          ),
      ],
    );
  }

  DateTimeRange? _selectedRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      _DebtPeriod.all => null,
      _DebtPeriod.today => DateTimeRange(
        start: today,
        end: today.add(const Duration(days: 1)),
      ),
      _DebtPeriod.thisWeek => DateTimeRange(
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today
            .subtract(Duration(days: today.weekday - 1))
            .add(const Duration(days: 7)),
      ),
      _DebtPeriod.thisMonth => DateTimeRange(
        start: DateTime(now.year, now.month),
        end: DateTime(now.year, now.month + 1),
      ),
    };
  }
}

class DebtDetailScreen extends StatelessWidget {
  const DebtDetailScreen({required this.debt, super.key});
  final DebtModel debt;

  @override
  Widget build(BuildContext context) {
    final store = PitieScope.of(context);
    final history =
        store.transactions
            .where((transaction) => transaction.debtId == debt.id)
            .toList()
          ..sort((first, second) => second.date.compareTo(first.date));
    return Scaffold(
      appBar: AppBar(title: Text(debt.type.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    debt.recipient,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text('\$${debt.amount.toStringAsFixed(2)}'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DebtDetailRow(label: 'Penerima', value: debt.recipient),
          _DebtDetailRow(label: 'Tanggal mulai', value: _formatDate(debt.date)),
          _DebtDetailRow(
            label: 'Tenggat',
            value: debt.dueDate == null
                ? 'Tidak ditentukan'
                : _formatDate(debt.dueDate!),
          ),
          _DebtDetailRow(label: 'Status', value: debt.status),
          if (debt.note.isNotEmpty)
            _DebtDetailRow(label: 'Catatan', value: debt.note),
          const SizedBox(height: 18),
          const Text(
            'Riwayat transaksi',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            const Text(
              'Belum ada perpindahan saldo untuk catatan ini.',
              style: TextStyle(color: Color(0xFF8B91A4), fontSize: 11),
            ),
          ...history.map(
            (transaction) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(transaction.description),
              subtitle: Text(_formatDate(transaction.date)),
              trailing: Text('\$${transaction.amount.toStringAsFixed(2)}'),
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

Future<void> _confirmClear(BuildContext context, TransactionStore store) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hapus semua catatan hutang?'),
      content: const Text(
        'Catatan dan transaksi terkait akan dihapus. Saldo akan dihitung ulang.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Hapus semua'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await store.clearDebts();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daftar hutang gagal dihapus.')),
      );
    }
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
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE3E6EF)),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFF4B4B).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: Color(0xFFFF4B4B),
            size: 21,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Belum lunas',
                style: TextStyle(color: Color(0xFF8B91A4), fontSize: 12),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF111631),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Text(
          '$count catatan',
          style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 12),
        ),
      ],
    ),
  );
}

class _DebtItem extends StatelessWidget {
  const _DebtItem({
    required this.debt,
    required this.onTap,
    required this.onRepay,
  });
  final DebtModel debt;
  final VoidCallback onTap;
  final VoidCallback onRepay;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6EF)),
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
                    color: Color(0xFF111631),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '\$${debt.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: debt.isPaid
                      ? const Color(0xFF8B91A4)
                      : const Color(0xFFFF4B4B),
                  fontSize: 14,
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
                style: const TextStyle(color: Color(0xFF687183), fontSize: 11),
              ),
              Text(
                'Mulai ${_formatDate(debt.date)}',
                style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 11),
              ),
              if (debt.dueDate != null)
                Text(
                  'Tenggat ${_formatDate(debt.dueDate!)}',
                  style: const TextStyle(
                    color: Color(0xFF8B91A4),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (debt.note.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              debt.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF687183), fontSize: 12),
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
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _DebtDetailRow extends StatelessWidget {
  const _DebtDetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        debt.status,
        style: TextStyle(
          color: color,
          fontSize: 10,
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
