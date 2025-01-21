import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/rides_service.dart';
import '../models/ride.dart';
import '../main.dart';
import '../screens/ride_details_screen.dart';

class MapContainer extends StatefulWidget {
  const MapContainer({super.key});

  @override
  State<MapContainer> createState() => _MapContainerState();
}

class _MapContainerState extends State<MapContainer>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final _ridesService = RidesService();
  bool _isExpanded = false;
  late AnimationController _animationController;
  Animation<double>? _heightAnimation;
  List<Ride> _availableRides = [];

  // Initial camera position (default to Tel Aviv)
  static const LatLng _defaultLocation = LatLng(32.0853, 34.7818);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadRides();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize the animation here where we have access to MediaQuery
    _heightAnimation = Tween<double>(
      begin: 300,
      end: MediaQuery.of(context).size.height * 0.85,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadRides() async {
    final currentUserId = authService.currentUser?.uid ?? '';
    _ridesService.getAvailableRides(currentUserId).listen((rides) {
      if (mounted) {
        setState(() {
          _availableRides = rides;
          _markers.clear();
          for (var ride in rides) {
            final availableSeats = ride.seats - (ride.passengers?.length ?? 0);
            _markers.add(
              Marker(
                markerId: MarkerId(ride.id),
                position: LatLng(
                  ride.pickupLocation.latitude,
                  ride.pickupLocation.longitude,
                ),
                infoWindow: InfoWindow(
                  title: 'To: ${ride.dropoffAddress}',
                  snippet: '${availableSeats}/${ride.seats} seats available',
                  onTap: () => _onMarkerTapped(ride),
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(availableSeats == 1
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueBlue),
              ),
            );
          }
        });
      }
    });
  }

  void _onMarkerTapped(Ride ride) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideDetailsScreen(ride: ride),
      ),
    );
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // If _heightAnimation is null, return a container with fixed height
    if (_heightAnimation == null) {
      return Container(height: 300);
    }

    return AnimatedBuilder(
      animation: _heightAnimation!,
      builder: (context, child) {
        return Container(
          height: _heightAnimation!.value,
          child: Stack(
            children: [
              // Map
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultLocation,
                  zoom: 12,
                ),
                onMapCreated: (controller) {
                  setState(() {
                    _mapController = controller;
                    _setMapStyle();
                  });
                },
                markers: _markers,
                mapType: MapType.normal,
                zoomControlsEnabled: false,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              ),

              // Expand/Collapse Button
              Positioned(
                bottom: _isExpanded ? 16 : 0,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _toggleExpanded,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(_isExpanded ? 0 : 20),
                        bottom: Radius.circular(_isExpanded ? 20 : 0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),

              // Search and Filter UI
              if (!_isExpanded)
                Positioned(
                  bottom: 40,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon:
                                  Icon(Icons.search, color: Colors.grey),
                              hintText: 'Search for a ride...',
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              // Implement search functionality
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              FilterChip(
                                label: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Today',
                                      style: TextStyle(
                                          color: Colors.blue.shade700),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.blue.shade50,
                                onSelected: (bool value) {},
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: Row(
                                  children: [
                                    Icon(
                                      Icons.event_seat,
                                      size: 16,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Available',
                                      style: TextStyle(
                                          color: Colors.blue.shade700),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.blue.shade50,
                                onSelected: (bool value) {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Available Rides Count
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${_availableRides.length} Available Rides',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setMapStyle() async {
    String style = '''
    [
      {
        "featureType": "poi",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      }
    ]
    ''';
    _mapController?.setMapStyle(style);
  }
}
