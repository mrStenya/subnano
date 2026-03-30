import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final _displayFormat = DateFormat('d MMM yyyy');
  static final _apiFormat = DateFormat('yyyy-MM-dd');

  static String toDisplay(DateTime date) => _displayFormat.format(date);
  static String toApi(DateTime date) => _apiFormat.format(date);

  static DateTime fromApi(String raw) => DateTime.parse(raw);

  static int rentalDays(DateTime start, DateTime end) {
    final diff = end.difference(start).inDays;
    return diff < 1 ? 1 : diff;
  }

  static bool datesOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
  }
}
