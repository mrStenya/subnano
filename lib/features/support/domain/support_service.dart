import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';

final supportServiceProvider = Provider<SupportService>(
  (ref) => SupportService(Supabase.instance.client),
);

class SupportService {
  SupportService(this._client);

  final SupabaseClient _client;

  Future<void> createTicket({
    required String category,
    required String subject,
    required String message,
    String? bookingId,
  }) async {
    final userId = _client.auth.currentUser!.id;

    await _client.from(AppConstants.supportTicketsTable).insert({
      'user_id': userId,
      'category': category,
      'subject': subject,
      'message': message,
      'status': 'open',
      if (bookingId != null) 'booking_id': bookingId,
    });
  }

  Future<List<Map<String, dynamic>>> fetchMyTickets() async {
    final userId = _client.auth.currentUser!.id;

    final data = await _client
        .from(AppConstants.supportTicketsTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }
}
