import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' show Guid;
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../bluetooth/bluetooth_service.dart';
import '../services/refrigerant_detector.dart';
import '../services/device_data_service.dart';
import '../services/device_registry.dart';
import '../services/auto_reconnect_service.dart';
import '../services/device_storage_service.dart';
import '../services/calibration_service.dart';
import '../services/diagnostic_engine.dart';
import '../services/ml_data_service.dart';
import '../models/hvac_reading.dart';
import '../widgets/calibration_popup.dart';
import '../widgets/diagnostic_card.dart';
import '../widgets/troubleshooting_sheet.dart';
import '../utils/pt_chart.dart';
import 'dart:math' as math;

/// Gauge slot types for sensor assignment
enum GaugeSlot {
  lowSidePressure,
  highSidePressure,
  suctionLineTemp,
  liquidLineTemp,
  supplyAirTemp,
  returnAirTemp,
}

/// Gauge display mode
enum GaugeDisplayMode {
  digital, // Default: Digital box layout
  analog,  // Classic round analog gauge
}

/// Job types for gauge configuration
enum JobType {
  airConditioning,
  heatPump,
  refrigerationCooler,
  refrigerationFreezer,
  refrigerationIceMachine,
}

extension JobTypeExtension on JobType {
  String get displayName {
    switch (this) {
      case JobType.airConditioning:
        return 'Air Conditioning';
      case JobType.heatPump:
        return 'Heat Pump';
      case JobType.refrigerationCooler:
        return 'Refrigeration - Cooler';
      case JobType.refrigerationFreezer:
        return 'Refrigeration - Freezer';
      case JobType.refrigerationIceMachine:
        return 'Refrigeration - Ice Machine';
    }
  }

  IconData get icon {
    switch (this) {
      case JobType.airConditioning:
        return Icons.ac_unit;
      case JobType.heatPump:
        return Icons.heat_pump;
      case JobType.refrigerationCooler:
        return Icons.kitchen;
      case JobType.refrigerationFreezer:
        return Icons.severe_cold;
      case JobType.refrigerationIceMachine:
        return Icons.icecream;
    }
  }

  bool get isRefrigeration {
    return this == JobType.refrigerationCooler ||
        this == JobType.refrigerationFreezer ||
        this == JobType.refrigerationIceMachine;
  }
}

/// Gauge screen - displays pressure readings with superheat/subcool calculations
class GaugeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const GaugeScreen({super.key, required this.onToggleTheme});

  @override
  State<GaugeScreen> createState() => _GaugeScreenState();
}

class _GaugeScreenState extends State<GaugeScreen> {
  final BluetoothService _bleService = BluetoothService();
  final DeviceDataService _dataService = DeviceDataService();
  final AutoReconnectService _reconnectService = AutoReconnectService();
  final DeviceStorageService _storageService = DeviceStorageService();
  final DeviceRegistry _registry = DeviceRegistry();
  final PTChart _ptChart = PTChart();
  final CalibrationService _calibrationService = CalibrationService();
  final DiagnosticEngine _diagnosticEngine = DiagnosticEngine();
  final MLDataService _mlDataService = MLDataService();

  // Global keys for calibration popup positioning
  final GlobalKey _highSidePressureKey = GlobalKey();
  final GlobalKey _lowSidePressureKey = GlobalKey();
  final GlobalKey _suctionLineTempKey = GlobalKey();
  final GlobalKey _liquidLineTempKey = GlobalKey();

  // Current refrigerant selection
  Refrigerant _currentRefrigerant = Refrigerant.r410a;

  // Current readings (raw values before calibration)
  double _highSidePressure = 0.0;
  double _lowSidePressure = 0.0;
  double _liquidLineTemp = 0.0;
  double _suctionLineTemp = 0.0;
  double _supplyAirTemp = 0.0;
  double _returnAirTemp = 0.0;

  // Sensor assignments: slot -> deviceId
  final Map<GaugeSlot, String> _sensorAssignments = {};

  // Device names for display
  final Map<String, String> _deviceNames = {};

  // Zero offsets per sensor (deviceId -> offset in mbar)
  final Map<String, double> _zeroOffsets = {};

  // Battery levels per device (deviceId -> level 0-100)
  final Map<String, int> _batteryLevels = {};

  // Calculated values
  double? _superheat;
  double? _subcool;
  double? _targetSuperheat;

  // Track if we've received any real data
  bool _hasReceivedData = false;

  // Current job type selection
  JobType _currentJobType = JobType.airConditioning;

  // Gauge display mode (digital or analog)
  GaugeDisplayMode _gaugeDisplayMode = GaugeDisplayMode.digital;

  // Scale connection state for auto-display
  bool _isScaleConnected = false;
  double _scaleWeight = 0.0;
  String? _scaleDeviceId;
  String? _scaleDeviceName;
  int? _scaleBatteryLevel;
  double? _lastKnownScaleWeight; // Preserved when disconnected

  // Diagnostic result (updated when readings change)
  DiagnosticResult? _diagnosticResult;

