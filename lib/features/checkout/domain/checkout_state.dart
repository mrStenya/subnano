/// State machine for the two-step checkout flow:
///
///  idle
///   └─ creatingBooking  (POST bookings)
///       └─ awaitingRentalSheet  (Stripe Payment Sheet open)
///           ├─ rentalCancelled  (user dismissed sheet — can retry)
///           └─ rentalPaid       (payment succeeded)
///               └─ awaitingDepositSheet  (Stripe Payment Sheet open)
///                   ├─ depositCancelled  (user dismissed — can retry)
///                   └─ completed         (both paid → navigate away)
///
///  Any step can also transition to [checkoutError] on unexpected failures.

sealed class CheckoutState {
  const CheckoutState();
}

/// Nothing happening yet.
class CheckoutIdle extends CheckoutState {
  const CheckoutIdle();
}

/// Creating draft booking in Supabase.
class CheckoutCreatingBooking extends CheckoutState {
  const CheckoutCreatingBooking();
}

/// Stripe Payment Sheet is being shown for the rental charge.
class CheckoutAwaitingRentalSheet extends CheckoutState {
  const CheckoutAwaitingRentalSheet({required this.bookingId});

  final String bookingId;
}

/// User closed the Stripe sheet without completing rental payment.
class CheckoutRentalCancelled extends CheckoutState {
  const CheckoutRentalCancelled({required this.bookingId});

  final String bookingId;
}

/// Rental payment succeeded. Deposit step is next.
class CheckoutRentalPaid extends CheckoutState {
  const CheckoutRentalPaid({required this.bookingId});

  final String bookingId;
}

/// Stripe Payment Sheet is being shown for the deposit.
class CheckoutAwaitingDepositSheet extends CheckoutState {
  const CheckoutAwaitingDepositSheet({required this.bookingId});

  final String bookingId;
}

/// User closed the deposit sheet without completing.
class CheckoutDepositCancelled extends CheckoutState {
  const CheckoutDepositCancelled({required this.bookingId});

  final String bookingId;
}

/// Both rental + deposit paid. Booking is confirmed.
class CheckoutCompleted extends CheckoutState {
  const CheckoutCompleted({required this.bookingId});

  final String bookingId;
}

/// Unrecoverable error (network failure, server error, etc.).
class CheckoutError extends CheckoutState {
  const CheckoutError({
    required this.message,
    this.bookingId, // present if booking was already created
  });

  final String message;
  final String? bookingId;
}
