import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride.dart';
import '../main.dart';
import 'dart:math' show cos, pi;

class RidesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new ride (as a driver offering a ride)
  Future<String> createRide({
    required String driverId,
    required GeoPoint pickupLocation,
    required GeoPoint dropoffLocation,
    required String pickupAddress,
    required String dropoffAddress,
    required DateTime scheduledTime,
    required int seats,
  }) async {
    try {
      // Create the ride document
      final docRef = await _firestore.collection('rides').add({
        'driver_id': driverId,
        'pickup_location': pickupLocation,
        'dropoff_location': dropoffLocation,
        'pickup_address': pickupAddress,
        'dropoff_address': dropoffAddress,
        'scheduled_time': Timestamp.fromDate(scheduledTime),
        'seats': seats,
        'passengers': [], // Array to store passenger IDs
        'status': RideStatus.pending.toString().split('.').last,
        'created_at': FieldValue.serverTimestamp(),
        'cancel_reason': null,
      });

      // Add ride to driver's created rides
      await _firestore.collection('users').doc(driverId).update({
        'rides.created': FieldValue.arrayUnion([docRef.id]),
      });

      return docRef.id;
    } catch (e) {
      throw 'Failed to create ride: $e';
    }
  }

  // Join a ride (as a passenger)
  Future<void> joinRide(String rideId, String passengerId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Get user document
        final userDoc = await transaction
            .get(_firestore.collection('users').doc(passengerId));

        // Get ride document
        final rideDoc =
            await transaction.get(_firestore.collection('rides').doc(rideId));

        if (!userDoc.exists || !rideDoc.exists) {
          throw 'User or ride not found';
        }

        // Check if user has enough tokens
        final userTokens = userDoc.data()?['tokens'] ?? 0;
        if (userTokens < 1) {
          throw 'Not enough tokens to join ride';
        }

        // Check if ride is full
        final passengers =
            List<String>.from(rideDoc.data()?['passengers'] ?? []);
        if (passengers.length >= rideDoc.data()?['seats']) {
          throw 'Ride is full';
        }

        // Check if user already joined
        if (passengers.contains(passengerId)) {
          throw 'Already joined this ride';
        }

        // Update ride with new passenger
        transaction.update(rideDoc.reference, {
          'passengers': FieldValue.arrayUnion([passengerId]),
        });

        // Deduct token from passenger
        transaction.update(userDoc.reference, {
          'tokens': FieldValue.increment(-1),
          'rides.joined': FieldValue.arrayUnion([rideId]),
        });

        // Add token to driver
        final driverId = rideDoc.data()?['driver_id'];
        if (driverId != null && driverId.isNotEmpty) {
          transaction.update(
            _firestore.collection('users').doc(driverId),
            {'tokens': FieldValue.increment(1)},
          );
        }
      });
    } catch (e) {
      throw 'Failed to join ride: $e';
    }
  }

  // Get all available rides
  Stream<List<Ride>> getAvailableRides(String currentUserId) {
    return _firestore
        .collection('rides')
        .where('status',
            isEqualTo: RideStatus.pending.toString().split('.').last)
        .where('driver_id', isNotEqualTo: currentUserId) // Don't show own rides
        .orderBy('driver_id') // Required for compound query
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      final rides =
          snapshot.docs.map((doc) => Ride.fromFirestore(doc)).toList();
      // Filter out full rides
      return rides
          .where((ride) => (ride.passengers?.length ?? 0) < ride.seats)
          .toList();
    });
  }

  // Get user's created rides
  Stream<List<Ride>> getUserCreatedRides(String userId) {
    return _firestore
        .collection('rides')
        .where('driver_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Ride.fromFirestore(doc)).toList();
    });
  }

  // Get user's joined rides
  Stream<List<Ride>> getUserJoinedRides(String userId) {
    return _firestore
        .collection('rides')
        .where('passengers', arrayContains: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Ride.fromFirestore(doc)).toList();
    });
  }

  // Start ride
  Future<void> startRide(String rideId) async {
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'status': RideStatus.inProgress.toString().split('.').last,
      });
    } catch (e) {
      throw 'Failed to start ride: $e';
    }
  }

  // Complete ride
  Future<void> completeRide(String rideId) async {
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'status': RideStatus.completed.toString().split('.').last,
      });
    } catch (e) {
      throw 'Failed to complete ride: $e';
    }
  }

  // Cancel ride
  Future<void> cancelRide(String rideId, String reason) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final rideDoc =
            await transaction.get(_firestore.collection('rides').doc(rideId));

        if (!rideDoc.exists) {
          throw 'Ride not found';
        }

        // Get passengers to refund tokens
        final passengers =
            List<String>.from(rideDoc.data()?['passengers'] ?? []);

        // Refund tokens to passengers
        for (final passengerId in passengers) {
          transaction.update(
            _firestore.collection('users').doc(passengerId),
            {
              'tokens': FieldValue.increment(1),
              'rides.joined': FieldValue.arrayRemove([rideId]),
            },
          );
        }

        // Update ride status
        transaction.update(rideDoc.reference, {
          'status': RideStatus.cancelled.toString().split('.').last,
          'cancel_reason': reason,
        });
      });
    } catch (e) {
      throw 'Failed to cancel ride: $e';
    }
  }

  // Get a single ride
  Stream<Ride?> getRide(String rideId) {
    return _firestore.collection('rides').doc(rideId).snapshots().map(
      (doc) {
        if (doc.exists) {
          return Ride.fromFirestore(doc);
        }
        return null;
      },
    );
  }

  // Get nearby available rides
  Future<List<Ride>> getNearbyRides(
    GeoPoint location,
    double radiusInKm,
    String currentUserId,
  ) async {
    final double lat = location.latitude;
    final double lng = location.longitude;
    final double latRange = radiusInKm / 111.0;
    final double lngRange = radiusInKm / (111.0 * cos(lat * pi / 180));

    final snapshot = await _firestore
        .collection('rides')
        .where('status',
            isEqualTo: RideStatus.pending.toString().split('.').last)
        .where('driver_id', isNotEqualTo: currentUserId)
        .get();

    return snapshot.docs.map((doc) => Ride.fromFirestore(doc)).where((ride) {
      // Filter by distance
      final pickupLat = ride.pickupLocation.latitude;
      final pickupLng = ride.pickupLocation.longitude;
      final inRange = (pickupLat >= lat - latRange &&
          pickupLat <= lat + latRange &&
          pickupLng >= lng - lngRange &&
          pickupLng <= lng + lngRange);

      // Filter out full rides
      final notFull = (ride.passengers?.length ?? 0) < ride.seats;

      return inRange && notFull;
    }).toList();
  }
}
