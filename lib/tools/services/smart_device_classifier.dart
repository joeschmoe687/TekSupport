import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;

/// Smart device classifier using pattern matching and heuristics
/// Identifies HVAC tools even when they're completely unknown
class SmartDeviceClassifier {
  /// Classify a device based on all available information
  static DeviceClassification classifyDevice({
    required String deviceName,
    required List<ble.Guid> serviceUuids,
    required Map<int, List<int>> manufacturerData,
    required String macAddress,
    required bool connectable,
    Map<ble.Guid, List<int>>? serviceData,
  }) {
    final features = _extractFeatures(
      deviceName: deviceName,
      serviceUuids: serviceUuids,
      manufacturerData: manufacturerData,
      macAddress: macAddress,
      connectable: connectable,
      serviceData: serviceData,
    );

    final scores = _calculateScores(features);
    final topCategory = _selectTopCategory(scores);

    return DeviceClassification(
      category: topCategory,
      confidence: scores[topCategory] ?? 0.0,
      manufacturer: _guessManufacturer(features),
      deviceType: _guessSpecificType(features, topCategory),
      connectionType: connectable ? 'GATT' : 'Broadcast-Only',
      features: features,
      allScores: scores,
    );
  }

  /// Extract relevant features from device advertisement
  static DeviceFeatures _extractFeatures({
    required String deviceName,
    required List<ble.Guid> serviceUuids,
    required Map<int, List<int>> manufacturerData,
    required String macAddress,
    required bool connectable,
    Map<ble.Guid, List<int>>? serviceData,
  }) {
    final nameLower = deviceName.toLowerCase();
    final serviceStrings = serviceUuids.map((s) => s.toString().toLowerCase()).toList();

    // Name-based features
    final nameFeatures = <String, bool>{
      'has_temp_keyword': nameLower.contains('temp') || nameLower.contains('therm'),
      'has_pressure_keyword': nameLower.contains('press') || nameLower.contains('psig'),
      'has_scale_keyword': nameLower.contains('scale') || nameLower.contains('weight'),
      'has_airflow_keyword': nameLower.contains('air') || nameLower.contains('flow') || nameLower.contains('cfm') || nameLower.contains('fpm'),
      'has_clamp_keyword': nameLower.contains('clamp') || nameLower.contains('meter'),
      'has_vacuum_keyword': nameLower.contains('vacuum') || nameLower.contains('micron'),
      'has_gauge_keyword': nameLower.contains('gauge') || nameLower.contains('manifold'),
      'has_probe_keyword': nameLower.contains('probe') || nameLower.contains('sensor'),
    };

    // Brand identification
    final knownBrands = <String, String>{
      'testo': 'Testo AG',
      't115': 'Testo AG',
      't549': 'Testo AG',
      't550': 'Testo AG',
      't605': 'Testo AG',
      't770': 'Testo AG',
      'fieldpiece': 'Fieldpiece',
      'jl3': 'Fieldpiece',
      'sman': 'Fieldpiece',
      'sdp': 'Fieldpiece',
      'srp': 'Fieldpiece',
      'srs': 'Fieldpiece',
      'job': 'Fieldpiece',
      'wey-tek': 'Wey-Tek/Inficon',
      'weytek': 'Wey-Tek/Inficon',
      'inficon': 'Wey-Tek/Inficon',
      'abm': 'CPS/AAB/WeatherFlow',
      'aab': 'CPS/AAB/WeatherFlow',
      'weatherflow': 'WeatherFlow',
      'navac': 'Navac',
      'yellow jacket': 'Yellow Jacket',
      'yj': 'Yellow Jacket',
      'robinair': 'Robinair',
      'mastercool': 'Mastercool',
      'supco': 'Supco',
      'uei': 'UEi Test',
      'cps': 'CPS Products',
    };

    String? detectedBrand;
    for (final entry in knownBrands.entries) {
      if (nameLower.contains(entry.key)) {
        detectedBrand = entry.value;
        break;
      }
    }

    // Service UUID analysis
    final serviceFeatures = <String, bool>{
      'has_device_info': serviceStrings.any((s) => s.contains('180a')),
      'has_battery_service': serviceStrings.any((s) => s.contains('180f')),
      'has_testo_service': serviceStrings.any((s) => s.contains('fff0')),
      'has_weytek_service': serviceStrings.any((s) => s.contains('e3b744f3')),
      'has_abm200_service': serviceStrings.any((s) => s.contains('961f0001')),
      'has_health_therm': serviceStrings.any((s) => s.contains('1809')),
    };

    // Manufacturer data analysis
    final manufacturerFeatures = <String, bool>{
      'has_manufacturer_data': manufacturerData.isNotEmpty,
      'is_fieldpiece': manufacturerData.containsKey(0x5046),
      'is_testo': manufacturerData.containsKey(0x02E1),
      'is_weytek': manufacturerData.containsKey(0x0806),
      'is_cps': manufacturerData.containsKey(0x05A7),
      'is_weatherflow': manufacturerData.containsKey(0x0A55),
      'is_yellow_jacket': manufacturerData.containsKey(0x0310),
    };

    // MAC address OUI analysis
    final macParts = macAddress.split(':');
    final oui = macParts.length >= 3 ? '${macParts[0]}:${macParts[1]}:${macParts[2]}'.toUpperCase() : '';
    
    final ouiFeatures = <String, bool>{
      'is_ti_chip': ['84:C6:92', '04:E9:E5', '34:B1:F7', '7C:EC:79', '98:07:2D', 'B0:B4:48', 'D4:F5:13'].contains(oui),
      'is_nordic_chip': ['C7:16:86', 'D5:26:21', 'E7:25:7B', 'F4:1B:F3'].contains(oui),
      'is_esp32_chip': ['24:0A:C4', '30:AE:A4', 'A4:CF:12'].contains(oui),
    };

    // Service data patterns
    int serviceDataSize = 0;
    if (serviceData != null) {
      for (final data in serviceData.values) {
        serviceDataSize += data.length;
      }
    }

    return DeviceFeatures(
      deviceName: deviceName,
      detectedBrand: detectedBrand,
      nameFeatures: nameFeatures,
      serviceFeatures: serviceFeatures,
      manufacturerFeatures: manufacturerFeatures,
      ouiFeatures: ouiFeatures,
      connectable: connectable,
      serviceCount: serviceUuids.length,
      manufacturerDataSize: manufacturerData.values.fold(0, (sum, data) => sum + data.length),
      serviceDataSize: serviceDataSize,
      macOui: oui,
    );
  }

