import 'package:intl/intl.dart';

class CurrencyUtils {
  CurrencyUtils._();

  static final _usd = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  static String formatUsd(double amount) => _usd.format(amount);

  /// Stripe amounts are in cents (smallest currency unit)
  static int toCents(double amount) => (amount * 100).round();
  static double fromCents(int cents) => cents / 100.0;
}
