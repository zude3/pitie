import 'package:flutter/material.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    required this.amount,
    this.showAmount = true,
    this.onToggleVisibility,
    super.key,
  });

  final double amount;
  final bool showAmount;
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C5FF2), Color(0xFF3584F5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Total Balance', style: _labelStyle)),
              if (onToggleVisibility != null)
                Tooltip(
                  message: showAmount ? 'Sembunyikan saldo' : 'Tampilkan saldo',
                  child: Semantics(
                    button: true,
                    child: InkWell(
                      onTap: onToggleVisibility,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          showAmount
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            showAmount ? '\$${amount.toStringAsFixed(2)}' : '\$ -',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACCOUNT NUMBER', style: _labelStyle),
                  const Text(
                    '0128302',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 19,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const TextStyle _labelStyle = TextStyle(
    color: Color(0xFFD9E1FF),
    fontSize: 9,
    fontWeight: FontWeight.w500,
  );
}
