import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_utils.dart';

/// Transient booking state — lives in memory between BookingDatesPage and
/// CheckoutPage. Cleared after successful checkout.
class BookingDraft {
  const BookingDraft({
    required this.scooterId,
    required this.scooterName,
    required this.startDate,
    required this.endDate,
    required this.pricePerDay,
  });

  final String scooterId;
  final String scooterName;
  final DateTime startDate;
  final DateTime endDate;
  final double pricePerDay;

  int get rentalDays => AppDateUtils.rentalDays(startDate, endDate);

  /// Total rental charge — does NOT include deposit.
  double get rentalTotal => rentalDays * pricePerDay;
}

class BookingDraftNotifier extends Notifier<BookingDraft?> {
  @override
  BookingDraft? build() => null;

  void set({
    required String scooterId,
    required String scooterName,
    required DateTime startDate,
    required DateTime endDate,
    required double pricePerDay,
  }) {
    state = BookingDraft(
      scooterId: scooterId,
      scooterName: scooterName,
      startDate: startDate,
      endDate: endDate,
      pricePerDay: pricePerDay,
    );
  }

  // Keep backward-compat alias used in BookingDatesPage
  void update({
    required String scooterId,
    required DateTime startDate,
    required DateTime endDate,
    required double pricePerDay,
    String scooterName = '',
  }) =>
      set(
        scooterId: scooterId,
        scooterName: scooterName,
        startDate: startDate,
        endDate: endDate,
        pricePerDay: pricePerDay,
      );

  void clear() => state = null;
}

final bookingDraftProvider =
    NotifierProvider<BookingDraftNotifier, BookingDraft?>(
  BookingDraftNotifier.new,
);