  StreamSubscription? _deviceUpdatesSubscription;
  StreamSubscription? _disconnectSubscription;
  StreamSubscription? _batterySubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _bleService.init();
    await _dataService.init();
    await _storageService.init();
    await _reconnectService.init();
    await _mlDataService.init();
    await _loadDeviceNames();
    await _loadBatteryLevels();
    await _loadGaugeDisplayMode();
    _listenForDeviceUpdates();
  }

  Future<void> _loadGaugeDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('gaugeDisplayMode') ?? 'digital';
    if (mounted) {
      setState(() {
        _gaugeDisplayMode = modeStr == 'analog' 
            ? GaugeDisplayMode.analog 
            : GaugeDisplayMode.digital;
      });
    }
  }

  Future<void> _saveGaugeDisplayMode(GaugeDisplayMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gaugeDisplayMode', mode == GaugeDisplayMode.analog ? 'analog' : 'digital');
    if (mounted) {
      setState(() {
        _gaugeDisplayMode = mode;
      });
    }
  }

  Future<void> _loadDeviceNames() async {
    final devices = await _storageService.getSavedDevices();
    for (final d in devices) {
      _deviceNames[d.remoteId] = d.name;
    }
  }

  Future<void> _loadBatteryLevels() async {
    // Pre-populate battery levels from data service
    final levels = _dataService.allBatteryLevels;
    _batteryLevels.addAll(levels);
  }

  void _listenForDeviceUpdates() {
    // Listen for disconnect events
    _disconnectSubscription =
        _reconnectService.reconnectStatus.listen((status) {
      if (!mounted) return;

      if (status.state == ReconnectState.disconnected &&
          status.deviceId != null) {
        // Get device name before removing
        final deviceName = _deviceNames[status.deviceId] ?? 'Device';

        // Check if this is a scale
        final profile = _registry.identifyByName(deviceName);
        if (profile?.type == HvacDeviceType.refrigerantScale && 
            status.deviceId == _scaleDeviceId) {
          setState(() {
            _isScaleConnected = false;
            _lastKnownScaleWeight = _scaleWeight; // Preserve weight
          });
        }

        setState(() {
          // Reset values for slots assigned to this device before removing
          _sensorAssignments.forEach((slot, deviceId) {
            if (deviceId == status.deviceId) {
              switch (slot) {
                case GaugeSlot.lowSidePressure:
                  _lowSidePressure = 0.0;
                  break;
                case GaugeSlot.highSidePressure:
                  _highSidePressure = 0.0;
                  break;
                case GaugeSlot.suctionLineTemp:
                  _suctionLineTemp = 0.0;
                  break;
                case GaugeSlot.liquidLineTemp:
                  _liquidLineTemp = 0.0;
                  break;
                case GaugeSlot.supplyAirTemp:
                  _supplyAirTemp = 0.0;
                  break;
                case GaugeSlot.returnAirTemp:
                  _returnAirTemp = 0.0;
                  break;
              }
            }
          });
          // Remove assignments for disconnected device
          _sensorAssignments
              .removeWhere((slot, deviceId) => deviceId == status.deviceId);
        });

        // Show disconnect notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bluetooth_disabled,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$deviceName disconnected',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } else if (status.state == ReconnectState.connected &&
          status.deviceId != null) {
        // Show reconnect notification
        final deviceName = _deviceNames[status.deviceId] ?? 'Device';
        
        // Check if this is a scale reconnecting
        final profile = _registry.identifyByName(deviceName);
        if (profile?.type == HvacDeviceType.refrigerantScale) {
          setState(() {
            _isScaleConnected = true;
            _scaleDeviceId = status.deviceId;
            _scaleDeviceName = deviceName;
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bluetooth_connected,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$deviceName connected',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    });

    // Listen for real-time readings from connected devices
    _deviceUpdatesSubscription = _dataService.readings.listen((reading) {
      if (!mounted) return;

      // Update device name cache
      _deviceNames[reading.deviceId] = reading.deviceName;

      // Track that we've received real data
      _hasReceivedData = true;

      // Handle scale readings separately
      if (reading.type == HvacDeviceType.refrigerantScale) {
        setState(() {
          _isScaleConnected = true;
          _scaleWeight = reading.value;
          _scaleDeviceId = reading.deviceId;
          _scaleDeviceName = reading.deviceName;
          _lastKnownScaleWeight = reading.value; // Update last known weight
        });
        return; // Don't process scale readings as gauge data
      }

      // Apply zero offset for pressure readings (hardware zeroing)
      double adjustedValue = reading.value;
      if (reading.type == HvacDeviceType.pressureProbe) {
        final zeroOffset = _zeroOffsets[reading.deviceId] ?? 0.0;
        adjustedValue = reading.value - zeroOffset;
      }

      // Apply calibration offset (user adjustments)
      // Check if this device is assigned to a slot to determine calibration key
      for (final entry in _sensorAssignments.entries) {
        if (entry.value == reading.deviceId) {
          final isPressure = entry.key == GaugeSlot.lowSidePressure ||
              entry.key == GaugeSlot.highSidePressure;
          if (isPressure) {
            final calibOffset = _calibrationService
                .getOffset(TestoCalibrationKeys.pressure(reading.deviceId));
            adjustedValue += calibOffset;
          } else {
            // Temperature calibration
            final calibOffset = _calibrationService
                .getOffset(TestoCalibrationKeys.temperature(reading.deviceId));
            adjustedValue += calibOffset;
          }
          break;
        }
      }

      setState(() {
        // Check if this device is assigned to a slot
        for (final entry in _sensorAssignments.entries) {
          if (entry.value == reading.deviceId) {
            switch (entry.key) {
              case GaugeSlot.lowSidePressure:
                _lowSidePressure = adjustedValue;
                break;
              case GaugeSlot.highSidePressure:
                _highSidePressure = adjustedValue;
                break;
              case GaugeSlot.suctionLineTemp:
                _suctionLineTemp = adjustedValue;
                break;
              case GaugeSlot.liquidLineTemp:
                _liquidLineTemp = adjustedValue;
                break;
              case GaugeSlot.supplyAirTemp:
                _supplyAirTemp = adjustedValue;
                break;
              case GaugeSlot.returnAirTemp:
                _returnAirTemp = adjustedValue;
                break;
            }
          }
        }

        // If no assignment, auto-assign based on device type
        if (!_sensorAssignments.containsValue(reading.deviceId)) {
          switch (reading.type) {
            case HvacDeviceType.pressureProbe:
              // Auto-assign to first empty pressure slot
              if (!_sensorAssignments.containsKey(GaugeSlot.highSidePressure)) {
                _sensorAssignments[GaugeSlot.highSidePressure] =
                    reading.deviceId;
                _highSidePressure = adjustedValue;
              } else if (!_sensorAssignments
                  .containsKey(GaugeSlot.lowSidePressure)) {
                _sensorAssignments[GaugeSlot.lowSidePressure] =
                    reading.deviceId;
                _lowSidePressure = adjustedValue;
              }
              break;
            case HvacDeviceType.temperatureProbe:
              // Auto-assign to first empty temp slot
              if (!_sensorAssignments.containsKey(GaugeSlot.suctionLineTemp)) {
                _sensorAssignments[GaugeSlot.suctionLineTemp] =
                    reading.deviceId;
                _suctionLineTemp = adjustedValue;
              } else if (!_sensorAssignments
                  .containsKey(GaugeSlot.liquidLineTemp)) {
                _sensorAssignments[GaugeSlot.liquidLineTemp] = reading.deviceId;
                _liquidLineTemp = adjustedValue;
              }
              break;
            default:
              break;
          }
        }
      });

      _updateCalculations();
    });

    // Listen for battery level updates
    _batterySubscription = _dataService.batteryUpdates.listen((battery) {
      if (!mounted) return;
      setState(() {
        _batteryLevels[battery.deviceId] = battery.level;
        // Update scale battery if it's the scale device
        if (battery.deviceId == _scaleDeviceId) {
          _scaleBatteryLevel = battery.level;
        }
      });
    });
  }

  @override
  void dispose() {
    _deviceUpdatesSubscription?.cancel();
    _disconnectSubscription?.cancel();
    _batterySubscription?.cancel();
    _bleService.stopScan();
    super.dispose();
  }

  void _updateCalculations() {
    // Convert mbar to psig for PT chart calculations
    final lowPsig = _lowSidePressure * 0.0145038;
    final highPsig = _highSidePressure * 0.0145038;

    if (lowPsig > 0 && _suctionLineTemp > 0) {
      _superheat = _ptChart.calculateSuperheat(
        refrigerant: _currentRefrigerant,
        suctionPressure: lowPsig,
        suctionLineTemp: _suctionLineTemp,
      );
    } else {
      _superheat = null;
    }

    if (highPsig > 0 && _liquidLineTemp > 0) {
      _subcool = _ptChart.calculateSubcool(
        refrigerant: _currentRefrigerant,
        liquidPressure: highPsig,
        liquidLineTemp: _liquidLineTemp,
      );
    } else {
      _subcool = null;
    }

    // Run diagnostics if we have any readings
    if (_hasReceivedData) {
      _diagnosticResult = _diagnosticEngine.analyze(
        systemType: _currentJobType,
        refrigerant: _currentRefrigerant,
        suctionPressure: lowPsig > 0 ? lowPsig : null,
        dischargePressure: highPsig > 0 ? highPsig : null,
        superheat: _superheat,
        subcool: _subcool,
        // TODO: Add ambient temp from ambient sensor if connected
      );
    }

    setState(() {});
  }

  /// Zero the pressure sensor assigned to the given slot
  void _zeroSensor(GaugeSlot slot) {
    final deviceId = _sensorAssignments[slot];
    if (deviceId == null) return;

    // Get current raw reading (before any offset) to use as the new zero point
    double currentRaw;
    switch (slot) {
      case GaugeSlot.lowSidePressure:
        // Add back any existing offset to get the raw value
        currentRaw = _lowSidePressure + (_zeroOffsets[deviceId] ?? 0.0);
        break;
      case GaugeSlot.highSidePressure:
        currentRaw = _highSidePressure + (_zeroOffsets[deviceId] ?? 0.0);
        break;
      default:
        return; // Only pressure slots can be zeroed
    }

    // Set the zero offset to the current raw reading
    setState(() {
      _zeroOffsets[deviceId] = currentRaw;
      // Apply the offset immediately
      switch (slot) {
        case GaugeSlot.lowSidePressure:
          _lowSidePressure = 0.0;
          break;
        case GaugeSlot.highSidePressure:
          _highSidePressure = 0.0;
          break;
        default:
          break;
      }
    });

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_slotDisplayName(slot)} zeroed'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );

    debugPrint(
        '[Gauge] Zeroed ${_slotDisplayName(slot)}: offset = $currentRaw mbar');
  }

  /// Get calibrated pressure reading for a device
  double _getCalibratedPressure(String deviceId, double rawPressure) {
    final offset =
        _calibrationService.getOffset(TestoCalibrationKeys.pressure(deviceId));
    return rawPressure + offset;
  }

  /// Get calibrated temperature reading for a device
  double _getCalibratedTemperature(String deviceId, double rawTemp) {
    final offset = _calibrationService
        .getOffset(TestoCalibrationKeys.temperature(deviceId));
    return rawTemp + offset;
  }

  /// Show calibration popup for a sensor
  void _showCalibrationPopup({
    required GaugeSlot slot,
    required GlobalKey targetKey,
  }) {
    final deviceId = _sensorAssignments[slot];
    if (deviceId == null) return;

    final isPressure =
        slot == GaugeSlot.lowSidePressure || slot == GaugeSlot.highSidePressure;
    final sensorKey = isPressure
        ? TestoCalibrationKeys.pressure(deviceId)
        : TestoCalibrationKeys.temperature(deviceId);

    double currentValue;
    String label;
    String unit;
    double step;

    switch (slot) {
      case GaugeSlot.highSidePressure:
        currentValue = _highSidePressure;
        label = 'High Side';
        unit = 'PSI';
        step = 0.5;
        break;
      case GaugeSlot.lowSidePressure:
        currentValue = _lowSidePressure;
        label = 'Low Side';
        unit = 'PSI';
        step = 0.5;
        break;
      case GaugeSlot.suctionLineTemp:
        currentValue = _suctionLineTemp;
        label = 'Suction Temp';
        unit = '°F';
        step = 0.5;
        break;
      case GaugeSlot.liquidLineTemp:
        currentValue = _liquidLineTemp;
        label = 'Liquid Temp';
        unit = '°F';
        step = 0.5;
        break;
      default:
        return;
    }

    showCalibrationPopup(
      context: context,
      targetKey: targetKey,
      sensorKey: sensorKey,
      label: label,
      currentValue: currentValue,
      step: step,
      unit: unit,
      accentColor: AppColors.primaryCyan,
      onSave: () {
        setState(() {
          // Refresh UI to show calibrated values
        });
      },
    );
  }

  void _showRefrigerantPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildRefrigerantPicker(),
    );
  }

  Widget _buildRefrigerantPicker() {
    final refrigerants = Refrigerant.values;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Refrigerant',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: refrigerants.map((r) {
              final isSelected = r == _currentRefrigerant;
              return GestureDetector(
                onTap: () async {
                  // Check if this is R22 or a drop-in that requires confirmation
                  if (r.isR22DropIn && r != _currentRefrigerant) {
                    Navigator.pop(context);
                    final confirmed = await _showR22ConfirmationDialog(r);
                    if (confirmed && mounted) {
                      setState(() {
                        _currentRefrigerant = r;
                      });
                      _updateCalculations();
                    }
                  } else {
                    setState(() {
                      _currentRefrigerant = r;
                    });
                    _updateCalculations();
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryCyan
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.primaryCyan : AppColors.border,
                    ),
                  ),
                  child: Text(
                    r.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.black : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Show confirmation dialog for R22 and drop-in refrigerants
  /// Returns true if user confirms selection
  Future<bool> _showR22ConfirmationDialog(Refrigerant refrigerant) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Text(
              'Confirm ${refrigerant.displayName}',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              refrigerant == Refrigerant.r22
                  ? 'R-22 systems may have been converted to drop-in refrigerants like R-407C or Nu-22.'
                  : '${refrigerant.displayName} is a drop-in replacement for R-22. Verify this is the correct refrigerant for this system.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'Check the nameplate or service stickers to confirm the current refrigerant type.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              foregroundColor: Colors.black,
            ),
            child: Text('Confirm ${refrigerant.displayName}'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show sensor picker for a gauge slot with live Bluetooth discovery
  void _showSensorPicker(GaugeSlot slot) {
    final isTemperatureSlot = slot == GaugeSlot.suctionLineTemp ||
        slot == GaugeSlot.liquidLineTemp ||
        slot == GaugeSlot.supplyAirTemp ||
        slot == GaugeSlot.returnAirTemp;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SensorPickerSheet(
        slot: slot,
        isTemperatureSlot: isTemperatureSlot,
        slotDisplayName: _slotDisplayName(slot),
        connectedDeviceIds: _reconnectService.connectedDeviceIds.toList(),
        sensorAssignments: _sensorAssignments,
        deviceNames: _deviceNames,
        zeroOffsets: _zeroOffsets,
        registry: _registry,
        bleService: _bleService,
        reconnectService: _reconnectService,
        storageService: _storageService,
        onAssign: (deviceId, deviceName) {
          setState(() {
            // Find and clear the old slot if this device was previously assigned
            GaugeSlot? oldSlot;
            _sensorAssignments.forEach((k, v) {
              if (v == deviceId) oldSlot = k;
            });
            if (oldSlot != null) {
              _sensorAssignments.remove(oldSlot);
              // Reset the display value for the old slot
              switch (oldSlot!) {
                case GaugeSlot.lowSidePressure:
                  _lowSidePressure = 0.0;
                  break;
                case GaugeSlot.highSidePressure:
                  _highSidePressure = 0.0;
                  break;
                case GaugeSlot.suctionLineTemp:
                  _suctionLineTemp = 0.0;
                  break;
                case GaugeSlot.liquidLineTemp:
                  _liquidLineTemp = 0.0;
                  break;
                case GaugeSlot.supplyAirTemp:
                  _supplyAirTemp = 0.0;
                  break;
                case GaugeSlot.returnAirTemp:
                  _returnAirTemp = 0.0;
                  break;
              }
              // Also clear zero offset for that slot
              _zeroOffsets.remove(deviceId);
            }
            // Assign to this slot
            _sensorAssignments[slot] = deviceId;
            // Store device name
            _deviceNames[deviceId] = deviceName;
          });
        },
        onUnassign: () {
          setState(() {
            final deviceId = _sensorAssignments[slot];
            _sensorAssignments.remove(slot);
            if (deviceId != null) {
              _zeroOffsets.remove(deviceId);
            }
            switch (slot) {
              case GaugeSlot.lowSidePressure:
                _lowSidePressure = 0.0;
                break;
              case GaugeSlot.highSidePressure:
                _highSidePressure = 0.0;
                break;
              case GaugeSlot.suctionLineTemp:
                _suctionLineTemp = 0.0;
                break;
              case GaugeSlot.liquidLineTemp:
                _liquidLineTemp = 0.0;
                break;
              case GaugeSlot.supplyAirTemp:
                _supplyAirTemp = 0.0;
                break;
              case GaugeSlot.returnAirTemp:
                _returnAirTemp = 0.0;
                break;
            }
          });
          _updateCalculations();
        },
        onZero: () => _zeroSensor(slot),
      ),
    );
  }

  /// Show job type picker
  void _showJobTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildJobTypePicker(),
    );
  }

  Widget _buildJobTypePicker() {
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Job Type',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the type of system you\'re working on',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          // Make the list scrollable
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main job types
                  _buildJobTypeOption(JobType.airConditioning),
                  _buildJobTypeOption(JobType.heatPump),
                  const SizedBox(height: 12),
                  // Refrigeration header
                  Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Refrigeration',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  _buildJobTypeOption(JobType.refrigerationCooler),
                  _buildJobTypeOption(JobType.refrigerationFreezer),
                  _buildJobTypeOption(JobType.refrigerationIceMachine),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildJobTypeOption(JobType jobType) {
    final isSelected = _currentJobType == jobType;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentJobType = jobType;
        });
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryCyan.withOpacity(0.15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryCyan : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              jobType.icon,
              color:
                  isSelected ? AppColors.primaryCyan : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                jobType.displayName,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primaryCyan
                      : AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle,
                  color: AppColors.primaryCyan, size: 22),
          ],
        ),
      ),
    );
  }

  String _slotDisplayName(GaugeSlot slot) {
    switch (slot) {
      case GaugeSlot.lowSidePressure:
        return 'Low Side';
      case GaugeSlot.highSidePressure:
        return 'High Side';
      case GaugeSlot.suctionLineTemp:
        return 'Suction Line';
      case GaugeSlot.liquidLineTemp:
        return 'Liquid Line';
      case GaugeSlot.supplyAirTemp:
        return 'Supply Air';
      case GaugeSlot.returnAirTemp:
        return 'Return Air';
    }
  }

  String? _getAssignedDeviceName(GaugeSlot slot) {
    final deviceId = _sensorAssignments[slot];
    if (deviceId == null) return null;
    return _deviceNames[deviceId];
  }

  /// Get battery level for an assigned sensor (0-100 or null)
  int? _getAssignedBatteryLevel(GaugeSlot slot) {
    final deviceId = _sensorAssignments[slot];
    if (deviceId == null) return null;
    return _batteryLevels[deviceId];
  }

  void _toggleGaugeDisplayMode() {
    final newMode = _gaugeDisplayMode == GaugeDisplayMode.digital
        ? GaugeDisplayMode.analog
        : GaugeDisplayMode.digital;
    _saveGaugeDisplayMode(newMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Gauges',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Display mode toggle
          IconButton(
            icon: Icon(
              _gaugeDisplayMode == GaugeDisplayMode.digital
                  ? Icons.speed
                  : Icons.grid_view,
              color: AppColors.textSecondary,
            ),
            onPressed: _toggleGaugeDisplayMode,
            tooltip: _gaugeDisplayMode == GaugeDisplayMode.digital
                ? 'Switch to Analog'
                : 'Switch to Digital',
          ),
          // Settings gear for job type
          IconButton(
            icon: Icon(Icons.settings, color: AppColors.textSecondary),
            onPressed: _showJobTypePicker,
            tooltip: 'Job Type',
          ),
          // Refrigerant selector
          GestureDetector(
            onTap: _showRefrigerantPicker,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentRefrigerant.displayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Show tip if devices connected but no data received
                  if (!_hasReceivedData && _sensorAssignments.isNotEmpty)
                    _buildNoDataTip(),
                  // Diagnostic Card - Show AI insights
                  if (_diagnosticResult != null)
                    DiagnosticCard(
                      diagnostic: _diagnosticResult!,
                      onTroubleshootTap: () {
                        TroubleshootingSheet.show(context, _diagnosticResult!);
                      },
                    ),
                  if (_diagnosticResult != null) const SizedBox(height: 16),
                  // Pressure Gauges
                  _buildPressureGauges(),
                  const SizedBox(height: 24),
                  // Calculations Card
                  _buildCalculationsCard(),
                  const SizedBox(height: 24),
                  // Line Temp Probes
                  _buildLineTemperatureProbes(),
                  const SizedBox(height: 24),
                  // Air Temp Probes
                  _buildAirTemperatureProbes(),
                  // Extra padding at bottom for scale overlay
                  if (_isScaleConnected || _lastKnownScaleWeight != null)
                    const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // Scale overlay (auto-shows when scale is connected)
          if (_isScaleConnected || _lastKnownScaleWeight != null)
            _buildScaleOverlay(),
        ],
      ),
      floatingActionButton: _hasReceivedData
          ? FloatingActionButton.extended(
              heroTag: 'gauge_screen_fab',
              onPressed: _captureReadingForML,
              backgroundColor: AppColors.primaryCyan,
              icon: const Icon(Icons.save, color: Colors.black),
              label: const Text(
                'Capture',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  /// Capture current readings for ML training
  Future<void> _captureReadingForML() async {
    if (!_hasReceivedData) return;

    // Convert mbar to PSI for storage
    final lowPsig = _lowSidePressure * 0.0145038;
    final highPsig = _highSidePressure * 0.0145038;

    final reading = _mlDataService.captureReading(
      systemType: _currentJobType,
      refrigerant: _currentRefrigerant,
      suctionPressure: lowPsig > 0 ? lowPsig : null,
      dischargePressure: highPsig > 0 ? highPsig : null,
      suctionLineTemp: _suctionLineTemp > 0 ? _suctionLineTemp : null,
      liquidLineTemp: _liquidLineTemp > 0 ? _liquidLineTemp : null,
      supplyAirTemp: _supplyAirTemp > 0 ? _supplyAirTemp : null,
      returnAirTemp: _returnAirTemp > 0 ? _returnAirTemp : null,
      superheat: _superheat,
      subcool: _subcool,
      outcome: ReadingOutcome.unknown,
    );

    // Upload immediately (could also batch for job completion)
    await _mlDataService.uploadReading(reading);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_upload, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                _mlDataService.isMLDataSharingEnabled
                    ? 'Reading captured for ML training'
                    : 'Reading saved locally (sharing disabled)',
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Build a tip widget when connected but no data is being received
  Widget _buildNoDataTip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for probe data...',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Testo probes may need to be activated first. Try pressing the button on your probe or briefly open the Testo app.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Convert mbar to display value and unit
  /// Returns (displayValue, unit, formattedValue)
  (double, String, String) _convertPressure(double mbar) {
    // Threshold for switching to microns (vacuum territory)
    // When mbar < -900 (deep vacuum, close to -1013 = full vacuum), show microns
    const double vacuumThreshold = -900.0; // mbar

    if (mbar < vacuumThreshold) {
      // Deep vacuum - show microns
      // microns = absolute pressure in microns of mercury
      // absolute_mbar = 1013.25 + differential_mbar
      // microns = absolute_mbar * 750.06
      final absoluteMbar = 1013.25 + mbar;
      final microns = absoluteMbar * 750.06;
      if (microns < 1000) {
        return (microns, 'µ', microns.toStringAsFixed(0));
      } else {
        // If microns > 1000, show as mTorr (millitorr = microns/1000)
        final mTorr = microns / 1000;
        return (mTorr, 'mTorr', mTorr.toStringAsFixed(2));
      }
    } else {
      // Normal or shallow vacuum - show PSI
      final psig = mbar * 0.0145038;
      return (psig, 'PSI', psig.toStringAsFixed(1));
    }
  }

  Widget _buildPressureGauges() {
    // Convert mbar readings to appropriate units
    final lowSide = _convertPressure(_lowSidePressure);
    final highSide = _convertPressure(_highSidePressure);

    // For saturation temp, we need psig
    final lowPsig = _lowSidePressure * 0.0145038;
    final highPsig = _highSidePressure * 0.0145038;

    if (_gaugeDisplayMode == GaugeDisplayMode.analog) {
      return Row(
        children: [
          Expanded(
            child: _buildAnalogGauge(
              slot: GaugeSlot.lowSidePressure,
              label: 'Low Side',
              value: lowSide.$1,
              unit: lowSide.$2,
              color: AppColors.primaryCyanLight,
              minValue: -30,
              maxValue: 150,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildAnalogGauge(
              slot: GaugeSlot.highSidePressure,
              label: 'High Side',
              value: highSide.$1,
              unit: highSide.$2,
              color: AppColors.error,
              minValue: 0,
              maxValue: 500,
            ),
          ),
        ],
      );
    }

    // Digital mode (default)
    return Row(
      children: [
        Expanded(
          child: _buildGaugeCard(
            slot: GaugeSlot.lowSidePressure,
            label: 'Low Side',
            value: lowSide.$1,
            unit: lowSide.$2,
            formattedValue: lowSide.$3,
            color: AppColors.primaryCyanLight,
            satTemp: lowPsig > 0
                ? _ptChart.getSaturationTemp(_currentRefrigerant, lowPsig)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGaugeCard(
            slot: GaugeSlot.highSidePressure,
            label: 'High Side',
            value: highSide.$1,
            unit: highSide.$2,
            formattedValue: highSide.$3,
            color: AppColors.error,
            satTemp: highPsig > 0
                ? _ptChart.getSaturationTemp(_currentRefrigerant, highPsig)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildGaugeCard({
    required GaugeSlot slot,
    required String label,
    required double value,
    required String unit,
    required Color color,
    double? satTemp,
    String? formattedValue,
  }) {
    final assignedDevice = _getAssignedDeviceName(slot);
    final batteryLevel = _getAssignedBatteryLevel(slot);
    // Show value if we have a reading (value != 0 or unit is microns/mTorr)
    final hasReading = value != 0 || unit == 'µ' || unit == 'mTorr';
    final displayValue =
        formattedValue ?? (hasReading ? value.toStringAsFixed(1) : '--');

    // Determine which global key to use for calibration popup positioning
    final key = slot == GaugeSlot.highSidePressure
        ? _highSidePressureKey
        : _lowSidePressureKey;

    return GestureDetector(
      key: key,
      onTap: () => _showSensorPicker(slot),
      onLongPress: assignedDevice != null && hasReading
          ? () => _showCalibrationPopup(slot: slot, targetKey: key)
          : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  assignedDevice != null
                      ? Icons.sensors
                      : Icons.add_circle_outline,
                  color: assignedDevice != null
                      ? AppColors.success
                      : AppColors.textMuted,
                  size: 16,
                ),
                if (batteryLevel != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    batteryLevel >= 60
                        ? Icons.battery_full
                        : batteryLevel >= 20
                            ? Icons.battery_4_bar
                            : Icons.battery_alert,
                    color: batteryLevel >= 60
                        ? AppColors.success
                        : batteryLevel >= 20
                            ? AppColors.warning
                            : AppColors.error,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$batteryLevel%',
                    style: TextStyle(
                      color: batteryLevel >= 60
                          ? AppColors.success
                          : batteryLevel >= 20
                              ? AppColors.warning
                              : AppColors.error,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
            if (assignedDevice != null) ...[
              const SizedBox(height: 2),
              Text(
                assignedDevice,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              hasReading ? displayValue : '--',
              style: TextStyle(
                color: color,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                color: unit == 'µ' || unit == 'mTorr'
                    ? AppColors.warning
                    : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: unit == 'µ' || unit == 'mTorr'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            if (satTemp != null) ...[
              const SizedBox(height: 8),
              Text(
                'Sat: ${satTemp.toStringAsFixed(1)}°F',
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCalculationValue(
                  'Superheat',
                  _superheat,
                  '°F',
                  hint: 'Need temp probe',
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: AppColors.border,
              ),
              Expanded(
                child: _buildCalculationValue(
                  'Subcool',
                  _subcool,
                  '°F',
                  hint: 'Need temp probe',
                ),
              ),
            ],
          ),
          if (_targetSuperheat != null) ...[
            const SizedBox(height: 16),
            Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Text(
              'Target Superheat: ${_targetSuperheat!.toStringAsFixed(1)}°F',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalculationValue(String label, double? value, String unit,
      {String? hint}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        if (value != null)
          Text(
            '${value.toStringAsFixed(1)}$unit',
            style: TextStyle(
              color: AppColors.primaryCyan,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          )
        else
          Text(
            hint ?? '--',
            style: TextStyle(
              color: AppColors.textMuted.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
      ],
    );
  }

  Widget _buildLineTemperatureProbes() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Line Temp Probes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTempReading(
                  slot: GaugeSlot.suctionLineTemp,
                  label: 'Suction Line',
                  value: _suctionLineTemp,
                  icon: Icons.thermostat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTempReading(
                  slot: GaugeSlot.liquidLineTemp,
                  label: 'Liquid Line',
                  value: _liquidLineTemp,
                  icon: Icons.thermostat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTempReading({
    required GaugeSlot slot,
    required String label,
    required double value,
    required IconData icon,
  }) {
    final assignedDevice = _getAssignedDeviceName(slot);
    final batteryLevel = _getAssignedBatteryLevel(slot);

    // Determine which global key to use for calibration popup positioning
    final key = slot == GaugeSlot.suctionLineTemp
        ? _suctionLineTempKey
        : _liquidLineTempKey;

    final hasReading = value != 0;

    return GestureDetector(
      key: key,
      onTap: () => _showSensorPicker(slot),
      onLongPress: assignedDevice != null && hasReading
          ? () => _showCalibrationPopup(slot: slot, targetKey: key)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryCyan, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        assignedDevice != null
                            ? Icons.sensors
                            : Icons.add_circle_outline,
                        color: assignedDevice != null
                            ? AppColors.success
                            : AppColors.textMuted,
                        size: 12,
                      ),
                      if (batteryLevel != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          batteryLevel >= 60
                              ? Icons.battery_full
                              : batteryLevel >= 20
                                  ? Icons.battery_4_bar
                                  : Icons.battery_alert,
                          color: batteryLevel >= 60
                              ? AppColors.success
                              : batteryLevel >= 20
                                  ? AppColors.warning
                                  : AppColors.error,
                          size: 10,
                        ),
                        Text(
                          '$batteryLevel%',
                          style: TextStyle(
                            color: batteryLevel >= 60
                                ? AppColors.success
                                : batteryLevel >= 20
                                    ? AppColors.warning
                                    : AppColors.error,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (assignedDevice != null)
                    Text(
                      assignedDevice,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    value > 0 ? '${value.toStringAsFixed(1)}°F' : '--',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAirTemperatureProbes() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Air Temp Probes',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'TD: ${_returnAirTemp > 0 && _supplyAirTemp > 0 ? (_returnAirTemp - _supplyAirTemp).toStringAsFixed(1) : "--"}°F',
                style: TextStyle(
                  color: _returnAirTemp > 0 && _supplyAirTemp > 0
                      ? AppColors.primaryCyan
                      : AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTempReading(
                  slot: GaugeSlot.supplyAirTemp,
                  label: 'Supply Air',
                  value: _supplyAirTemp,
                  icon: Icons.air,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTempReading(
                  slot: GaugeSlot.returnAirTemp,
                  label: 'Return Air',
                  value: _returnAirTemp,
                  icon: Icons.air,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScaleOverlay() {
    // Placeholder implementation for scale overlay
    return SizedBox.shrink();
  }

  /// Build analog gauge (classic round dial)
  Widget _buildAnalogGauge({
    required GaugeSlot slot,
    required String label,
    required double value,
    required String unit,
    required Color color,
    required double minValue,
    required double maxValue,
  }) {
    final assignedDevice = _getAssignedDeviceName(slot);
    final batteryLevel = _getAssignedBatteryLevel(slot);
    final hasReading = value != 0;

    // Normalize value to 0-1 range for gauge
    double normalizedValue = 0;
    if (hasReading) {
      normalizedValue = ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    }

    return GestureDetector(
      onTap: () => _showSensorPicker(slot),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: assignedDevice != null
                ? color.withOpacity(0.5)
                : AppColors.textMuted.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Label and assigned device name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (batteryLevel != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.battery_std,
                        size: 16,
                        color: _getBatteryColor(batteryLevel),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$batteryLevel%',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (assignedDevice != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  assignedDevice,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Circular gauge
            Stack(
              alignment: Alignment.center,
              children: [
                // Background arc
                CustomPaint(
                  size: const Size(120, 120),
                  painter: _GaugeArcPainter(
                    backgroundColor: AppColors.textMuted.withOpacity(0.1),
                    foregroundColor: color,
                    value: normalizedValue,
                  ),
                ),
                // Value display
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasReading ? value.toStringAsFixed(1) : '--',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: hasReading ? color : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Assignment prompt or tap to reassign
            Text(
              assignedDevice != null
                  ? 'Tap to reassign'
                  : 'Tap to assign sensor',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 75) return AppColors.success;
    if (level > 30) return AppColors.warning;
    return AppColors.error;
  }
}

/// Stateful sensor picker sheet with live Bluetooth scanning
class _SensorPickerSheet extends StatefulWidget {
  final GaugeSlot slot;
  final bool isTemperatureSlot;
  final String slotDisplayName;
  final List<String> connectedDeviceIds;
  final Map<GaugeSlot, String> sensorAssignments;
  final Map<String, String> deviceNames;
  final Map<String, double> zeroOffsets;
  final DeviceRegistry registry;
  final BluetoothService bleService;
  final AutoReconnectService reconnectService;
  final DeviceStorageService storageService;
  final Function(String deviceId, String deviceName) onAssign;
  final VoidCallback onUnassign;
  final VoidCallback onZero;

  const _SensorPickerSheet({
    required this.slot,
    required this.isTemperatureSlot,
    required this.slotDisplayName,
    required this.connectedDeviceIds,
    required this.sensorAssignments,
    required this.deviceNames,
    required this.zeroOffsets,
    required this.registry,
    required this.bleService,
    required this.reconnectService,
    required this.storageService,
    required this.onAssign,
    required this.onUnassign,
    required this.onZero,
  });

  @override
  State<_SensorPickerSheet> createState() => _SensorPickerSheetState();
}

class _SensorPickerSheetState extends State<_SensorPickerSheet> {
  List<dynamic> _scanResults = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _connectingDeviceId;
  int? _scaleBatteryLevel;
  bool _isScaleConnected = false;
  double _scaleWeight = 0.0;
  String? _scaleDeviceId;
  String? _scaleDeviceName;
  double? _lastKnownScaleWeight;
  StreamSubscription? _scanResultsSubscription;
  StreamSubscription? _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    widget.bleService.stopScan();
    super.dispose();
  }

  Future<void> _startScanning() async {
    _scanResultsSubscription = widget.bleService.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
        });
      }
    });

    _isScanningSubscription = widget.bleService.isScanning.listen((scanning) {
      if (mounted) {
        setState(() {
          _isScanning = scanning;
        });
      }
    });

    try {
      final isAvailable = await widget.bleService.isBluetoothAvailable();
      if (!isAvailable) {
        await widget.bleService.requestBluetoothOn();
      }
      // Scan with known HVAC device service UUIDs for efficiency
      final knownUuids = widget.registry
          .getAllServiceUuids()
          .map((uuid) => Guid(uuid))
          .toList();
      await widget.bleService.startScan(
        timeout: const Duration(seconds: 30),
        serviceUuids: knownUuids.isNotEmpty ? knownUuids : null,
      );
    } catch (e) {
      debugPrint('[SensorPicker] Scan error: $e');
    }
  }

  Future<void> _connectAndAssign(dynamic scanResult) async {
    final device = scanResult.device;
    final deviceId = device.remoteId.str;
    final deviceName =
        device.platformName.isNotEmpty ? device.platformName : 'Unknown Device';

    setState(() {
      _isConnecting = true;
      _connectingDeviceId = deviceId;
    });

    try {
      await widget.bleService.connectToDevice(device);
      // Register the connection with AutoReconnectService
      widget.reconnectService.markConnected(deviceId, device);

      // Save device to storage for persistence
      final profile = widget.registry.identifyByName(deviceName);
      final savedDevice = SavedDevice(
        remoteId: deviceId,
        name: deviceName,
        manufacturer: profile?.manufacturer.name ?? 'unknown',
        deviceType: profile?.type.name ?? 'unknown',
        unit: profile?.unit ?? '',
        firstPaired: DateTime.now(),
        lastSeen: DateTime.now(),
        autoReconnect: true,
      );
      await widget.storageService.saveDevice(savedDevice);
      debugPrint('[SensorPicker] Saved device to storage: $deviceName');

      widget.onAssign(deviceId, deviceName);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[SensorPicker] Connect error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingDeviceId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get connected devices - filter to only show compatible types for this slot
    // Check both deviceNames map AND scan results for device identification
    final connectedDevices = widget.connectedDeviceIds.where((deviceId) {
      // Try to get device name from cache first
      var deviceName = widget.deviceNames[deviceId] ?? '';

      // If not in cache, check scan results
      if (deviceName.isEmpty) {
        for (final result in _scanResults) {
          if (result.device.remoteId.str == deviceId) {
            deviceName = result.device.platformName ?? '';
            break;
          }
        }
      }

      if (deviceName.isEmpty) {
        debugPrint(
            '[SensorPicker] Connected device $deviceId has no name, skipping');
        return false;
      }

      final profile = widget.registry.identifyByName(deviceName);
      if (profile == null) {
        debugPrint(
            '[SensorPicker] No profile for connected device: $deviceName');
        return false;
      }

      // Only show devices compatible with this slot type
      if (widget.isTemperatureSlot) {
        return profile.type == HvacDeviceType.temperatureProbe;
      } else {
        return profile.type == HvacDeviceType.pressureProbe;
      }
    }).toList();

    // Filter scan results to ONLY recognized HVAC devices that match the slot type
    final compatibleDevices = _scanResults.where((result) {
      final deviceName = result.device.platformName ?? '';
      if (deviceName.isEmpty) return false;

      // Must be a recognized device
      final profile = widget.registry.identifyByName(deviceName);
      final profileByUuid = widget.registry.identifyDevice(result);
      final detectedProfile = profile ?? profileByUuid;
      if (detectedProfile == null) return false;

      // Must match the slot type (temp probe for temp slots, pressure for pressure slots)
      if (widget.isTemperatureSlot) {
        return detectedProfile.type == HvacDeviceType.temperatureProbe;
      } else {
        return detectedProfile.type == HvacDeviceType.pressureProbe;
      }
    }).toList();

    // Check if this slot is assigned
    final isAssigned = widget.sensorAssignments.containsKey(widget.slot);

    // Get supported device hint based on slot type
    final supportedDevicesHint = widget.isTemperatureSlot
        ? 'Supported: Testo T115i'
        : 'Supported: Testo T549i, T550i';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign ${widget.isTemperatureSlot ? "Temperature" : "Pressure"} Sensor',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.slotDisplayName,
                      style: TextStyle(
                        color: AppColors.primaryCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isScanning)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryCyan,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Connected compatible devices section
          if (connectedDevices.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppColors.success, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${connectedDevices.length} Compatible ${connectedDevices.length == 1 ? "Device" : "Devices"} Connected',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...connectedDevices.map((deviceId) {
              // Get device name from cache or scan results
              var deviceName = widget.deviceNames[deviceId] ?? '';
              if (deviceName.isEmpty) {
                for (final result in _scanResults) {
                  if (result.device.remoteId.str == deviceId) {
                    deviceName = result.device.platformName ?? '';
                    break;
                  }
                }
              }
              if (deviceName.isEmpty) deviceName = deviceId;

              final isAssignedToSlot =
                  widget.sensorAssignments[widget.slot] == deviceId;
              final profile = widget.registry.identifyByName(deviceName);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isAssignedToSlot
                      ? AppColors.primaryCyan.withOpacity(0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAssignedToSlot
                        ? AppColors.primaryCyan
                        : AppColors.border,
                    width: isAssignedToSlot ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.isTemperatureSlot ? Icons.thermostat : Icons.speed,
                      color: AppColors.success,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    deviceName,
                    style: TextStyle(
                      color: isAssignedToSlot
                          ? AppColors.primaryCyan
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    profile?.name ?? 'Ready to use',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  trailing: isAssignedToSlot
                      ? Icon(Icons.check_circle,
                          color: AppColors.primaryCyan, size: 28)
                      : Text(
                          'TAP TO SELECT',
                          style: TextStyle(
                            color: AppColors.primaryCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  onTap: () {
                    widget.onAssign(deviceId, deviceName);
                    Navigator.pop(context);
                  },
                ),
              );
            }),
            const SizedBox(height: 8),
            Divider(color: AppColors.border),
          ],

          // Discovered compatible devices section
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                color: AppColors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _isScanning ? 'Scanning for sensors...' : 'Available Sensors',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Flexible(
            child: compatibleDevices.isEmpty
                ? _buildEmptyState(supportedDevicesHint)
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: compatibleDevices.length,
                    itemBuilder: (context, index) {
                      final result = compatibleDevices[index];
                      final device = result.device;
                      final deviceId = device.remoteId.str;
                      final deviceName = device.platformName.isNotEmpty
                          ? device.platformName
                          : 'Unknown Device';

                      // Skip if already connected
                      if (widget.connectedDeviceIds.contains(deviceId)) {
                        return const SizedBox.shrink();
                      }

                      final profile =
                          widget.registry.identifyByName(deviceName);
                      final isConnecting = _connectingDeviceId == deviceId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.isTemperatureSlot
                                  ? Icons.thermostat
                                  : Icons.speed,
                              color: AppColors.primaryCyan,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            deviceName,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            profile?.name ?? 'Tap to connect',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          trailing: isConnecting
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryCyan,
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryCyan,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    'CONNECT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                          onTap: _isConnecting
                              ? null
                              : () => _connectAndAssign(result),
                        ),
                      );
                    },
                  ),
          ),

          // Action buttons
          const SizedBox(height: 12),
          if (isAssigned) ...[
            Row(
              children: [
                if (!widget.isTemperatureSlot)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.onZero();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.exposure_zero, size: 18),
                      label: const Text('Zero'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryCyan,
                        side: BorderSide(color: AppColors.primaryCyan),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (!widget.isTemperatureSlot) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      widget.onUnassign();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('Unassign'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Build scale overlay that auto-appears when scale is connected
  Widget _buildScaleOverlay() {
    final isConnected = _isScaleConnected;
    final weight = isConnected ? _scaleWeight : (_lastKnownScaleWeight ?? 0.0);
    
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: isConnected ? 1.0 : 0.6,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isConnected
                  ? [AppColors.primaryPurple, AppColors.accentBlue]
                  : [AppColors.textMuted, AppColors.textSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isConnected
                    ? AppColors.primaryPurple.withOpacity(0.3)
                    : Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Scale icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.scale,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Weight and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scaleDeviceName ?? 'Scale',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          weight.toStringAsFixed(2),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'oz',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (!isConnected)
                      const Text(
                        'Last known weight',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              // Connection status and battery
              Column(
                children: [
                  // Connection strength (simulated from RSSI if available)
                  Icon(
                    isConnected
                        ? Icons.signal_cellular_4_bar
                        : Icons.signal_cellular_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  if (_scaleBatteryLevel != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _scaleBatteryLevel! >= 60
                              ? Icons.battery_full
                              : _scaleBatteryLevel! >= 20
                                  ? Icons.battery_4_bar
                                  : Icons.battery_alert,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_scaleBatteryLevel}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String supportedDevicesHint) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isScanning ? Icons.bluetooth_searching : Icons.sensors_off,
                color: AppColors.textMuted,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isScanning
                  ? 'Looking for sensors...'
                  : 'No compatible sensors found',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isScanning
                  ? 'Make sure your probe is powered on'
                  : 'Power on your sensor and try again',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline,
                      color: AppColors.info, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    supportedDevicesHint,
                    style: TextStyle(
                      color: AppColors.info,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isScanning) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _startScanning,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Scan Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  foregroundColor: Colors.white,
                  padding:
                                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _getAssignedDeviceName(GaugeSlot slot) {
    // Placeholder implementation
    return null;
  }

  int? _getAssignedBatteryLevel(GaugeSlot slot) {
    // Placeholder implementation
    return null;
  }
  void _showSensorPicker(GaugeSlot slot) {
    // Placeholder implementation
  }
}

/// Custom painter for analog gauge dial
class _AnalogGaugePainter extends CustomPainter {
  final double value; // 0.0 to 1.0
  final Color color;
  final bool isDarkMode;

  _AnalogGaugePainter({
    required this.value,
    required this.color,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    // Draw outer ring
    final outerRingPaint = Paint()
      ..color = isDarkMode ? AppColors.darkBorder : AppColors.lightBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, outerRingPaint);

    // Draw colored arc (gauge fill)
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    // Arc goes from -150° to +150° (240° total range)
    const startAngle = -150 * math.pi / 180;
    const totalAngle = 240 * math.pi / 180;
    final sweepAngle = totalAngle * value;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // Draw tick marks
    final tickPaint = Paint()
      ..color = isDarkMode ? AppColors.darkTextMuted : AppColors.lightTextMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i <= 10; i++) {
      final angle = startAngle + (totalAngle * i / 10);
      final isMajorTick = i % 2 == 0;
      final tickLength = isMajorTick ? 12.0 : 6.0;

      final startPoint = Offset(
        center.dx + (radius - tickLength) * math.cos(angle),
        center.dy + (radius - tickLength) * math.sin(angle),
      );
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      canvas.drawLine(startPoint, endPoint, tickPaint);
    }

    // Draw needle
    final needleAngle = startAngle + (totalAngle * value);
    final needlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeWidth = 3;

    final needleLength = radius - 20;
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );

    // Draw needle as a triangle
    final needlePath = Path();
    needlePath.moveTo(center.dx, center.dy);
    needlePath.lineTo(
      center.dx + 6 * math.cos(needleAngle + math.pi / 2),
      center.dy + 6 * math.sin(needleAngle + math.pi / 2),
    );
    needlePath.lineTo(needleEnd.dx, needleEnd.dy);
    needlePath.lineTo(
      center.dx + 6 * math.cos(needleAngle - math.pi / 2),
      center.dy + 6 * math.sin(needleAngle - math.pi / 2),
    );
    needlePath.close();

    canvas.drawPath(needlePath, needlePaint);

    // Draw center circle
    final centerCirclePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 8, centerCirclePaint);
  }

  @override
  bool shouldRepaint(_AnalogGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

/// Custom painter for simpler arc-style gauge
class _GaugeArcPainter extends CustomPainter {
  final Color backgroundColor;
  final Color foregroundColor;
  final double value;

  _GaugeArcPainter({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const startAngle = math.pi * 0.75; // Start at 135 degrees
    const sweepAngle = math.pi * 1.5; // 270 degrees total

    // Background arc
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // Foreground arc
    if (value > 0) {
      final foregroundPaint = Paint()
        ..color = foregroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * value,
        false,
        foregroundPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugeArcPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
