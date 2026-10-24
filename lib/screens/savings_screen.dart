import 'package:flutter/material.dart';

import '../data/transaction_store.dart';
import '../models/category_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';
import 'transaction_detail_screen.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PitieScope.of(context);
    final totalSaved = store.savingsGoals.fold<double>(
      0,
      (sum, goal) => sum + goal.savedAmount,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
      children: [
        const Text(
          'Tabungan',
          style: TextStyle(
            color: Color(0xFF111631),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Rencanakan tujuan dan pantau progresnya',
          style: TextStyle(color: Color(0xFF8B91A4), fontSize: 13),
        ),
        const SizedBox(height: 18),
        _SavingsSummary(
          totalSaved: totalSaved,
          goals: store.savingsGoals.length,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: store.savingsBalance > 0
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UseSavingsScreen()),
                )
              : null,
          icon: const Icon(Icons.shopping_bag_outlined),
          label: const Text('Gunakan tabungan'),
        ),
        const SizedBox(height: 22),
        const Text(
          'Target tabungan',
          style: TextStyle(
            color: Color(0xFF111631),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (store.savingsGoals.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 44),
            child: Column(
              children: [
                Icon(
                  Icons.savings_outlined,
                  color: Color(0xFF9AA0B1),
                  size: 34,
                ),
                SizedBox(height: 10),
                Text(
                  'Belum ada target tabungan',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Buat target pertama lewat tombol +.',
                  style: TextStyle(color: Color(0xFF8B91A4), fontSize: 10),
                ),
              ],
            ),
          )
        else
          ...store.savingsGoals.map(
            (goal) => _SavingsGoalCard(
              goal: goal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SavingsGoalDetailScreen(goal: goal),
                ),
              ),
              onAdd: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddSavingsAmountScreen(goal: goal),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AddSavingsGoalScreen extends StatefulWidget {
  const AddSavingsGoalScreen({super.key});

  @override
  State<AddSavingsGoalScreen> createState() => _AddSavingsGoalScreenState();
}

class _AddSavingsGoalScreenState extends State<AddSavingsGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await PitieScope.of(context).addSavingsGoal(
        SavingsGoalModel(
          name: _nameController.text.trim(),
          targetAmount: double.parse(_targetController.text.trim()),
          savedAmount: 0,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Target tabungan gagal disimpan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Target tabungan baru')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nama target',
              hintText: 'Contoh: Mobil, Cicilan, Dana darurat',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nama target wajib diisi'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Nominal target',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final amount = double.tryParse(value?.trim() ?? '');
              return amount == null || amount <= 0
                  ? 'Masukkan nominal target yang valid'
                  : null;
            },
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Menyimpan...' : 'Buat target'),
          ),
        ],
      ),
    ),
  );
}

class AddSavingsAmountScreen extends StatefulWidget {
  const AddSavingsAmountScreen({required this.goal, super.key});
  final SavingsGoalModel goal;

  @override
  State<AddSavingsAmountScreen> createState() => _AddSavingsAmountScreenState();
}

class _AddSavingsAmountScreenState extends State<AddSavingsAmountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await PitieScope.of(context).addSavingsAmount(
        widget.goal,
        double.parse(_amountController.text.trim()),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setoran gagal disimpan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Setor ke ${widget.goal.name}')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Terkumpul \$${widget.goal.savedAmount.toStringAsFixed(2)} dari '
            '\$${widget.goal.targetAmount.toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFF687183), fontSize: 12),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Nominal setoran',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final amount = double.tryParse(value?.trim() ?? '');
              return amount == null || amount <= 0
                  ? 'Masukkan nominal setoran yang valid'
                  : null;
            },
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Menyimpan...' : 'Simpan setoran'),
          ),
        ],
      ),
    ),
  );
}

class SavingsGoalDetailScreen extends StatelessWidget {
  const SavingsGoalDetailScreen({required this.goal, super.key});
  final SavingsGoalModel goal;

