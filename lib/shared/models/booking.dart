import 'package:equatable/equatable.dart';

enum BookingStatus { draft, confirmed, active, completed, cancelled }

class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.scooterId,
    required this.startDate,
    required this.endDate,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.scooterName,
    this.depositAmount,
    this.depositReturned,
    this.pickupPointId,
    this.pickupPointName,
    this.pickupPointAddress,
  });

  final String id;
  final String scooterId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalAmount;
  final BookingStatus status;
  final DateTime createdAt;

  // Joined fields (optional, from query)
  final String? scooterName;
  final double? depositAmount;
  final bool? depositReturned;
  final String? pickupPointId;
  final String? pickupPointName;
  final String? pickupPointAddress;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      scooterId: json['scooter_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: BookingStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      scooterName: json['scooters']?['name'] as String?,
      depositAmount: (json['deposit_holds']?['amount'] as num?)?.toDouble(),
      depositReturned: json['deposit_holds']?['returned'] as bool?,
      pickupPointId: json['pickup_point_id'] as String?,
      pickupPointName: json['pickup_points']?['name'] as String?,
      pickupPointAddress: json['pickup_points']?['address'] as String?,
    );
  }

  @override
  List<Object?> get props => [id];
}