  /// Calculate confidence scores for each device category
  static Map<String, double> _calculateScores(DeviceFeatures features) {
    final scores = <String, double>{
      'temperature_probe': 0.0,
      'pressure_probe': 0.0,
      'refrigerant_scale': 0.0,
      'airflow_meter': 0.0,
      'clamp_meter': 0.0,
      'vacuum_gauge': 0.0,
      'manifold_gauge': 0.0,
      'psychrometer': 0.0,
      'thermal_imager': 0.0,
      'unknown_hvac': 0.0,
      'consumer_device': 0.0,
    };

    // Temperature probe scoring
    if (features.nameFeatures['has_temp_keyword'] == true) scores['temperature_probe'] = scores['temperature_probe']! + 30.0;
    if (features.nameFeatures['has_probe_keyword'] == true) scores['temperature_probe'] = scores['temperature_probe']! + 15.0;
    if (features.serviceFeatures['has_testo_service'] == true) scores['temperature_probe'] = scores['temperature_probe']! + 25.0;
    if (features.manufacturerFeatures['is_testo'] == true) scores['temperature_probe'] = scores['temperature_probe']! + 20.0;
    if (features.ouiFeatures['is_nordic_chip'] == true) scores['temperature_probe'] = scores['temperature_probe']! + 10.0;

    // Pressure probe scoring
    if (features.nameFeatures['has_pressure_keyword'] == true) scores['pressure_probe'] = scores['pressure_probe']! + 35.0;
    if (features.nameFeatures['has_probe_keyword'] == true) scores['pressure_probe'] = scores['pressure_probe']! + 10.0;
    if (features.manufacturerFeatures['is_fieldpiece'] == true) scores['pressure_probe'] = scores['pressure_probe']! + 20.0;

    // Scale scoring
    if (features.nameFeatures['has_scale_keyword'] == true) scores['refrigerant_scale'] = scores['refrigerant_scale']! + 40.0;
    if (features.serviceFeatures['has_weytek_service'] == true) scores['refrigerant_scale'] = scores['refrigerant_scale']! + 30.0;
    if (features.manufacturerFeatures['is_weytek'] == true) scores['refrigerant_scale'] = scores['refrigerant_scale']! + 25.0;

    // Airflow meter scoring
    if (features.nameFeatures['has_airflow_keyword'] == true) scores['airflow_meter'] = scores['airflow_meter']! + 40.0;
    if (features.serviceFeatures['has_abm200_service'] == true) scores['airflow_meter'] = scores['airflow_meter']! + 35.0;
    if (features.manufacturerFeatures['is_cps'] == true || features.manufacturerFeatures['is_weatherflow'] == true) {
      scores['airflow_meter'] = scores['airflow_meter']! + 25.0;
    }

    // Clamp meter scoring
    if (features.nameFeatures['has_clamp_keyword'] == true) scores['clamp_meter'] = scores['clamp_meter']! + 30.0;
    if (features.manufacturerFeatures['is_fieldpiece'] == true) scores['clamp_meter'] = scores['clamp_meter']! + 15.0;

    // Vacuum gauge scoring
    if (features.nameFeatures['has_vacuum_keyword'] == true) scores['vacuum_gauge'] = scores['vacuum_gauge']! + 40.0;

    // Manifold gauge scoring
    if (features.nameFeatures['has_gauge_keyword'] == true) scores['manifold_gauge'] = scores['manifold_gauge']! + 25.0;
    if (features.manufacturerFeatures['is_fieldpiece'] == true || features.manufacturerFeatures['is_yellow_jacket'] == true) {
      scores['manifold_gauge'] = scores['manifold_gauge']! + 20.0;
    }

    // Generic HVAC device (fallback if has HVAC indicators but unclear type)
    if (features.detectedBrand != null) scores['unknown_hvac'] = scores['unknown_hvac']! + 20.0;
    if (features.ouiFeatures['is_ti_chip'] == true) scores['unknown_hvac'] = scores['unknown_hvac']! + 15.0;
    if (features.serviceFeatures['has_battery_service'] == true) scores['unknown_hvac'] = scores['unknown_hvac']! + 10.0;

    // Consumer device indicators (negative scoring for HVAC)
    if (!features.connectable) {
      // Broadcast-only more common in HVAC tools
      scores['unknown_hvac'] = scores['unknown_hvac']! + 10.0;
    }
    if (features.serviceCount > 10) {
      // Too many services suggests phone/watch/earbuds
      scores['consumer_device'] = scores['consumer_device']! + 30.0;
    }

    // Normalize scores to 0-100 range
    final maxScore = scores.values.fold(0.0, (max, score) => score > max ? score : max);
    if (maxScore > 0) {
      for (final key in scores.keys) {
        scores[key] = (scores[key]! / maxScore) * 100.0;
      }
    }

    return scores;
  }

