import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../booking/domain/booking_draft_provider.dart';
import '../../booking/domain/booking_repository.dart';
import 'checkout_state.dart';

final checkoutNotifierProvider =
    NotifierProvider<CheckoutNotifier, CheckoutState>(CheckoutNotifier.new);

class CheckoutNotifier extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutIdle();

  IBookingRepository get _bookingRepo =>
      ref.read(bookingRepositoryProvider);

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Step 1 — Create booking + pay rental
  // ---------------------------------------------------------------------------
  Future<void> startRentalPayment() async {
    final draft = ref.read(bookingDraftProvider);
    if (draft == null) return;

    // If booking was already created (retry after cancellation), skip creation
    final existingBookingId = switch (state) {
      CheckoutRentalCancelled(:final bookingId) => bookingId,
      _ => null,
    };

    state = const CheckoutCreatingBooking();

    String bookingId;
    try {
      if (existingBookingId != null) {
        bookingId = existingBookingId;
      } else {
        bookingId = await _bookingRepo.createDraftBooking(
          scooterId: draft.scooterId,
          startDate: draft.startDate,
          endDate: draft.endDate,
          totalAmount: draft.rentalTotal,
        );
      }
    } catch (e) {
      state = CheckoutError(message: _friendlyError(e));
      return;
    }

    state = CheckoutAwaitingRentalSheet(bookingId: bookingId);

    try {
      // Get PaymentIntent from Edge Function
      final response = await _client.functions.invoke(
        AppConstants.createPaymentIntentFn,
        body: {
          'booking_id': bookingId,
          'amount': (draft.rentalTotal * 100).round(),
          'currency': 'usd',
        },
      );

      final data = _parseEdgeFunctionResponse(response, bookingId);

      // Present Stripe Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: data['client_secret'] as String,
          merchantDisplayName: 'SubNano',
          customerId: data['customer_id'] as String?,
          customerEphemeralKeySecret: data['ephemeral_key'] as String?,
          style: ThemeMode.system,
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      // Optimistic confirm — webhook will also confirm
      await _bookingRepo.confirmBooking(bookingId);

      state = CheckoutRentalPaid(bookingId: bookingId);
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        state = CheckoutRentalCancelled(bookingId: bookingId);
      } else {
        state = CheckoutError(
          message: e.error.localizedMessage ?? 'Payment failed',
          bookingId: bookingId,
        );
      }
    } catch (e) {
      state = CheckoutError(
        message: _friendlyError(e),
        bookingId: bookingId,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Pay deposit
  // ---------------------------------------------------------------------------
  Future<void> startDepositPayment() async {
    final bookingId = switch (state) {
      CheckoutRentalPaid(:final bookingId) => bookingId,
      CheckoutDepositCancelled(:final bookingId) => bookingId,
      _ => null,
    };
    if (bookingId == null) return;

    state = CheckoutAwaitingDepositSheet(bookingId: bookingId);

    try {
      final response = await _client.functions.invoke(
        AppConstants.createDepositIntentFn,
        body: {'booking_id': bookingId},
      );

      final data = _parseEdgeFunctionResponse(response, bookingId);

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: data['client_secret'] as String,
          merchantDisplayName: 'SubNano — Security Deposit',
          customerId: data['customer_id'] as String?,
          customerEphemeralKeySecret: data['ephemeral_key'] as String?,
          style: ThemeMode.system,
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      // Clear the draft — booking is fully confirmed
      ref.read(bookingDraftProvider.notifier).clear();

      state = CheckoutCompleted(bookingId: bookingId);
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        state = CheckoutDepositCancelled(bookingId: bookingId);
      } else {
        state = CheckoutError(
          message: e.error.localizedMessage ?? 'Deposit payment failed',
          bookingId: bookingId,
        );
      }
    } catch (e) {
      state = CheckoutError(
        message: _friendlyError(e),
        bookingId: bookingId,
      );
    }
  }

  void reset() {
    state = const CheckoutIdle();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Map<String, dynamic> _parseEdgeFunctionResponse(
    FunctionResponse response,
    String bookingId,
  ) {
    if (response.status != null && response.status! >= 400) {
      final body = response.data;
      final message = (body is Map ? body['error'] : null) as String? ??
          'Server error ${response.status}';
      throw Exception(message);
    }
    return response.data as Map<String, dynamic>;
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.contains('network') || raw.contains('SocketException')) {
      return 'No internet connection. Please try again.';
    }
    if (raw.contains('duplicate') || raw.contains('unique')) {
      return 'This scooter is already booked for the selected dates.';
    }
    return 'Something went wrong. Please try again.';
  }
}
