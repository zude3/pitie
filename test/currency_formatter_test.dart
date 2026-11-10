import 'package:flutter_test/flutter_test.dart';
import 'package:pitie/utils/currency_formatter.dart';

void main() {
  test('formats whole rupiah amounts with Indonesian thousands separators', () {
    expect(formatRupiah(0), 'Rp 0');
    expect(formatRupiah(1234567), 'Rp 1.234.567');
    expect(formatRupiah(1234.6), 'Rp 1.235');
    expect(formatRupiah(-2500), 'Rp -2.500');
  });

  test('formats compact chart labels in Indonesian units', () {
    expect(formatRupiahCompact(950), 'Rp 950');
    expect(formatRupiahCompact(1500), 'Rp 1.5 rb');
    expect(formatRupiahCompact(2500000), 'Rp 2.5 jt');
    expect(formatRupiahCompact(3000000000), 'Rp 3.0 M');
  });
}
