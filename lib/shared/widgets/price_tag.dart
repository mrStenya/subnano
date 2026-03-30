import 'package:flutter/material.dart';
import '../../core/utils/currency_utils.dart';

class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.amount,
    this.suffix = '/ day',
    this.style,
  });

  final double amount;
  final String suffix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseStyle = style ??
        Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
            );
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: CurrencyUtils.formatUsd(amount)),
          TextSpan(
            text: ' $suffix',
            style: baseStyle?.copyWith(
              fontWeight: FontWeight.normal,
              fontSize: (baseStyle.fontSize ?? 14) - 2,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
