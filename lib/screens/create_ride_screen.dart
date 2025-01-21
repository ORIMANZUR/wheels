import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../services/rides_service.dart';
import '../main.dart';
import 'location_picker_screen.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ridesService = RidesService();

  late TextEditingController _pickupController;
  late TextEditingController _dropoffController;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _seats = 1;

  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  static const LatLng _israelCenter = LatLng(31.7683, 35.2137);

  @override
  void initState() {
    super.initState();
    _pickupController = TextEditingController();
    _dropoffController = TextEditingController();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    super.dispose();
  }

  Future<void> _selectLocation(bool isPickup) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          title:
              isPickup ? 'Select Pickup Location' : 'Select Dropoff Location',
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isPickup) {
          _pickupLocation = result['location'] as LatLng;
          _pickupController.text = result['address'] as String;
        } else {
          _dropoffLocation = result['location'] as LatLng;
          _dropoffController.text = result['address'] as String;
        }
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _createRide() async {
    if (_formKey.currentState!.validate() &&
        _pickupLocation != null &&
        _dropoffLocation != null) {
      try {
        final DateTime scheduledDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );

        await _ridesService.createRide(
          driverId: authService.currentUser!.uid,
          pickupLocation:
              GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
          dropoffLocation:
              GeoPoint(_dropoffLocation!.latitude, _dropoffLocation!.longitude),
          pickupAddress: _pickupController.text,
          dropoffAddress: _dropoffController.text,
          scheduledTime: scheduledDateTime,
          seats: _seats,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride created successfully!')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating ride: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a Ride'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pickup Location
            TextFormField(
              controller: _pickupController,
              readOnly: true,
              onTap: () => _selectLocation(true),
              decoration: InputDecoration(
                labelText: 'Pickup Location',
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map),
                  onPressed: () => _selectLocation(true),
                ),
              ),
              validator: (value) => value?.isEmpty ?? true
                  ? 'Please select pickup location'
                  : null,
            ),
            const SizedBox(height: 16),

            // Dropoff Location
            TextFormField(
              controller: _dropoffController,
              readOnly: true,
              onTap: () => _selectLocation(false),
              decoration: InputDecoration(
                labelText: 'Dropoff Location',
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map),
                  onPressed: () => _selectLocation(false),
                ),
              ),
              validator: (value) => value?.isEmpty ?? true
                  ? 'Please select dropoff location'
                  : null,
            ),
            const SizedBox(height: 24),

            // Date and Time Selection
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      DateFormat('MMM d, y').format(_selectedDate),
                    ),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime.format(context)),
                    onPressed: () => _selectTime(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Number of Available Seats
            Row(
              children: [
                const Text('Available Seats:'),
                Expanded(
                  child: Slider(
                    value: _seats.toDouble(),
                    min: 1,
                    max: 4,
                    divisions: 3,
                    label: _seats.toString(),
                    onChanged: (value) {
                      setState(() {
                        _seats = value.toInt();
                      });
                    },
                  ),
                ),
                Text(_seats.toString()),
              ],
            ),
            const SizedBox(height: 24),

            // Information about tokens
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You will receive 1 token for each passenger that joins your ride.',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Create Button
            ElevatedButton(
              onPressed: _createRide,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Create Ride',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
