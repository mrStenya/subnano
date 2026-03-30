import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/scooter.dart';

// ---------------------------------------------------------------------------
// Abstract interface — makes unit testing easy without Supabase
// ---------------------------------------------------------------------------
abstract class ICatalogRepository {
  Future<List<Scooter>> fetchScooters({bool availableOnly = false});
  Future<Scooter> fetchScooterById(String id);
  Future<bool> checkAvailability({
    required String scooterId,
    required DateTime startDate,
    required DateTime endDate,
  });
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final catalogRepositoryProvider = Provider<ICatalogRepository>(
  (ref) => SupabaseCatalogRepository(Supabase.instance.client),
);

/// All scooters. Pass [availableOnly] = true to hide non-available ones.
final scooterListProvider =
    FutureProvider.family<List<Scooter>, bool>((ref, availableOnly) async {
  return ref
      .watch(catalogRepositoryProvider)
      .fetchScooters(availableOnly: availableOnly);
});

/// Single scooter by id — includes pickup_points join.
final scooterDetailProvider =
    FutureProvider.family<Scooter, String>((ref, id) async {
  return ref.watch(catalogRepositoryProvider).fetchScooterById(id);
});

// ---------------------------------------------------------------------------
// Supabase implementation
// ---------------------------------------------------------------------------
class SupabaseCatalogRepository implements ICatalogRepository {
  SupabaseCatalogRepository(this._client);

  final SupabaseClient _client;

  /// List query — lightweight, no joins, just the scooters table.
  @override
  Future<List<Scooter>> fetchScooters({bool availableOnly = false}) async {
    var query = _client
        .from(AppConstants.scootersTable)
        .select()
        .order('name');

    if (availableOnly) {
      query = query.eq('status', 'available');
    }

    final data = await query;
    return (data as List)
        .map((row) => Scooter.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Detail query — joins pickup_points so the UI can show location.
  @override
  Future<Scooter> fetchScooterById(String id) async {
    final data = await _client
        .from(AppConstants.scootersTable)
        .select('*, pickup_points(name, address)')
        .eq('id', id)
        .single();

    return Scooter.fromJson(data);
  }

  /// Calls the DB function defined in the migration.
  @override
  Future<bool> checkAvailability({
    required String scooterId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result = await _client.rpc(
      'check_scooter_availability',
      params: {
        'p_scooter_id': scooterId,
        'p_start_date': startDate.toIso8601String().substring(0, 10),
        'p_end_date': endDate.toIso8601String().substring(0, 10),
      },
    );
    return result as bool;
  }
}
