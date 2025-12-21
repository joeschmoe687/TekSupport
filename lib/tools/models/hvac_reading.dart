import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/gauge_screen.dart';
import '../services/refrigerant_detector.dart';

/// Represents a single HVAC diagnostic reading for ML training
class HvacReading {
  final String id;
  final String? jobId;
  final String? technicianId;
  final DateTime timestamp;
  
  // System information
  final JobType systemType;
  final Refrigerant refrigerant;
  final String? equipmentInfo; // Nameplate data
  final bool? isFixedOrifice; // vs TXV
  
  // Pressure readings (PSI)
  final double? suctionPressure;
  final double? dischargePressure;
  
  // Temperature readings (°F)
  final double? suctionLineTemp;
  final double? liquidLineTemp;
  final double? supplyAirTemp;
  final double? returnAirTemp;
  final double? ambientTemp;
  
  // Calculated values
  final double? superheat;
  final double? subcool;
  
  // Job outcome
  final ReadingOutcome? outcome;
  final String? technicianNotes;
  final List<String>? adjustmentsMade; // What tech changed after seeing readings
  
  // Privacy flag
  final bool isAnonymized;
  
  HvacReading({
    required this.id,
    this.jobId,
    this.technicianId,
    required this.timestamp,
    required this.systemType,
    required this.refrigerant,
    this.equipmentInfo,
    this.isFixedOrifice,
    this.suctionPressure,
    this.dischargePressure,
    this.suctionLineTemp,
    this.liquidLineTemp,
    this.supplyAirTemp,
    this.returnAirTemp,
    this.ambientTemp,
    this.superheat,
    this.subcool,
    this.outcome,
    this.technicianNotes,
    this.adjustmentsMade,
    this.isAnonymized = true,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'jobId': jobId,
      'technicianId': technicianId,
      'timestamp': Timestamp.fromDate(timestamp),
      'systemType': systemType.name,
      'refrigerant': refrigerant.name,
      'equipmentInfo': equipmentInfo,
      'isFixedOrifice': isFixedOrifice,
      'suctionPressure': suctionPressure,
      'dischargePressure': dischargePressure,
      'suctionLineTemp': suctionLineTemp,
      'liquidLineTemp': liquidLineTemp,
      'supplyAirTemp': supplyAirTemp,
      'returnAirTemp': returnAirTemp,
      'ambientTemp': ambientTemp,
      'superheat': superheat,
      'subcool': subcool,
      'outcome': outcome?.name,
      'technicianNotes': technicianNotes,
      'adjustmentsMade': adjustmentsMade,
      'isAnonymized': isAnonymized,
    };
  }

  factory HvacReading.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HvacReading(
      id: doc.id,
      jobId: data['jobId'] as String?,
      technicianId: data['technicianId'] as String?,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      systemType: JobType.values.firstWhere(
        (e) => e.name == data['systemType'],
        orElse: () => JobType.airConditioning,
      ),
      refrigerant: Refrigerant.values.firstWhere(
        (e) => e.name == data['refrigerant'],
        orElse: () => Refrigerant.r410a,
      ),
      equipmentInfo: data['equipmentInfo'] as String?,
      isFixedOrifice: data['isFixedOrifice'] as bool?,
      suctionPressure: data['suctionPressure'] as double?,
      dischargePressure: data['dischargePressure'] as double?,
      suctionLineTemp: data['suctionLineTemp'] as double?,
      liquidLineTemp: data['liquidLineTemp'] as double?,
      supplyAirTemp: data['supplyAirTemp'] as double?,
      returnAirTemp: data['returnAirTemp'] as double?,
      ambientTemp: data['ambientTemp'] as double?,
      superheat: data['superheat'] as double?,
      subcool: data['subcool'] as double?,
      outcome: data['outcome'] != null
          ? ReadingOutcome.values.firstWhere(
              (e) => e.name == data['outcome'],
              orElse: () => ReadingOutcome.unknown,
            )
          : null,
      technicianNotes: data['technicianNotes'] as String?,
      adjustmentsMade: (data['adjustmentsMade'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      isAnonymized: data['isAnonymized'] as bool? ?? true,
    );
  }

  HvacReading copyWith({
    String? id,
    String? jobId,
    String? technicianId,
    DateTime? timestamp,
    JobType? systemType,
    Refrigerant? refrigerant,
    String? equipmentInfo,
    bool? isFixedOrifice,
    double? suctionPressure,
    double? dischargePressure,
    double? suctionLineTemp,
    double? liquidLineTemp,
    double? supplyAirTemp,
    double? returnAirTemp,
    double? ambientTemp,
    double? superheat,
    double? subcool,
    ReadingOutcome? outcome,
    String? technicianNotes,
    List<String>? adjustmentsMade,
    bool? isAnonymized,
  }) {
    return HvacReading(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      technicianId: technicianId ?? this.technicianId,
      timestamp: timestamp ?? this.timestamp,
      systemType: systemType ?? this.systemType,
      refrigerant: refrigerant ?? this.refrigerant,
      equipmentInfo: equipmentInfo ?? this.equipmentInfo,
      isFixedOrifice: isFixedOrifice ?? this.isFixedOrifice,
      suctionPressure: suctionPressure ?? this.suctionPressure,
      dischargePressure: dischargePressure ?? this.dischargePressure,
      suctionLineTemp: suctionLineTemp ?? this.suctionLineTemp,
      liquidLineTemp: liquidLineTemp ?? this.liquidLineTemp,
      supplyAirTemp: supplyAirTemp ?? this.supplyAirTemp,
      returnAirTemp: returnAirTemp ?? this.returnAirTemp,
      ambientTemp: ambientTemp ?? this.ambientTemp,
      superheat: superheat ?? this.superheat,
      subcool: subcool ?? this.subcool,
      outcome: outcome ?? this.outcome,
      technicianNotes: technicianNotes ?? this.technicianNotes,
      adjustmentsMade: adjustmentsMade ?? this.adjustmentsMade,
      isAnonymized: isAnonymized ?? this.isAnonymized,
    );
  }
}

/// Outcome of a diagnostic reading
enum ReadingOutcome {
  pass, // System within normal parameters
  adjusted, // Technician made adjustments (charging, etc.)
  failed, // System has issues requiring repair
  unknown, // Not yet determined
}
