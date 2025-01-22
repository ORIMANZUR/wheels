import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/ride.dart';
import '../services/rides_service.dart';
import '../services/auth_service.dart';
import '../main.dart';

class RideDetailsScreen extends StatefulWidget {
  final Ride ride;

  const RideDetailsScreen({super.key, required this.ride});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  final _ridesService = RidesService();
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  void _initializeMap() {
    _markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(
          widget.ride.pickupLocation.latitude,
          widget.ride.pickupLocation.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: widget.ride.pickupAddress),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(
          widget.ride.dropoffLocation.latitude,
          widget.ride.dropoffLocation.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.ride.dropoffAddress),
      ),
    );

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(
            widget.ride.pickupLocation.latitude,
            widget.ride.pickupLocation.longitude,
          ),
          LatLng(
            widget.ride.dropoffLocation.latitude,
            widget.ride.dropoffLocation.longitude,
          ),
        ],
        color: Colors.blue,
        width: 4,
      ),
    );
  }

  Future<void> _joinRide() async {
    try {
      await _ridesService.joinRide(
        widget.ride.id,
        authService.currentUser!.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the ride!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _startRide() async {
    try {
      await _ridesService.startRide(widget.ride.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride started!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting ride: $e')),
        );
      }
    }
  }

  Future<void> _completeRide() async {
    try {
      await _ridesService.completeRide(widget.ride.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing ride: $e')),
        );
      }
    }
  }

  Future<void> _cancelRide() async {
    final currentUser = authService.currentUser;
    if (currentUser == null) return;

    final isDriver = widget.ride.driverId == currentUser.uid;
    final isPassenger = widget.ride.hasPassenger(currentUser.uid);

    // Only allow driver or passenger to cancel
    if (!isDriver && !isPassenger) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You are not authorized to cancel this ride')),
        );
      }
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _CancelDialog(),
    );

    if (reason != null) {
      try {
        await _ridesService.cancelRide(widget.ride.id, reason);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride cancelled')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error cancelling ride: $e')),
          );
        }
      }
    }
  }

  // Add new method for passengers to leave ride
  Future<void> _leaveRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Ride'),
        content: const Text(
            'Are you sure you want to leave this ride? Your token will be refunded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Leave Ride'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _ridesService.leaveRide(
          widget.ride.id,
          authService.currentUser!.uid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully left the ride')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error leaving ride: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = authService.currentUser;
    final isDriver = widget.ride.driverId == currentUser?.uid;
    final isPassenger = widget.ride.hasPassenger(currentUser?.uid ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Details'),
        actions: [
          if (widget.ride.status == RideStatus.pending &&
              isDriver) // Only driver can cancel
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _cancelRide,
            ),
          if (widget.ride.status == RideStatus.pending &&
              isPassenger) // Passengers can leave
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _leaveRide,
            ),
        ],
      ),
      body: Column(
        children: [
          // Map showing route
          SizedBox(
            height: 200,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  widget.ride.pickupLocation.latitude,
                  widget.ride.pickupLocation.longitude,
                ),
                zoom: 12,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) => _mapController = controller,
            ),
          ),

          // Ride details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card
                  Card(
                    child: ListTile(
                      leading: Icon(
                        _getStatusIcon(widget.ride.status),
                        color: _getStatusColor(widget.ride.status),
                      ),
                      title: Text(
                        widget.ride.status
                            .toString()
                            .split('.')
                            .last
                            .toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(widget.ride.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Created ${DateFormat.yMMMd().format(widget.ride.createdAt)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Locations
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildLocationItem(
                            'Pickup',
                            widget.ride.pickupAddress,
                            Icons.trip_origin,
                            Colors.green,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Icon(Icons.more_vert),
                          ),
                          _buildLocationItem(
                            'Dropoff',
                            widget.ride.dropoffAddress,
                            Icons.place,
                            Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time and Seats/Token info
                  Row(
                    children: [
                      // Time
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(Icons.access_time),
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat.jm()
                                      .format(widget.ride.scheduledTime),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  DateFormat.yMMMd()
                                      .format(widget.ride.scheduledTime),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Seats
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(Icons.event_seat),
                                const SizedBox(height: 8),
                                Text(
                                  '${widget.ride.availableSeats()} / ${widget.ride.seats}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Available Seats',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Token info
                      if (!isDriver &&
                          !isPassenger &&
                          widget.ride.status == RideStatus.pending)
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(Icons.stars,
                                      color: Colors.amber.shade700),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '1 Token',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'to join',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          if (widget.ride.status != RideStatus.completed &&
              widget.ride.status != RideStatus.cancelled)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (widget.ride.status == RideStatus.pending &&
                      !isDriver &&
                      !isPassenger &&
                      !widget.ride.isFull())
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _joinRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        child: const Text('Join Ride'),
                      ),
                    ),
                  if (widget.ride.status == RideStatus.pending && isDriver)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startRide,
                        child: const Text('Start Ride'),
                      ),
                    ),
                  if (widget.ride.status == RideStatus.inProgress && isDriver)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _completeRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Complete Ride'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationItem(
    String label,
    String address,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(RideStatus status) {
    switch (status) {
      case RideStatus.pending:
        return Icons.schedule;
      case RideStatus.inProgress:
        return Icons.directions_car;
      case RideStatus.completed:
        return Icons.done_all;
      case RideStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.pending:
        return Colors.orange;
      case RideStatus.inProgress:
        return Colors.green;
      case RideStatus.completed:
        return Colors.grey;
      case RideStatus.cancelled:
        return Colors.red;
    }
  }
}

class _CancelDialog extends StatefulWidget {
  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel Ride'),
      content: TextField(
        controller: _reasonController,
        decoration: const InputDecoration(
          labelText: 'Reason for cancellation',
          hintText: 'Please provide a reason',
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_reasonController.text.isNotEmpty) {
              Navigator.pop(context, _reasonController.text);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Cancel Ride'),
        ),
      ],
    );
  }
}
