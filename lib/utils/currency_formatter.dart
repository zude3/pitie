String formatRupiah(double amount) {
  final wholeAmount = amount.round().toString();
  final sign = wholeAmount.startsWith('-') ? '-' : '';
  final digits = sign.isEmpty ? wholeAmount : wholeAmount.substring(1);
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return 'Rp $sign$grouped';
}

String formatRupiahCompact(double amount) {
  final absoluteAmount = amount.abs();
  if (absoluteAmount >= 1000000000) {
    return 'Rp ${(amount / 1000000000).toStringAsFixed(1)} M';
  }
  if (absoluteAmount >= 1000000) {
    return 'Rp ${(amount / 1000000).toStringAsFixed(1)} jt';
  }
  if (absoluteAmount >= 1000) {
    return 'Rp ${(amount / 1000).toStringAsFixed(1)} rb';
  }
  return formatRupiah(amount);
}
