import 'package:cloud_firestore/cloud_firestore.dart';

enum StepType {
  locationCapture,
  customerInfo,
  systemTypeSelection,
  nameplateOcr,
  equipmentForm,
  modeSelection,
  gaugeConnection,
  stabilization,
  temperatureEntry,
  ampDrawMeasurement,
  diagnostics,
  completion,
}

enum StepStatus {
  pending,
  inProgress,
  completed,
  skipped,
}

class JobStep {
  final String id;
  final String jobId;
  final StepType type;
  final StepStatus status;
  final int orderIndex;
  final String? title;
  final String? description;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final DateTime? completedAt;

  JobStep({
    required this.id,
    required this.jobId,
    required this.type,
    required this.status,
    required this.orderIndex,
    this.title,
    this.description,
    this.data,
    required this.createdAt,
    this.completedAt,
  });

  factory JobStep.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobStep(
      id: doc.id,
      jobId: data['jobId'] as String,
      type: StepType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => StepType.completion,
      ),
      status: StepStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => StepStatus.pending,
      ),
      orderIndex: data['orderIndex'] as int,
      title: data['title'] as String?,
      description: data['description'] as String?,
      data: data['data'] as Map<String, dynamic>?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'jobId': jobId,
      'type': type.name,
      'status': status.name,
      'orderIndex': orderIndex,
      'title': title,
      'description': description,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  JobStep copyWith({
    String? id,
    String? jobId,
    StepType? type,
    StepStatus? status,
    int? orderIndex,
    String? title,
    String? description,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return JobStep(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      type: type ?? this.type,
      status: status ?? this.status,
      orderIndex: orderIndex ?? this.orderIndex,
      title: title ?? this.title,
      description: description ?? this.description,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
