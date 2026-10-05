import 'package:flutter/material.dart';

class WeeklyExpenseChart extends StatelessWidget {
  const WeeklyExpenseChart({required this.values, super.key});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: CustomPaint(painter: _WeeklyExpenseChartPainter(values)),
    );
  }
}

class _WeeklyExpenseChartPainter extends CustomPainter {
  _WeeklyExpenseChartPainter(this.values);

  final List<double> values;
  static const _barColor = Color(0xFF5B48F5);
  static const _axisColor = Color(0xFFE9EAF4);
  static const _labelColor = Color(0xFF8B91A4);
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void paint(Canvas canvas, Size size) {
    const topPadding = 20.0;
    const bottomPadding = 28.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final maxValue = values.fold<double>(0, (max, value) {
      return value > max ? value : max;
    });
    final scale = maxValue == 0 ? 1 : maxValue;
    final double slotWidth = size.width / 7;
    final barWidth = slotWidth * 0.46;
    final axisPaint = Paint()
      ..color = _axisColor
      ..strokeWidth = 1;
    final barPaint = Paint()..color = _barColor;

    for (var row = 0; row <= 3; row++) {
      final y = topPadding + chartHeight * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), axisPaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var index = 0; index < 7; index++) {
      final double value = index < values.length ? values[index] : 0.0;
      final double barHeight = maxValue == 0
          ? 0
          : (chartHeight * value / scale).toDouble();
      final left = slotWidth * index + (slotWidth - barWidth) / 2;
      final top = topPadding + chartHeight - barHeight;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        const Radius.circular(5),
      );
      canvas.drawRRect(barRect, barPaint);

      textPainter.text = TextSpan(
        text: _formatAmount(value),
        style: const TextStyle(color: _labelColor, fontSize: 8),
      );
      textPainter.layout(maxWidth: slotWidth);
      textPainter.paint(
        canvas,
        Offset(
          (slotWidth * index + (slotWidth - textPainter.width) / 2).toDouble(),
          (top - 13).clamp(0, size.height).toDouble(),
        ),
      );

      textPainter.text = TextSpan(
        text: _days[index],
        style: const TextStyle(color: _labelColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          slotWidth * index + (slotWidth - textPainter.width) / 2,
          topPadding + chartHeight + 10,
        ),
      );
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '\$${(amount / 1000000).toStringAsFixed(1)}m';
    if (amount >= 1000) return '\$${(amount / 1000).toStringAsFixed(1)}k';
    return '\$${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 1)}';
  }

  @override
  bool shouldRepaint(covariant _WeeklyExpenseChartPainter oldDelegate) {
    return oldDelegate.values.length != values.length ||
        !_sameValues(oldDelegate.values, values);
  }

  bool _sameValues(List<double> previous, List<double> current) {
    if (previous.length != current.length) return false;
    for (var index = 0; index < current.length; index++) {
      if (previous[index] != current[index]) return false;
    }
    return true;
  }
}
