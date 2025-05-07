import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;

  // Sample coordinates (Bangalore)
  static const LatLng _center = LatLng(12.9716, 77.5946);

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Geo-Fencing"),
        backgroundColor: Color(0xFF3E82C6),
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(target: _center, zoom: 15.0),
        markers: {
          Marker(
            markerId: MarkerId("currentLocation"),
            position: _center,
            infoWindow: InfoWindow(title: "You are here"),
          ),
        },
      ),
    );
  }
}
