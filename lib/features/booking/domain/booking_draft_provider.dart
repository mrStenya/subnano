import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Transient state holding the in-progress booking before checkout.
class BookingDraft {
  const BookingDraft({
    required this.scooterId,
    required this.startDate,
    required this.endDate,
    required this.pricePerDay,
  });

  final String scooterId;
  final DateTime startDate;
  final DateTime endDate;
  final double pricePerDay;

  double get totalAmount =>
      endDate.difference(startDate).inDays * pricePerDay;
}

class BookingDraftNotifier extends Notifier<BookingDraft?> {
  @override
  BookingDraft? build() => null;

  void update({
    required String scooterId,
    required DateTime startDate,
    required DateTime endDate,
    required double pricePerDay,
  }) {
    state = BookingDraft(
      scooterId: scooterId,
      startDate: startDate,
      endDate: endDate,
      pricePerDay: pricePerDay,
    );
  }

  void clear() => state = null;
}

final bookingDraftProvider =
    NotifierProvider<BookingDraftNotifier, BookingDraft?>(
  BookingDraftNotifier.new,
);
