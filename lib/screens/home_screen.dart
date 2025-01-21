import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/ride_card.dart';
import '../widgets/map_container.dart';
import '../services/auth_service.dart';
import '../services/rides_service.dart';
import '../models/ride.dart';
import '../main.dart';
import 'login_screen.dart';
import 'create_ride_screen.dart';
import 'ride_details_screen.dart';

class WheelsApp extends StatefulWidget {
  const WheelsApp({super.key});

  @override
  State<WheelsApp> createState() => _WheelsAppState();
}

class _WheelsAppState extends State<WheelsApp> {
  int _selectedIndex = 0;
  final _ridesService = RidesService();

  Future<void> _signOut() async {
    try {
      await authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  void _navigateToCreateRide() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateRideScreen()),
    );
  }

  void _showMenuOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Add settings navigation here
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                _signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 2:
        return _buildProfileContent();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    final currentUserId = authService.currentUser?.uid ?? '';

    return SingleChildScrollView(
      child: Column(
        children: [
          const MapContainer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Available Rides',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _navigateToCreateRide,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Ride'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<Ride>>(
                  stream: _ridesService.getAvailableRides(currentUserId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    final rides = snapshot.data ?? [];

                    if (rides.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No rides available at the moment.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rides.length,
                      itemBuilder: (context, index) => RideCard(
                        ride: rides[index],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RideDetailsScreen(ride: rides[index]),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    final userId = authService.currentUser?.uid ?? '';

    return FutureBuilder<Map<String, dynamic>?>(
      future: authService.getUserProfile(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data;
        if (userData == null) {
          return const Center(child: Text('No profile data available'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 16),
              Text(
                userData['name'] ?? 'User',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                userData['email'] ?? '',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '${userData['tokens'] ?? 0} Tokens',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildProfileStat('Rides Completed',
                  userData['rides_completed']?.toString() ?? '0'),
              _buildProfileStat(
                  'Rating', '${userData['rating']?.toString() ?? '5.0'} ⭐'),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              StreamBuilder<List<Ride>>(
                stream: _ridesService.getUserCreatedRides(userId),
                builder: (context, createdSnapshot) {
                  if (createdSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<List<Ride>>(
                    stream: _ridesService.getUserJoinedRides(userId),
                    builder: (context, joinedSnapshot) {
                      if (joinedSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final createdRides = createdSnapshot.data ?? [];
                      final joinedRides = joinedSnapshot.data ?? [];

                      if (createdRides.isEmpty && joinedRides.isEmpty) {
                        return const Center(
                          child: Text(
                            'No rides yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (createdRides.isNotEmpty) ...[
                            const Text(
                              'Rides You\'re Driving',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: createdRides.length,
                              itemBuilder: (context, index) => RideCard(
                                ride: createdRides[index],
                                isDriver: true,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RideDetailsScreen(
                                        ride: createdRides[index]),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (joinedRides.isNotEmpty) ...[
                            const Text(
                              'Rides You\'ve Joined',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: joinedRides.length,
                              itemBuilder: (context, index) => RideCard(
                                ride: joinedRides[index],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RideDetailsScreen(
                                        ride: joinedRides[index]),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.blue, Colors.cyan],
          ).createShader(bounds),
          child: Text(
            'Wheels',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.grey),
            onPressed: _showMenuOptions,
          ),
        ],
      ),
      body: _getCurrentScreen(),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.directions_car, 'Rides', 0),
              const SizedBox(width: 32),
              _buildCreateRideButton(),
              const SizedBox(width: 32),
              _buildNavItem(Icons.person, 'Profile', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: _selectedIndex == index ? Colors.blue : Colors.grey,
          ),
          Text(
            label,
            style: TextStyle(
              color: _selectedIndex == index ? Colors.blue : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateRideButton() {
    return FloatingActionButton(
      onPressed: _navigateToCreateRide,
      backgroundColor: Colors.blue,
      child: const Text(
        'Create\nRide',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }
}
