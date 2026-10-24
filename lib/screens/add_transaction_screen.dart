import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/transaction_store.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

// Warna sesuai desain Add Transaction.
const _primary = Color(0xFF5B48F5);
const _ink = Color(0xFF111631);
const _muted = Color(0xFF8B91A4);
const _border = Color(0xFFE3E6EF);
const _toggleBg = Color(0xFFE3E8EF);

const _incomeCategoryNames = ['Gaji', 'Freelance', 'Bonus'];

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

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
  late TransactionType type;
  String? category;
  late DateTime date;
  bool saving = false;

  bool get isEditing => widget.transaction != null;

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

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: date,
    );
    if (picked != null) setState(() => date = picked);
  }

  Future<void> save() async {
    final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
    final validationMessage = amount == null || !amount.isFinite
        ? 'Masukkan jumlah yang valid.'
        : amount <= 0
        ? 'Jumlah harus lebih besar dari 0.'
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
      type: type,
      amount: amount!,
      category: category!,
      description: descriptionController.text.trim().isEmpty
          ? category!
          : descriptionController.text.trim(),
      date: date,
      createdAt: widget.transaction?.createdAt,
    );
    final store = PitieScope.of(context);
    setState(() => saving = true);
    try {
      if (isEditing) {
        await store.update(transaction);
      } else {
        await store.add(transaction);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil disimpan.')),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi gagal disimpan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = transactionCategories.where((item) {
      final isIncomeCategory = _incomeCategoryNames.contains(item.name);
      return type == TransactionType.income
          ? isIncomeCategory
          : !isIncomeCategory;
    }).toList();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _ink),
            onPressed: () => Navigator.maybePop(context),
          ),
          titleSpacing: 0,
          title: Text(
            isEditing ? 'Edit Transaction' : 'Add Transaction',
            style: const TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TypeToggle(
                      value: type,
                      onChanged: (value) => setState(() {
                        if (value == type) return;
                        type = value;
                        category = null;
                      }),
                    ),
                    const SizedBox(height: 28),
                    _AmountInput(controller: amountController),
                    const SizedBox(height: 28),
                    const _SectionLabel('SELECT CATEGORY'),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categories.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 90,
                          ),
                      itemBuilder: (context, index) {
                        final item = categories[index];
                        return _CategoryCard(
                          category: item,
                          selected: item.name == category,
                          onTap: () => setState(() => category = item.name),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    const _SectionLabel('DESCRIPTION'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _fieldDecoration(
                        'Enter description / note...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('TRANSACTION DATE'),
                    const SizedBox(height: 8),
                    _DateField(value: _formatDate(date), onTap: pickDate),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: _SaveButton(
                  label: 'Save Transaction',
                  loading: saving,
                  onPressed: saving ? null : save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _muted, fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: border(_border),
    focusedBorder: border(_primary),
    border: border(_border),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _muted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    ),
  );
}

/// Toggle Expense / Income dengan pill putih untuk item terpilih.
class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});

  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, TransactionType segmentType) {
      final selected = value == segmentType;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(segmentType),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? _ink : const Color(0xFF6B7280),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _toggleBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          segment('Expense', TransactionType.expense),
          segment('Income', TransactionType.income),
        ],
      ),
    );
  }
}

/// Input nominal besar di tengah ("$0.00").
class _AmountInput extends StatelessWidget {
  const _AmountInput({required this.controller});
  final TextEditingController controller;

  static const _style = TextStyle(
    color: _ink,
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.1,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'ENTER AMOUNT',
          style: TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('\$', style: _style),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 110, maxWidth: 240),
              child: IntrinsicWidth(
                child: TextField(
                  controller: controller,
                  style: _style,
                  cursorColor: _primary,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*[.,]?\d{0,2}'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: _style,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final CategoryModel category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF0EEFF) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _primary : _border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(category.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(color: _ink, fontSize: 15),
                ),
              ),
              const Icon(Icons.calendar_month_outlined, color: _ink, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D5B48F5),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(label),
        ),
      ),
    );
  }
}
