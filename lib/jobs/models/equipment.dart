import 'package:cloud_firestore/cloud_firestore.dart';

enum SystemType {
  ac,
  heatPump,
  furnace,
}

enum EquipmentType {
  condenser,
  evaporatorCoil,
  airHandler,
  furnace,
}

class Equipment {
  final String id;
  final String jobId;
  final EquipmentType type;
  final SystemType? systemType;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final String? refrigerantType;
  final double? voltage;
  final double? mca; // Minimum Circuit Ampacity
  final double? mop; // Maximum Overcurrent Protection
  final double? rla; // Rated Load Amps
  final double? fla; // Full Load Amps
  final String? nameplateImageUrl;
  final Map<String, dynamic>? ocrData;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Equipment({
    required this.id,
    required this.jobId,
    required this.type,
    this.systemType,
    this.brand,
    this.model,
    this.serialNumber,
    this.refrigerantType,
    this.voltage,
    this.mca,
    this.mop,
    this.rla,
    this.fla,
    this.nameplateImageUrl,
    this.ocrData,
    required this.createdAt,
    this.updatedAt,
  });

  factory Equipment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Equipment(
      id: doc.id,
      jobId: data['jobId'] as String,
      type: EquipmentType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => EquipmentType.condenser,
      ),
      systemType: data['systemType'] != null
          ? SystemType.values.firstWhere(
              (e) => e.name == data['systemType'],
              orElse: () => SystemType.ac,
            )
          : null,
      brand: data['brand'] as String?,
      model: data['model'] as String?,
      serialNumber: data['serialNumber'] as String?,
      refrigerantType: data['refrigerantType'] as String?,
      voltage: data['voltage'] as double?,
      mca: data['mca'] as double?,
      mop: data['mop'] as double?,
      rla: data['rla'] as double?,
      fla: data['fla'] as double?,
      nameplateImageUrl: data['nameplateImageUrl'] as String?,
      ocrData: data['ocrData'] as Map<String, dynamic>?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'jobId': jobId,
      'type': type.name,
      'systemType': systemType?.name,
      'brand': brand,
      'model': model,
      'serialNumber': serialNumber,
      'refrigerantType': refrigerantType,
      'voltage': voltage,
      'mca': mca,
      'mop': mop,
      'rla': rla,
      'fla': fla,
      'nameplateImageUrl': nameplateImageUrl,
      'ocrData': ocrData,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Equipment copyWith({
    String? id,
    String? jobId,
    EquipmentType? type,
    SystemType? systemType,
    String? brand,
    String? model,
    String? serialNumber,
    String? refrigerantType,
    double? voltage,
    double? mca,
    double? mop,
    double? rla,
    double? fla,
    String? nameplateImageUrl,
    Map<String, dynamic>? ocrData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Equipment(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      type: type ?? this.type,
      systemType: systemType ?? this.systemType,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      refrigerantType: refrigerantType ?? this.refrigerantType,
      voltage: voltage ?? this.voltage,
      mca: mca ?? this.mca,
      mop: mop ?? this.mop,
      rla: rla ?? this.rla,
      fla: fla ?? this.fla,
      nameplateImageUrl: nameplateImageUrl ?? this.nameplateImageUrl,
      ocrData: ocrData ?? this.ocrData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
