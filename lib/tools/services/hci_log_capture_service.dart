import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Service to capture and manage HCI Bluetooth logs on Android
/// Requires USB debugging to be enabled
class HciLogCaptureService {
  static const platform = MethodChannel('com.tekneckjoe.tektool/hci_capture');

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Check if HCI logging is enabled on the device
  Future<bool> isHciLoggingEnabled() async {
    try {
      if (!Platform.isAndroid) return false;

      final result = await platform.invokeMethod('checkHciLogging');
      return result == true;
    } catch (e) {
      debugPrint('[HCI] Error checking HCI status: $e');
      return false;
    }
  }

  /// Enable HCI snoop logging (requires developer options)
  Future<bool> enableHciLogging() async {
    try {
      if (!Platform.isAndroid) return false;

      final result = await platform.invokeMethod('enableHciLogging');
      return result == true;
    } catch (e) {
      debugPrint('[HCI] Error enabling HCI: $e');
      return false;
    }
  }

  /// Capture current HCI log from Android system
  /// Returns path to captured file or null if failed
  Future<String?> captureHciLog() async {
    try {
      if (!Platform.isAndroid) {
        throw Exception('HCI capture only available on Android');
      }

      // Call platform method to extract HCI log via bugreport
      final String? logPath = await platform.invokeMethod('captureHciLog');

      if (logPath != null && File(logPath).existsSync()) {
        return logPath;
      }

      return null;
    } catch (e) {
      debugPrint('[HCI] Error capturing log: $e');
      return null;
    }
  }

  /// Parse HCI log and extract Testo/Fieldpiece device data
  Future<HciLogData?> parseHciLog(String logPath) async {
    try {
      final file = File(logPath);
      if (!file.existsSync()) {
        debugPrint('[HCI] File not found: $logPath');
        return null;
      }

      final bytes = await file.readAsBytes();
      debugPrint('[HCI] Read ${bytes.length} bytes from HCI log');

      if (bytes.isEmpty) {
        debugPrint('[HCI] HCI log file is empty');
        return null;
      }

      final devices = <HciDevice>[];
      final packets = <HciPacket>[];

      // Parse btsnoop_hci.log format
      // Header: "btsnoop\0" (8 bytes) + version (4 bytes) + type (4 bytes)
      if (bytes.length < 16) {
        debugPrint(
            '[HCI] File too small (${bytes.length} bytes, need at least 16)');
        return null;
      }

      // Verify header
      final header = String.fromCharCodes(bytes.sublist(0, 8));
      debugPrint('[HCI] File header: "$header"');

      if (!header.startsWith('btsnoop')) {
        debugPrint('[HCI] Invalid btsnoop header');
        return null;
      }

      int offset = 16; // Skip header
      int packetCount = 0;

      // Parse packets
      while (offset < bytes.length - 24) {
        try {
          // Packet record structure:
          // - Original length (4 bytes)
          // - Included length (4 bytes)
          // - Flags (4 bytes)
          // - Cumulative drops (4 bytes)
          // - Timestamp (8 bytes)
          // - Data (variable)

          // final origLen = _readUint32BE(bytes, offset);
          final inclLen = _readUint32BE(bytes, offset + 4);
          // final flags = _readUint32BE(bytes, offset + 8);
          final timestamp = _readUint64BE(bytes, offset + 16);

          if (inclLen > 0 && offset + 24 + inclLen <= bytes.length) {
            final data = bytes.sublist(offset + 24, offset + 24 + inclLen);

            // Parse HCI packet
            final packet = _parseHciPacket(data, timestamp);
            if (packet != null) {
              packets.add(packet);

              // Extract device info if advertisement
              final device = _extractDeviceInfo(packet);
              if (device != null &&
                  !devices.any((d) => d.address == device.address)) {
                devices.add(device);
              }
            }

            offset += 24 + inclLen;
            packetCount++;
          } else {
            break;
          }
        } catch (e) {
          debugPrint('[HCI] Parse error at offset $offset: $e');
          break;
        }
      }

      debugPrint(
          '[HCI] Parsed $packetCount packets, found ${devices.length} devices');

      return HciLogData(
        filePath: logPath,
        fileSize: bytes.length,
        capturedAt: DateTime.now(),
        devices: devices,
        packets: packets,
        totalPackets: packets.length,
      );
    } catch (e) {
      debugPrint('[HCI] Error parsing log: $e');
      return null;
    }
  }

