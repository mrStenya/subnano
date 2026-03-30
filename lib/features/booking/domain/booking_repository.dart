import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/booking.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------
abstract class IBookingRepository {
  Future<String> createDraftBooking({
    required String scooterId,
    required DateTime startDate,
    required DateTime endDate,
    required double totalAmount,
    String? pickupPointId,
  });

  Future<void> confirmBooking(String bookingId);

  Future<Booking> fetchBookingById(String bookingId);
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final bookingRepositoryProvider = Provider<IBookingRepository>(
  (ref) => SupabaseBookingRepository(Supabase.instance.client),
);

// ---------------------------------------------------------------------------
// Supabase implementation
// ---------------------------------------------------------------------------
class SupabaseBookingRepository implements IBookingRepository {
  SupabaseBookingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> createDraftBooking({
    required String scooterId,
    required DateTime startDate,
    required DateTime endDate,
    required double totalAmount,
    String? pickupPointId,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final result = await _client
        .from(AppConstants.bookingsTable)
        .insert({
          'user_id': userId,
          'scooter_id': scooterId,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
          'total_amount': totalAmount,
          'status': 'draft',
          if (pickupPointId != null) 'pickup_point_id': pickupPointId,
        })
        .select('id')
        .single();

    return result['id'] as String;
  }

  @override
  Future<void> confirmBooking(String bookingId) async {
    await _client
        .from(AppConstants.bookingsTable)
        .update({'status': 'confirmed'})
        .eq('id', bookingId);
  }

  @override
  Future<Booking> fetchBookingById(String bookingId) async {
    final data = await _client
        .from(AppConstants.bookingsTable)
        .select('''
          *,
          scooters(name),
          pickup_points(name, address),
          deposit_holds(amount, returned)
        ''')
        .eq('id', bookingId)
        .single();

    return Booking.fromJson(data);
  }
}
