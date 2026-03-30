import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../booking/domain/booking_draft_provider.dart';
import '../../booking/domain/booking_repository.dart';

final checkoutServiceProvider = Provider<CheckoutService>((ref) {
  return CheckoutService(
    client: Supabase.instance.client,
    bookingRepo: ref.read(bookingRepositoryProvider),
  );
});

class CheckoutResult {
  const CheckoutResult({required this.bookingId});

  final String bookingId;
}

class CheckoutService {
  CheckoutService({
    required SupabaseClient client,
    required BookingRepository bookingRepo,
  })  : _client = client,
        _bookingRepo = bookingRepo;

  final SupabaseClient _client;
  final BookingRepository _bookingRepo;

  /// 1. Creates a draft booking in Supabase
  /// 2. Calls Edge Function to get a Stripe PaymentIntent
  /// 3. Presents Stripe Payment Sheet
  /// 4. On success → confirms the booking
  Future<CheckoutResult> createBookingAndPayRental({
    required BookingDraft draft,
  }) async {
    // Step 1 — create draft booking
    final bookingId = await _bookingRepo.createDraftBooking(
      scooterId: draft.scooterId,
      startDate: draft.startDate,
      endDate: draft.endDate,
      totalAmount: draft.totalAmount,
    );

    // Step 2 — create Stripe PaymentIntent via Edge Function
    final response = await _client.functions.invoke(
      AppConstants.createPaymentIntentFn,
      body: {
        'booking_id': bookingId,
        'amount': (draft.totalAmount * 100).round(), // cents
        'currency': 'usd',
      },
    );

    final data = response.data as Map<String, dynamic>;
    final clientSecret = data['client_secret'] as String;
    final customerId = data['customer_id'] as String?;
    final ephemeralKey = data['ephemeral_key'] as String?;

    // Step 3 — configure & present Stripe Payment Sheet
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'SubNano',
        customerId: customerId,
        customerEphemeralKeySecret: ephemeralKey,
        style: ThemeMode.system,
      ),
    );
    await Stripe.instance.presentPaymentSheet();

    // Step 4 — confirm booking (webhook also does this, but we update optimistically)
    await _bookingRepo.confirmBooking(bookingId);

    return CheckoutResult(bookingId: bookingId);
  }

  /// Calls Edge Function to create a deposit hold (SetupIntent or PaymentIntent).
  Future<void> chargeDeposit({required String bookingId}) async {
    final response = await _client.functions.invoke(
      AppConstants.createDepositIntentFn,
      body: {'booking_id': bookingId},
    );

    final data = response.data as Map<String, dynamic>;
    final clientSecret = data['client_secret'] as String;

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'SubNano — Security Deposit',
        style: ThemeMode.system,
      ),
    );
    await Stripe.instance.presentPaymentSheet();
  }
}