  /// Select the top category from scores
  static String _selectTopCategory(Map<String, double> scores) {
    double maxScore = 0.0;
    String topCategory = 'unknown_hvac';

    for (final entry in scores.entries) {
      if (entry.value > maxScore && entry.key != 'consumer_device') {
        maxScore = entry.value;
        topCategory = entry.key;
      }
    }

    // If confidence too low, fall back to unknown_hvac
    if (maxScore < 20.0) return 'unknown_hvac';

    return topCategory;
  }

  /// Guess manufacturer from features
  static String? _guessManufacturer(DeviceFeatures features) {
    if (features.detectedBrand != null) return features.detectedBrand;

    if (features.manufacturerFeatures['is_fieldpiece'] == true) return 'Fieldpiece';
    if (features.manufacturerFeatures['is_testo'] == true) return 'Testo AG';
    if (features.manufacturerFeatures['is_weytek'] == true) return 'Wey-Tek/Inficon';
    if (features.manufacturerFeatures['is_cps'] == true) return 'CPS Products';
    if (features.manufacturerFeatures['is_weatherflow'] == true) return 'WeatherFlow';
    if (features.manufacturerFeatures['is_yellow_jacket'] == true) return 'Yellow Jacket';

    // Guess from chip manufacturer
    if (features.ouiFeatures['is_ti_chip'] == true) return 'Unknown (TI BLE chip)';
    if (features.ouiFeatures['is_nordic_chip'] == true) return 'Unknown (Nordic BLE chip)';
    if (features.ouiFeatures['is_esp32_chip'] == true) return 'Unknown (ESP32 chip)';

    return null;
  }

