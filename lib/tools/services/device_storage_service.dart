import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting BLE device data locally.
/// Stores paired devices, connection history, and learned patterns.
class DeviceStorageService {
  static final DeviceStorageService _instance =
      DeviceStorageService._internal();
  factory DeviceStorageService() => _instance;
  DeviceStorageService._internal();

  static const String _pairedDevicesKey = 'paired_devices';
  static const String _connectionHistoryKey = 'connection_history';
  static const String _learnedPatternsKey = 'learned_patterns';
  static const String _deviceProfilesKey = 'device_profiles';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ============ PAIRED DEVICES ============

  /// Save a device to paired devices list
  Future<void> saveDevice(SavedDevice device) async {
    await init();
    final devices = await getSavedDevices();

    // Update existing or add new
    final existingIndex =
        devices.indexWhere((d) => d.remoteId == device.remoteId);
    if (existingIndex >= 0) {
      devices[existingIndex] = device;
    } else {
      devices.add(device);
    }

    await _prefs!.setString(
      _pairedDevicesKey,
      jsonEncode(devices.map((d) => d.toJson()).toList()),
    );
  }

  /// Get all saved/paired devices
  Future<List<SavedDevice>> getSavedDevices() async {
    await init();
    final json = _prefs!.getString(_pairedDevicesKey);
    if (json == null || json.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(json);
      return list.map((j) => SavedDevice.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Remove a device from saved list
  Future<void> removeDevice(String remoteId) async {
    await init();
    final devices = await getSavedDevices();
    devices.removeWhere((d) => d.remoteId == remoteId);
    await _prefs!.setString(
      _pairedDevicesKey,
      jsonEncode(devices.map((d) => d.toJson()).toList()),
    );
  }

  /// Update last seen time for a device
  Future<void> updateLastSeen(String remoteId) async {
    final devices = await getSavedDevices();
    final index = devices.indexWhere((d) => d.remoteId == remoteId);
    if (index >= 0) {
      devices[index] = devices[index].copyWith(lastSeen: DateTime.now());
      await _prefs!.setString(
        _pairedDevicesKey,
        jsonEncode(devices.map((d) => d.toJson()).toList()),
      );
    }
  }

  // ============ CONNECTION HISTORY ============

  /// Log a connection event
  Future<void> logConnection(ConnectionEvent event) async {
    await init();
    final history = await getConnectionHistory();
    history.add(event);

    // Keep last 100 events
    if (history.length > 100) {
      history.removeRange(0, history.length - 100);
    }

    await _prefs!.setString(
      _connectionHistoryKey,
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }

  /// Get connection history
  Future<List<ConnectionEvent>> getConnectionHistory() async {
    await init();
    final json = _prefs!.getString(_connectionHistoryKey);
    if (json == null || json.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(json);
      return list.map((j) => ConnectionEvent.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  // ============ LEARNED PATTERNS (ML) ============

  /// Save learned data patterns from BLE sniffing
  Future<void> saveLearnedPattern(LearnedPattern pattern) async {
    await init();
    final patterns = await getLearnedPatterns();

    // Update existing or add new
    final existingIndex = patterns.indexWhere(
      (p) =>
          p.deviceName == pattern.deviceName &&
          p.characteristicUuid == pattern.characteristicUuid,
    );
    if (existingIndex >= 0) {
      patterns[existingIndex] = pattern;
    } else {
      patterns.add(pattern);
    }

    await _prefs!.setString(
      _learnedPatternsKey,
      jsonEncode(patterns.map((p) => p.toJson()).toList()),
    );
  }

  /// Get all learned patterns
  Future<List<LearnedPattern>> getLearnedPatterns() async {
    await init();
    final json = _prefs!.getString(_learnedPatternsKey);
    if (json == null || json.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(json);
      return list.map((j) => LearnedPattern.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear all learned patterns
  Future<void> clearLearnedPatterns() async {
    await init();
    await _prefs!.remove(_learnedPatternsKey);
  }

  // ============ CUSTOM DEVICE PROFILES ============

  /// Save a custom device profile (from sniffer)
  Future<void> saveDeviceProfile(CustomDeviceProfile profile) async {
    await init();
    final profiles = await getDeviceProfiles();

    final existingIndex = profiles.indexWhere((p) => p.id == profile.id);
    if (existingIndex >= 0) {
      profiles[existingIndex] = profile;
    } else {
      profiles.add(profile);
    }

    await _prefs!.setString(
      _deviceProfilesKey,
      jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );
  }

  /// Get all custom device profiles
  Future<List<CustomDeviceProfile>> getDeviceProfiles() async {
    await init();
    final json = _prefs!.getString(_deviceProfilesKey);
    if (json == null || json.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(json);
      return list.map((j) => CustomDeviceProfile.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete a custom profile
  Future<void> deleteDeviceProfile(String id) async {
    await init();
    final profiles = await getDeviceProfiles();
    profiles.removeWhere((p) => p.id == id);
    await _prefs!.setString(
      _deviceProfilesKey,
      jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );
  }

  // ============ STORAGE STATS ============

  /// Get storage statistics for display
  Future<StorageStats> getStorageStats() async {
    await init();

    final devices = await getSavedDevices();
    final history = await getConnectionHistory();
    final patterns = await getLearnedPatterns();
    final profiles = await getDeviceProfiles();

    // Calculate approximate storage size
    int totalBytes = 0;
    totalBytes += _prefs!.getString(_pairedDevicesKey)?.length ?? 0;
    totalBytes += _prefs!.getString(_connectionHistoryKey)?.length ?? 0;
    totalBytes += _prefs!.getString(_learnedPatternsKey)?.length ?? 0;
    totalBytes += _prefs!.getString(_deviceProfilesKey)?.length ?? 0;

    return StorageStats(
      deviceCount: devices.length,
      historyCount: history.length,
      patternCount: patterns.length,
      profileCount: profiles.length,
      totalBytes: totalBytes,
    );
  }

  /// Clear all stored data
  Future<void> clearAllData() async {
    await init();
    await _prefs!.remove(_pairedDevicesKey);
    await _prefs!.remove(_connectionHistoryKey);
    await _prefs!.remove(_learnedPatternsKey);
    await _prefs!.remove(_deviceProfilesKey);
  }
}

// ============ DATA MODELS ============

/// Saved device information for persistence
class SavedDevice {
  final String remoteId;
  final String name;
  final String manufacturer;
  final String deviceType;
  final String unit;
  final DateTime firstPaired;
  final DateTime lastSeen;
  final bool autoReconnect;
  final String? serviceUuid;
  final String? characteristicUuid;

  SavedDevice({
    required this.remoteId,
    required this.name,
    required this.manufacturer,
    required this.deviceType,
    required this.unit,
    required this.firstPaired,
    required this.lastSeen,
    this.autoReconnect = true,
    this.serviceUuid,
    this.characteristicUuid,
  });

  SavedDevice copyWith({
    String? remoteId,
    String? name,
    String? manufacturer,
    String? deviceType,
    String? unit,
    DateTime? firstPaired,
    DateTime? lastSeen,
    bool? autoReconnect,
    String? serviceUuid,
    String? characteristicUuid,
  }) {
    return SavedDevice(
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      deviceType: deviceType ?? this.deviceType,
      unit: unit ?? this.unit,
      firstPaired: firstPaired ?? this.firstPaired,
      lastSeen: lastSeen ?? this.lastSeen,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      characteristicUuid: characteristicUuid ?? this.characteristicUuid,
    );
  }

  Map<String, dynamic> toJson() => {
        'remoteId': remoteId,
        'name': name,
        'manufacturer': manufacturer,
        'deviceType': deviceType,
        'unit': unit,
        'firstPaired': firstPaired.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
        'autoReconnect': autoReconnect,
        'serviceUuid': serviceUuid,
        'characteristicUuid': characteristicUuid,
      };

  factory SavedDevice.fromJson(Map<String, dynamic> json) => SavedDevice(
        remoteId: json['remoteId'] ?? '',
        name: json['name'] ?? 'Unknown',
        manufacturer: json['manufacturer'] ?? 'unknown',
        deviceType: json['deviceType'] ?? 'unknown',
        unit: json['unit'] ?? '',
        firstPaired:
            DateTime.tryParse(json['firstPaired'] ?? '') ?? DateTime.now(),
        lastSeen: DateTime.tryParse(json['lastSeen'] ?? '') ?? DateTime.now(),
        autoReconnect: json['autoReconnect'] ?? true,
        serviceUuid: json['serviceUuid'],
        characteristicUuid: json['characteristicUuid'],
      );
}

/// Connection event for history tracking
class ConnectionEvent {
  final String remoteId;
  final String deviceName;
  final DateTime timestamp;
  final String eventType; // 'connected', 'disconnected', 'failed'
  final String? reason;
  final int? rssi;

  ConnectionEvent({
    required this.remoteId,
    required this.deviceName,
    required this.timestamp,
    required this.eventType,
    this.reason,
    this.rssi,
  });

  Map<String, dynamic> toJson() => {
        'remoteId': remoteId,
        'deviceName': deviceName,
        'timestamp': timestamp.toIso8601String(),
        'eventType': eventType,
        'reason': reason,
        'rssi': rssi,
      };

  factory ConnectionEvent.fromJson(Map<String, dynamic> json) =>
      ConnectionEvent(
        remoteId: json['remoteId'] ?? '',
        deviceName: json['deviceName'] ?? 'Unknown',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        eventType: json['eventType'] ?? 'unknown',
        reason: json['reason'],
        rssi: json['rssi'],
      );
}

/// Learned data pattern from ML analysis
class LearnedPattern {
  final String deviceName;
  final String serviceUuid;
  final String characteristicUuid;
  final String dataType; // 'temperature', 'pressure', 'voltage', etc.
  final String parseMethod; // 'int16_le_div10', 'float32_le', etc.
  final String unit;
  final int confidence; // 0-100
  final DateTime learnedAt;
  final List<String> sampleValues;

  LearnedPattern({
    required this.deviceName,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.dataType,
    required this.parseMethod,
    required this.unit,
    required this.confidence,
    required this.learnedAt,
    this.sampleValues = const [],
  });

  Map<String, dynamic> toJson() => {
        'deviceName': deviceName,
        'serviceUuid': serviceUuid,
        'characteristicUuid': characteristicUuid,
        'dataType': dataType,
        'parseMethod': parseMethod,
        'unit': unit,
        'confidence': confidence,
        'learnedAt': learnedAt.toIso8601String(),
        'sampleValues': sampleValues,
      };

  factory LearnedPattern.fromJson(Map<String, dynamic> json) => LearnedPattern(
        deviceName: json['deviceName'] ?? '',
        serviceUuid: json['serviceUuid'] ?? '',
        characteristicUuid: json['characteristicUuid'] ?? '',
        dataType: json['dataType'] ?? 'unknown',
        parseMethod: json['parseMethod'] ?? 'raw',
        unit: json['unit'] ?? '',
        confidence: json['confidence'] ?? 0,
        learnedAt: DateTime.tryParse(json['learnedAt'] ?? '') ?? DateTime.now(),
        sampleValues: List<String>.from(json['sampleValues'] ?? []),
      );
}

/// Custom device profile saved from sniffer
class CustomDeviceProfile {
  final String id;
  final String name;
  final String manufacturer;
  final String type;
  final String serviceUuid;
  final String characteristicUuid;
  final String parseMethod;
  final String unit;
  final DateTime createdAt;
  final String? notes;

  CustomDeviceProfile({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.type,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.parseMethod,
    required this.unit,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'manufacturer': manufacturer,
        'type': type,
        'serviceUuid': serviceUuid,
        'characteristicUuid': characteristicUuid,
        'parseMethod': parseMethod,
        'unit': unit,
        'createdAt': createdAt.toIso8601String(),
        'notes': notes,
      };

  factory CustomDeviceProfile.fromJson(Map<String, dynamic> json) =>
      CustomDeviceProfile(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Unknown',
        manufacturer: json['manufacturer'] ?? 'unknown',
        type: json['type'] ?? 'unknown',
        serviceUuid: json['serviceUuid'] ?? '',
        characteristicUuid: json['characteristicUuid'] ?? '',
        parseMethod: json['parseMethod'] ?? 'raw',
        unit: json['unit'] ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        notes: json['notes'],
      );
}

/// Storage statistics
class StorageStats {
  final int deviceCount;
  final int historyCount;
  final int patternCount;
  final int profileCount;
  final int totalBytes;

  StorageStats({
    required this.deviceCount,
    required this.historyCount,
    required this.patternCount,
    required this.profileCount,
    required this.totalBytes,
  });

  String get formattedSize {
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024)
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
