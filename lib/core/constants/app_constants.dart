class AppConstants {
  AppConstants._();

  // Supabase table names
  static const String profilesTable = 'profiles';
  static const String scootersTable = 'scooters';
  static const String pickupPointsTable = 'pickup_points';
  static const String bookingsTable = 'bookings';
  static const String paymentsTable = 'payments';
  static const String depositHoldsTable = 'deposit_holds';
  static const String supportTicketsTable = 'support_tickets';

  // Supabase Edge Function names
  static const String createPaymentIntentFn = 'create-payment-intent';
  static const String createDepositIntentFn = 'create-deposit-intent';

  // Business rules
  static const int minRentalDays = 1;
  static const int maxRentalDays = 30;
  static const double depositAmountUsd = 500.0;
}