  /// Guess specific device type/model
  static String? _guessSpecificType(DeviceFeatures features, String category) {
    final name = features.deviceName.toLowerCase();

    // Testo models
    if (name.contains('t115')) return 'Testo T115i Temperature Probe';
    if (name.contains('t549') || name.contains('t550')) return 'Testo Pressure Probe';
    if (name.contains('t605')) return 'Testo Humidity Probe';
    if (name.contains('t770') || name.contains('t870')) return 'Testo Thermal Imager';

    // Fieldpiece models
    if (name.contains('jl3')) return 'Fieldpiece JL3 Vacuum Gauge';
    if (name.contains('sman')) return 'Fieldpiece SMAN Manifold';
    if (name.contains('sdp')) return 'Fieldpiece SDP Pressure Probe';
    if (name.contains('srp')) return 'Fieldpiece SRP Psychrometer';
    if (name.contains('srs')) return 'Fieldpiece SRS Refrigerant Scale';

    // Other known models
    if (name.contains('abm-200') || name.contains('abm200')) return 'ABM-200 Airflow Meter';
    if (name == 'scale' && features.serviceFeatures['has_weytek_service'] == true) {
      return 'Wey-Tek HD Refrigerant Scale';
    }

    // Generic types based on category
    switch (category) {
      case 'temperature_probe':
        return features.manufacturer != null 
            ? '${features.manufacturer} Temperature Probe'
            : 'Temperature Probe';
      case 'pressure_probe':
        return features.manufacturer != null
            ? '${features.manufacturer} Pressure Probe'
            : 'Pressure Probe';
      case 'refrigerant_scale':
        return 'Refrigerant Scale';
      case 'airflow_meter':
        return 'Airflow Meter';
      case 'clamp_meter':
        return 'Clamp Meter';
      case 'vacuum_gauge':
        return 'Vacuum Gauge';
      case 'manifold_gauge':
        return 'Manifold Gauge';
      default:
        return null;
    }
  }
}

/// Device features extracted from advertisement
class DeviceFeatures {
  final String deviceName;
  final String? detectedBrand;
  final Map<String, bool> nameFeatures;
  final Map<String, bool> serviceFeatures;
  final Map<String, bool> manufacturerFeatures;
  final Map<String, bool> ouiFeatures;
  final bool connectable;
  final int serviceCount;
  final int manufacturerDataSize;
  final int serviceDataSize;
  final String macOui;

  DeviceFeatures({
    required this.deviceName,
    this.detectedBrand,
    required this.nameFeatures,
    required this.serviceFeatures,
    required this.manufacturerFeatures,
    required this.ouiFeatures,
    required this.connectable,
    required this.serviceCount,
    required this.manufacturerDataSize,
    required this.serviceDataSize,
    required this.macOui,
  });

  /// Get manufacturer (detected brand or null)
  String? get manufacturer => detectedBrand;
}

/// Classification result
class DeviceClassification {
  final String category;
  final double confidence;
  final String? manufacturer;
  final String? deviceType;
  final String connectionType;
  final DeviceFeatures features;
  final Map<String, double> allScores;

  DeviceClassification({
    required this.category,
    required this.confidence,
    this.manufacturer,
    this.deviceType,
    required this.connectionType,
    required this.features,
    required this.allScores,
  });

  String get categoryDisplay {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String get confidenceDisplay {
    if (confidence >= 80) return 'Very High';
    if (confidence >= 60) return 'High';
    if (confidence >= 40) return 'Medium';
    if (confidence >= 20) return 'Low';
    return 'Very Low';
  }

  /// Get a human-readable summary
  String get summary {
    final parts = <String>[];
    
    if (deviceType != null) {
      parts.add(deviceType!);
    } else {
      parts.add(categoryDisplay);
    }
    
    if (manufacturer != null) {
      parts.add('($manufacturer)');
    }
    
    parts.add('- ${confidenceDisplay} Confidence');
    
    return parts.join(' ');
  }
}
