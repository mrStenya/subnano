import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/scooter.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(Supabase.instance.client),
);

/// Lists all scooters (available + others for display).
final scooterListProvider = FutureProvider<List<Scooter>>((ref) async {
  return ref.watch(catalogRepositoryProvider).fetchScooters();
});

/// Single scooter by id.
final scooterDetailProvider =
    FutureProvider.family<Scooter, String>((ref, id) async {
  return ref.watch(catalogRepositoryProvider).fetchScooterById(id);
});

class CatalogRepository {
  CatalogRepository(this._client);

  final SupabaseClient _client;

  Future<List<Scooter>> fetchScooters() async {
    final data = await _client
        .from(AppConstants.scootersTable)
        .select()
        .order('name');

    return (data as List)
        .map((row) => Scooter.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Scooter> fetchScooterById(String id) async {
    final data = await _client
        .from(AppConstants.scootersTable)
        .select()
        .eq('id', id)
        .single();

    return Scooter.fromJson(data);
  }

  /// Returns true if the scooter has no confirmed/active bookings
  /// overlapping [start, end). Calls the DB function directly.
  Future<bool> checkAvailability({
    required String scooterId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result = await _client.rpc('check_scooter_availability', params: {
      'p_scooter_id': scooterId,
      'p_start_date': startDate.toIso8601String().substring(0, 10),
      'p_end_date': endDate.toIso8601String().substring(0, 10),
    });
    return result as bool;
  }
}
