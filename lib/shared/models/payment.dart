import 'package:equatable/equatable.dart';

enum PaymentStatus { pending, succeeded, failed, refunded }

enum PaymentType { rental, deposit }

class Payment extends Equatable {
  const Payment({
    required this.id,
    required this.bookingId,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.stripePaymentIntentId,
  });

  final String id;
  final String bookingId;
  final PaymentType type;
  final double amount;
  final PaymentStatus status;
  final DateTime createdAt;
  final String? stripePaymentIntentId;

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      type: PaymentType.values.byName(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      status: PaymentStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
    );
  }

  @override
  List<Object?> get props => [id];
}
