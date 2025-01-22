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
  List<Ride> _filteredRides = [];

  // Filter states
  bool _showTodayOnly = false;
  bool _showAvailableOnly = true;
  String _searchQuery = '';

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
    _heightAnimation = Tween<double>(
      begin: 300,
      end: MediaQuery.of(context).size.height * 0.85,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _filterRides() {
    setState(() {
      _filteredRides = _availableRides.where((ride) {
        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          final searchLower = _searchQuery.toLowerCase();
          if (!ride.pickupAddress.toLowerCase().contains(searchLower) &&
              !ride.dropoffAddress.toLowerCase().contains(searchLower)) {
            return false;
          }
        }

        // Apply today filter
        if (_showTodayOnly) {
          final today = DateTime.now();
          final rideDate = ride.scheduledTime;
          if (rideDate.year != today.year ||
              rideDate.month != today.month ||
              rideDate.day != today.day) {
            return false;
          }
        }

        // Apply available seats filter
        if (_showAvailableOnly && ride.isFull()) {
          return false;
        }

        return true;
      }).toList();

      // Update markers based on filtered rides
      _updateMapMarkers();
    });
  }

  void _updateMapMarkers() {
    _markers.clear();
    for (var ride in _filteredRides) {
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
  }

  Future<void> _loadRides() async {
    final currentUserId = authService.currentUser?.uid ?? '';
    _ridesService.getAvailableRides(currentUserId).listen((rides) {
      if (mounted) {
        setState(() {
          _availableRides = rides;
          _filterRides(); // This will update _filteredRides and markers
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(32.0853, 34.7818), // Tel Aviv
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
                          // Search TextField
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon:
                                  Icon(Icons.search, color: Colors.grey),
                              hintText: 'Search by location...',
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                _filterRides();
                              });
                            },
                          ),
                          const SizedBox(height: 8),

                          // Filter Chips
                          Row(
                            children: [
                              FilterChip(
                                selected: _showTodayOnly,
                                label: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: _showTodayOnly
                                          ? Colors.white
                                          : Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Today',
                                      style: TextStyle(
                                          color: _showTodayOnly
                                              ? Colors.white
                                              : Colors.blue.shade700),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.blue.shade50,
                                selectedColor: Colors.blue.shade400,
                                onSelected: (bool value) {
                                  setState(() {
                                    _showTodayOnly = value;
                                    _filterRides();
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                selected: _showAvailableOnly,
                                label: Row(
                                  children: [
                                    Icon(
                                      Icons.event_seat,
                                      size: 16,
                                      color: _showAvailableOnly
                                          ? Colors.white
                                          : Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Available',
                                      style: TextStyle(
                                          color: _showAvailableOnly
                                              ? Colors.white
                                              : Colors.blue.shade700),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.blue.shade50,
                                selectedColor: Colors.blue.shade400,
                                onSelected: (bool value) {
                                  setState(() {
                                    _showAvailableOnly = value;
                                    _filterRides();
                                  });
                                },
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
                    '${_filteredRides.length} Available Rides',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Expand/Collapse Button
              Positioned(
                bottom: _isExpanded ? 16 : 0,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                      if (_isExpanded) {
                        _animationController.forward();
                      } else {
                        _animationController.reverse();
                      }
                    });
                  },
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
            ],
          ),
        );
      },
    );
  }

  void _onMarkerTapped(Ride ride) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideDetailsScreen(ride: ride),
      ),
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

  @override
  void dispose() {
    _animationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
