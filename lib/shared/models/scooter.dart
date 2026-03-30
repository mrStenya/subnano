import 'package:equatable/equatable.dart';

enum ScooterStatus { available, rented, maintenance, retired }

class Scooter extends Equatable {
  const Scooter({
    required this.id,
    required this.name,
    required this.pricePerDay,
    required this.status,
    this.description,
    this.imageUrl,
    this.maxDepthM,
    this.maxSpeedKnots,
    this.batteryHours,
    this.weightKg,
    this.pickupPointId,
    this.pickupPointName,
    this.pickupPointAddress,
  });

  final String id;
  final String name;
  final double pricePerDay;
  final ScooterStatus status;
  final String? description;
  final String? imageUrl;
  final double? maxDepthM;
  final double? maxSpeedKnots;
  final double? batteryHours;
  final double? weightKg;
  final String? pickupPointId;

  // Joined from pickup_points — populated only in detail queries
  final String? pickupPointName;
  final String? pickupPointAddress;

  bool get isAvailable => status == ScooterStatus.available;

  factory Scooter.fromJson(Map<String, dynamic> json) {
    final pp = json['pickup_points'] as Map<String, dynamic>?;
    return Scooter(
      id: json['id'] as String,
      name: json['name'] as String,
      pricePerDay: (json['price_per_day'] as num).toDouble(),
      status: ScooterStatus.values.byName(json['status'] as String),
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      maxDepthM: (json['max_depth_m'] as num?)?.toDouble(),
      maxSpeedKnots: (json['max_speed_knots'] as num?)?.toDouble(),
      batteryHours: (json['battery_hours'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      pickupPointId: json['pickup_point_id'] as String?,
      pickupPointName: pp?['name'] as String?,
      pickupPointAddress: pp?['address'] as String?,
    );
  }

  @override
  List<Object?> get props => [id];
}