  @override
  Widget build(BuildContext context) {
    final store = PitieScope.of(context);
    final current = store.savingsGoals.firstWhere(
      (item) => item.id == goal.id,
      orElse: () => goal,
    );
    final history =
        store.transactions
            .where((transaction) => transaction.savingsGoalId == current.id)
            .toList()
          ..sort((first, second) => second.date.compareTo(first.date));
    final progress = current.targetAmount == 0
        ? 0.0
        : (current.savedAmount / current.targetAmount).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: Text(current.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          _SavingsSummary(totalSaved: current.savedAmount, goals: 1),
          const SizedBox(height: 14),
          Text(
            'Target \$${current.targetAmount.toStringAsFixed(2)} · ${(progress * 100).round()}%',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF00B879),
            backgroundColor: const Color(0xFFE9F1ED),
          ),
          const SizedBox(height: 22),
          const Text(
            'Riwayat aktivitas',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            const Text(
              'Belum ada setoran atau pemakaian.',
              style: TextStyle(color: Color(0xFF8B91A4), fontSize: 11),
            ),
          ...history.map(
            (transaction) => _SavingsActivityItem(
              transaction: transaction,
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

class UseSavingsScreen extends StatefulWidget {
  const UseSavingsScreen({super.key});

  @override
  State<UseSavingsScreen> createState() => _UseSavingsScreenState();
}

class _UseSavingsScreenState extends State<UseSavingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  static final _expenseCategories = transactionCategories
      .where(
        (category) =>
            !const ['Gaji', 'Freelance', 'Bonus'].contains(category.name),
      )
      .map((category) => category.name)
      .toList();
  int? _goalId;
  String _category = _expenseCategories.first;
  DateTime _date = DateTime.now();
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final goals = PitieScope.of(context).savingsGoals
        .where((goal) => goal.savedAmount > 0 && goal.id != null);
    if (goals.isNotEmpty) _goalId = goals.first.id;
    _initialized = true;
  }

  @override
  void dispose() {
    _amountController.dispose();
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
    final store = PitieScope.of(context);
    final goal = store.savingsGoals.firstWhere((item) => item.id == _goalId);
    final amount = double.parse(_amountController.text.trim());
    if (amount > goal.savedAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo target tidak mencukupi.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await store.useSavings(goal, amount, _category, _date);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pemakaian tabungan gagal disimpan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = PitieScope.of(context).savingsGoals
        .where((goal) => goal.savedAmount > 0 && goal.id != null)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Gunakan tabungan')),
      body: goals.isEmpty
          ? const Center(child: Text('Belum ada saldo tabungan yang tersedia.'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _goalId,
                    decoration: const InputDecoration(
                      labelText: 'Sumber tabungan',
                      border: OutlineInputBorder(),
                    ),
                    items: goals
                        .map(
                          (goal) => DropdownMenuItem(
                            value: goal.id,
                            child: Text(
                              '${goal.name} · \$${goal.savedAmount.toStringAsFixed(2)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _goalId = value),
                    validator: (value) =>
                        value == null ? 'Pilih sumber tabungan' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Kategori pengeluaran',
                      border: OutlineInputBorder(),
                    ),
                    items: _expenseCategories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _category = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('Tanggal: ${_formatDate(_date)}'),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Menyimpan...' : 'Simpan pemakaian'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SavingsSummary extends StatelessWidget {
  const _SavingsSummary({required this.totalSaved, required this.goals});
  final double totalSaved;
  final int goals;

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
            color: const Color(0xFF00B879).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.savings_outlined,
            color: Color(0xFF00A66A),
            size: 21,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saldo tabungan',
                style: TextStyle(color: Color(0xFF8B91A4), fontSize: 12),
              ),
              Text(
                '\$${totalSaved.toStringAsFixed(2)}',
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
          '$goals target',
          style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 12),
        ),
      ],
    ),
  );
}

class _SavingsGoalCard extends StatelessWidget {
  const _SavingsGoalCard({
    required this.goal,
    required this.onTap,
    required this.onAdd,
  });
  final SavingsGoalModel goal;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final progress = goal.targetAmount == 0
        ? 0.0
        : (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0);
    final isComplete = goal.savedAmount >= goal.targetAmount;
    return InkWell(
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF8F1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flag_outlined,
                    color: Color(0xFF00A66A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    goal.name,
                    style: const TextStyle(
                      color: Color(0xFF111631),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!isComplete)
                  IconButton(
                    onPressed: onAdd,
                    tooltip: 'Tambah setoran',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF00A66A),
                    ),
                  )
                else
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF00A66A),
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '\$${goal.savedAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'Target \$${goal.targetAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF8B91A4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF00B879),
              backgroundColor: const Color(0xFFE9F1ED),
            ),
            const SizedBox(height: 5),
            Text(
              '${(progress * 100).round()}% tercapai',
              style: const TextStyle(color: Color(0xFF8B91A4), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsActivityItem extends StatelessWidget {
  const _SavingsActivityItem({required this.transaction, required this.onTap});
  final TransactionModel transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUse = transaction.account == TransactionAccount.savings;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isUse ? Icons.shopping_bag_outlined : Icons.add_circle_outline,
        color: isUse ? const Color(0xFFE36A4A) : const Color(0xFF00A66A),
      ),
      title: Text(
        isUse ? 'Pemakaian · ${transaction.category}' : 'Setoran tabungan',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
        style: const TextStyle(fontSize: 10),
      ),
      trailing: Text(
        '\$${transaction.amount.toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      onTap: onTap,
    );
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
