import 'package:cloud_firestore/cloud_firestore.dart';

enum RideStatus {
  pending, // When ride is created by driver
  inProgress, // When ride has started
  completed, // When ride is finished
  cancelled // If cancelled by driver or passenger
}

class Ride {
  final String id;
  final String driverId;
  final List<String>? passengers; // List of passenger IDs
  final GeoPoint pickupLocation;
  final GeoPoint dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;
  final DateTime scheduledTime;
  final int seats; // Total available seats
  final RideStatus status;
  final DateTime createdAt;
  final String? cancelReason;

  Ride({
    required this.id,
    required this.driverId,
    this.passengers,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.scheduledTime,
    required this.seats,
    required this.status,
    required this.createdAt,
    this.cancelReason,
  });

  // Create from Firestore document
  factory Ride.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Ride(
      id: doc.id,
      driverId: data['driver_id'] ?? '',
      passengers: data['passengers'] != null
          ? List<String>.from(data['passengers'])
          : [],
      pickupLocation: data['pickup_location'] as GeoPoint,
      dropoffLocation: data['dropoff_location'] as GeoPoint,
      pickupAddress: data['pickup_address'] ?? '',
      dropoffAddress: data['dropoff_address'] ?? '',
      scheduledTime: (data['scheduled_time'] as Timestamp).toDate(),
      seats: data['seats'] ?? 1,
      status: RideStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => RideStatus.pending,
      ),
      createdAt: (data['created_at'] as Timestamp).toDate(),
      cancelReason: data['cancel_reason'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'driver_id': driverId,
      'passengers': passengers,
      'pickup_location': pickupLocation,
      'dropoff_location': dropoffLocation,
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
      'scheduled_time': Timestamp.fromDate(scheduledTime),
      'seats': seats,
      'status': status.toString().split('.').last,
      'created_at': Timestamp.fromDate(createdAt),
      'cancel_reason': cancelReason,
    };
  }

  // Create a copy of ride with updated fields
  Ride copyWith({
    String? id,
    String? driverId,
    List<String>? passengers,
    GeoPoint? pickupLocation,
    GeoPoint? dropoffLocation,
    String? pickupAddress,
    String? dropoffAddress,
    DateTime? scheduledTime,
    int? seats,
    RideStatus? status,
    DateTime? createdAt,
    String? cancelReason,
  }) {
    return Ride(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      passengers: passengers ?? this.passengers,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      seats: seats ?? this.seats,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      cancelReason: cancelReason ?? this.cancelReason,
    );
  }

  // Helper methods
  bool isFull() {
    return (passengers?.length ?? 0) >= seats;
  }

  bool hasPassenger(String userId) {
    return passengers?.contains(userId) ?? false;
  }

  int availableSeats() {
    return seats - (passengers?.length ?? 0);
  }
}
