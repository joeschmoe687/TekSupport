import 'package:geolocator/geolocator.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Service to determine if call recording is allowed based on user's geographic location
/// Disables recording in strict-consent countries (EU, Canada, Australia, etc.)
class CallRecordingGeoService {
  static const platform = MethodChannel('com.tekneck.hvac/geo');

  // Countries/regions with strict call recording laws (two-party consent, GDPR, etc.)
  static const Set<String> strictConsentCountries = {
    'DE', // Germany - GDPR + strict data protection
    'AT', // Austria
    'BE', // Belgium
    'BG', // Bulgaria
    'HR', // Croatia
    'CY', // Cyprus
    'CZ', // Czech Republic
    'DK', // Denmark
    'EE', // Estonia
    'FI', // Finland
    'FR', // France
    'GR', // Greece
    'HU', // Hungary
    'IE', // Ireland
    'IT', // Italy
    'LV', // Latvia
    'LT', // Lithuania
    'LU', // Luxembourg
    'MT', // Malta
    'NL', // Netherlands
    'PL', // Poland
    'PT', // Portugal
    'RO', // Romania
    'SK', // Slovakia
    'SI', // Slovenia
    'ES', // Spain
    'SE', // Sweden
    'GB', // United Kingdom (post-Brexit GDPR)
    'CH', // Switzerland
    'CA', // Canada - two-party consent
    'AU', // Australia - Telecommunications Act
    'NZ', // New Zealand
  };

  /// Get user's country code via device locale or IP geolocation
  /// Returns country code (e.g., 'US', 'CA', 'DE') or null if unable to determine
  static Future<String?> getUserCountryCode() async {
    try {
      // First try device locale
      final deviceCountry = _getDeviceLocaleCountry();
      if (deviceCountry != null) return deviceCountry;

      // Fallback: try IP geolocation via platform channel
      final countryCode = await platform.invokeMethod<String>('getCountryCode');
      return countryCode;
    } catch (e) {
      print('Error getting country code: $e');
      return null;
    }
  }

  /// Extract country code from device locale
  static String? _getDeviceLocaleCountry() {
    try {
      final locale = Platform.localeName; // e.g., 'en_US', 'de_DE'
      if (locale.contains('_')) {
        return locale.split('_')[1].toUpperCase();
      }
    } catch (e) {
      print('Error extracting locale country: $e');
    }
    return null;
  }

  /// Check if call recording is allowed in user's location
  /// Returns true if recording is permitted, false if in strict-consent region
  static Future<bool> isCallRecordingAllowed() async {
    final countryCode = await getUserCountryCode();
    if (countryCode == null) {
      // If unable to determine location, default to conservative: disable recording
      return false;
    }

    // Recording disabled in strict-consent countries
    if (strictConsentCountries.contains(countryCode)) {
      print(
          'Call recording disabled: User in strict-consent country ($countryCode)');
      return false;
    }

    print('Call recording allowed: User country code $countryCode');
    return true;
  }

  /// Get precise coordinates for location verification
  /// Used for additional compliance verification
  static Future<Position?> getUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.denied) {
          print('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      return position;
    } catch (e) {
      print('Error getting user location: $e');
      return null;
    }
  }

  /// Add or remove a country from restricted list (admin override)
  static void addRestrictedCountry(String countryCode) {
    strictConsentCountries.add(countryCode.toUpperCase());
  }

  static void removeRestrictedCountry(String countryCode) {
    strictConsentCountries.remove(countryCode.toUpperCase());
  }

  /// Get list of all restricted countries
  static List<String> getRestrictedCountries() {
    return strictConsentCountries.toList()..sort();
  }
}
