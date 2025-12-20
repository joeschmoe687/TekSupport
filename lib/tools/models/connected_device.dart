import '../services/device_registry.dart';

/// Model representing a connected HVAC Bluetooth device
class ConnectedDevice {
  final String id;
  final String name;
  final HvacManufacturer manufacturer;
  final HvacDeviceType type;
  final String unit;
  double currentReading;
  double? zeroOffset;
  int? batteryLevel;
  bool isConnected;
  DateTime? lastUpdate;

  ConnectedDevice({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.type,
    required this.unit,
    this.currentReading = 0.0,
    this.zeroOffset,
    this.batteryLevel,
    this.isConnected = false,
    this.lastUpdate,
  });

  /// Get the zeroed reading (current - offset)
  double get zeroedReading => currentReading - (zeroOffset ?? 0);

  /// Display string for the reading
  String get displayReading => '${zeroedReading.toStringAsFixed(1)} $unit';

  /// Icon for the device type
  String get iconName {
    switch (type) {
      case HvacDeviceType.refrigerantGauge:
        return 'gauge';
      case HvacDeviceType.temperatureProbe:
        return 'thermostat';
      case HvacDeviceType.refrigerantScale:
        return 'scale';
      case HvacDeviceType.airflowMeter:
        return 'air';
      case HvacDeviceType.pressureProbe:
        return 'compress';
      case HvacDeviceType.clampMeter:
        return 'bolt';
      case HvacDeviceType.vacuumGauge:
        return 'speed';
      default:
        return 'devices';
    }
  }

  /// Manufacturer logo/color
  String get manufacturerName {
    switch (manufacturer) {
      case HvacManufacturer.weytek:
        return 'Weytek';
      case HvacManufacturer.ccs:
        return 'CCS';
      case HvacManufacturer.testo:
        return 'Testo';
      case HvacManufacturer.fieldpiece:
        return 'Fieldpiece';
      case HvacManufacturer.parker:
        return 'Parker';
      case HvacManufacturer.yellowJacket:
        return 'Yellow Jacket';
      default:
        return 'Unknown';
    }
  }
}

/// Model for current job/unit context
class JobContext {
  final String? jobId;
  final String? unitName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? equipmentBrand;
  final String? equipmentModel;
  final String? serialNumber;

  const JobContext({
    this.jobId,
    this.unitName,
    this.address,
    this.latitude,
    this.longitude,
    this.equipmentBrand,
    this.equipmentModel,
    this.serialNumber,
  });

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasEquipment => equipmentBrand != null || equipmentModel != null;
}