  /// Upload HCI log to Firebase Storage and metadata to Firestore
  Future<String?> uploadToFirebase(HciLogData logData, String userId) async {
    try {
      final sessionId = 'hci_${DateTime.now().millisecondsSinceEpoch}';
      final file = File(logData.filePath);

      if (!file.existsSync()) {
        throw Exception('HCI log file not found');
      }

      // Upload file to Storage
      final storageRef =
          _storage.ref().child('hci_logs/$userId/$sessionId/btsnoop_hci.log');
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Save metadata to Firestore
      await _firestore.collection('ble_sniff_logs').doc(sessionId).set({
        'sessionId': sessionId,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'capturedAt': logData.capturedAt.toIso8601String(),
        'fileSize': logData.fileSize,
        'filePath': downloadUrl,
        'devices': logData.devices.map((d) => d.toMap()).toList(),
        'totalPackets': logData.totalPackets,
        'deviceCount': logData.devices.length,
        'metadata': {
          'appVersion': '1.0.0',
          'platform': Platform.operatingSystem,
          'osVersion': Platform.operatingSystemVersion,
        },
      });

      debugPrint('[HCI] Uploaded to Firebase: $sessionId');
      return sessionId;
    } catch (e) {
      debugPrint('[HCI] Upload error: $e');
      return null;
    }
  }

  // Helper methods

  int _readUint32BE(List<int> bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  int _readUint64BE(List<int> bytes, int offset) {
    return (bytes[offset] << 56) |
        (bytes[offset + 1] << 48) |
        (bytes[offset + 2] << 40) |
        (bytes[offset + 3] << 32) |
        (bytes[offset + 4] << 24) |
        (bytes[offset + 5] << 16) |
        (bytes[offset + 6] << 8) |
        bytes[offset + 7];
  }

  HciPacket? _parseHciPacket(List<int> data, int timestamp) {
    if (data.isEmpty) return null;

    final packetType = data[0];

    // HCI Event (0x04) - includes advertisements
    if (packetType == 0x04 && data.length > 2) {
      final eventCode = data[1];

      // LE Meta Event (0x3E)
      if (eventCode == 0x3e && data.length > 3) {
        final subevent = data[3];

        // LE Advertising Report (0x02)
        if (subevent == 0x02) {
          return HciPacket(
            type: 'advertisement',
            timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp ~/ 1000),
            data: data,
            size: data.length,
          );
        }
      }
    }

    return HciPacket(
      type: 'other',
      timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp ~/ 1000),
      data: data,
      size: data.length,
    );
  }

  HciDevice? _extractDeviceInfo(HciPacket packet) {
    if (packet.type != 'advertisement') return null;

    try {
      final data = packet.data;

      // Parse LE Advertising Report structure
      // Skip to advertising data (varies by report type)
      if (data.length < 20) return null;

      // Extract BD_ADDR (6 bytes, usually at offset 7-12)
      final address = data
          .sublist(7, 13)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(':');

      // Extract RSSI (last byte)
      final rssi = data[data.length - 1];

      // Parse advertising data for device name
      String? name;
      for (int i = 14; i < data.length - 1;) {
        final length = data[i];
        if (length == 0 || i + length >= data.length) break;

        final type = data[i + 1];

        // Complete Local Name (0x09) or Shortened Local Name (0x08)
        if (type == 0x09 || type == 0x08) {
          name = String.fromCharCodes(data.sublist(i + 2, i + 1 + length));
          break;
        }

        i += 1 + length;
      }

      // Filter for HVAC tools (Testo, Fieldpiece, etc.)
      if (name != null &&
          (name.toLowerCase().contains('testo') ||
              name.toLowerCase().contains('fieldpiece') ||
              name.toLowerCase().contains('wey-tek') ||
              name.toLowerCase().contains('abm-'))) {
        return HciDevice(
          name: name,
          address: address,
          rssi: rssi,
          firstSeen: packet.timestamp,
          lastSeen: packet.timestamp,
        );
      }
    } catch (e) {
      debugPrint('[HCI] Device extraction error: $e');
    }

    return null;
  }
}

/// Data model for parsed HCI log
class HciLogData {
  final String filePath;
  final int fileSize;
  final DateTime capturedAt;
  final List<HciDevice> devices;
  final List<HciPacket> packets;
  final int totalPackets;

  HciLogData({
    required this.filePath,
    required this.fileSize,
    required this.capturedAt,
    required this.devices,
    required this.packets,
    required this.totalPackets,
  });
}

/// Detected HVAC device from HCI log
class HciDevice {
  final String name;
  final String address;
  final int rssi;
  final DateTime firstSeen;
  final DateTime lastSeen;

  HciDevice({
    required this.name,
    required this.address,
    required this.rssi,
    required this.firstSeen,
    required this.lastSeen,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'rssi': rssi,
        'firstSeen': firstSeen.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
      };
}

/// Individual HCI packet
class HciPacket {
  final String type;
  final DateTime timestamp;
  final List<int> data;
  final int size;

  HciPacket({
    required this.type,
    required this.timestamp,
    required this.data,
    required this.size,
  });
}
