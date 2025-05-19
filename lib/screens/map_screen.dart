import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  LatLng? _currentLocation;
  bool _isLoading = true; // Add a loading state

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false; // Location services not enabled
        });
        return;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        setState(() {
          _isLoading = false; // Location permission denied
        });
        return;
      }
    }

    try {
      final userLocation = await location.getLocation();
      setState(() {
        _currentLocation = LatLng(
          userLocation.latitude!,
          userLocation.longitude!,
        );
        _isLoading = false; // Location fetched successfully
      });
    } catch (e) {
      print("Error fetching location: $e");
      setState(() {
        _isLoading = false; // Error during location fetch
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Your Location"),
        backgroundColor: Colors.green,
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _currentLocation == null
              ? Center(child: Text("Could not retrieve location."))
              : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentLocation!,
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: MarkerId("current"),
                    position: _currentLocation!,
                    infoWindow: InfoWindow(title: "You are here"),
                  ),
                },
                onMapCreated: (controller) {
                  mapController = controller;
                },
              ),
    );
  }
}
