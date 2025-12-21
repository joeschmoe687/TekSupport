import 'package:cloud_firestore/cloud_firestore.dart';

enum JobType {
  commissioning,
  serviceCall,
}

enum JobStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

class Job {
  final String id;
  final String userId;
  final JobType type;
  final JobStatus status;
  final String? customerName;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;

  Job({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    this.customerName,
    this.locationAddress,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.metadata,
  });

  factory Job.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Job(
      id: doc.id,
      userId: data['userId'] as String,
      type: JobType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => JobType.serviceCall,
      ),
      status: JobStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => JobStatus.pending,
      ),
      customerName: data['customerName'] as String?,
      locationAddress: data['locationAddress'] as String?,
      latitude: data['latitude'] as double?,
      longitude: data['longitude'] as double?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.name,
      'status': status.name,
      'customerName': customerName,
      'locationAddress': locationAddress,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'metadata': metadata,
    };
  }

  Job copyWith({
    String? id,
    String? userId,
    JobType? type,
    JobStatus? status,
    String? customerName,
    String? locationAddress,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Job(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      customerName: customerName ?? this.customerName,
      locationAddress: locationAddress ?? this.locationAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
