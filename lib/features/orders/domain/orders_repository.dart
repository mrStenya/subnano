import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/booking.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(Supabase.instance.client),
);

/// All bookings for the current user, newest first.
final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  return ref.watch(ordersRepositoryProvider).fetchMyBookings();
});

/// Single booking detail.
final bookingDetailProvider =
    FutureProvider.family<Booking, String>((ref, id) async {
  return ref.watch(ordersRepositoryProvider).fetchBookingById(id);
});

class OrdersRepository {
  OrdersRepository(this._client);

  final SupabaseClient _client;

  Future<List<Booking>> fetchMyBookings() async {
    final userId = _client.auth.currentUser!.id;

    final data = await _client
        .from(AppConstants.bookingsTable)
        .select('''
          *,
          scooters(name),
          pickup_points(name, address),
          deposit_holds(amount, returned)
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Booking.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Booking> fetchBookingById(String id) async {
    final data = await _client
        .from(AppConstants.bookingsTable)
        .select('''
          *,
          scooters(name),
          pickup_points(name, address),
          deposit_holds(amount, returned)
        ''')
        .eq('id', id)
        .single();

    return Booking.fromJson(data);
  }
}
