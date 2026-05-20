import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class LocationService {
  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Check location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  // Request location permission
  Future<LocationPermission> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission;
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    // Check if location services are enabled
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled');
      return null;
    }

    // Check permission
    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission permanently denied');
      return null;
    }

    // Get position
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  // Get address from coordinates - simplified without geocoding
  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      // Without geocoding package, return coordinates as fallback
      return '$latitude, $longitude';
    } catch (e) {
      debugPrint('Error formatting coordinates: $e');
    }
    return null;
  }

  // Get coordinates from address - not supported without geocoding package
  Future<Position?> getCoordinatesFromAddress(String address) async {
    debugPrint('Address-based coordinates lookup not available');
    return null; // Geocoding not available without external package
  }
}
