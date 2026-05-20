import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/job.dart';
import '../models/equipment.dart';
import '../models/job_step.dart';

class JobService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new job
  Future<Job> createJob(JobType type) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final jobData = Job(
      id: '',
      userId: user.uid,
      type: type,
      status: JobStatus.pending,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore.collection('jobs').add(jobData.toFirestore());
    
    // Initialize workflow steps based on job type
    await _initializeWorkflowSteps(docRef.id, type);

    return jobData.copyWith(id: docRef.id);
  }

  // Initialize workflow steps for a job
  Future<void> _initializeWorkflowSteps(String jobId, JobType type) async {
    List<JobStep> steps = [];
    int orderIndex = 0;

    // Common initial steps
    steps.add(JobStep(
      id: '',
      jobId: jobId,
      type: StepType.locationCapture,
      status: StepStatus.pending,
      orderIndex: orderIndex++,
      title: 'Capture Location',
      description: 'Auto-detect job location using GPS',
      createdAt: DateTime.now(),
    ));

    steps.add(JobStep(
      id: '',
      jobId: jobId,
      type: StepType.customerInfo,
      status: StepStatus.pending,
      orderIndex: orderIndex++,
      title: 'Customer Information',
      description: 'Enter customer or business name',
      createdAt: DateTime.now(),
    ));

    if (type == JobType.commissioning) {
      // Commissioning-specific steps
      steps.addAll([
        JobStep(
          id: '',
          jobId: jobId,
          type: StepType.systemTypeSelection,
          status: StepStatus.pending,
          orderIndex: orderIndex++,
          title: 'System Type',
          description: 'Select AC or Heat Pump',
          createdAt: DateTime.now(),
        ),
        JobStep(
          id: '',
          jobId: jobId,
          type: StepType.nameplateOcr,
          status: StepStatus.pending,
          orderIndex: orderIndex++,
          title: 'Scan Equipment',
          description: 'Photograph unit nameplates',
          createdAt: DateTime.now(),
        ),
        JobStep(
          id: '',
          jobId: jobId,
          type: StepType.modeSelection,
          status: StepStatus.pending,
          orderIndex: orderIndex++,
          title: 'System Mode',
          description: 'Start system in AC or Heat mode',
          createdAt: DateTime.now(),
        ),
        JobStep(
          id: '',
          jobId: jobId,
          type: StepType.gaugeConnection,
          status: StepStatus.pending,
          orderIndex: orderIndex++,
          title: 'Connect Gauges',
          description: 'Connect pressure gauges and temperature probes',
          createdAt: DateTime.now(),
        ),
        JobStep(
          id: '',
          jobId: jobId,
          type: StepType.stabilization,
          status: StepStatus.pending,
          orderIndex: orderIndex++,
          title: 'System Stabilization',
          description: '20-minute stabilization period',
          createdAt: DateTime.now(),
        ),
        JobStep(
          id: '',
          jobId: jobId,
          type: StepType.ampDrawMeasurement,
          status: StepStatus.pending,
          orderIndex: orderIndex++,
          title: 'Amp Draw Readings',
          description: 'Measure blower, fan, and compressor amps',
          createdAt: DateTime.now(),
        ),
        JobStep(
          id: '',
          jobId: jobId,
          type: StepType.diagnostics,
          status: StepStatus.pending,
          orderIndex: orderIndex++,
          title: 'System Diagnostics',
          description: 'Review readings and adjust as needed',
          createdAt: DateTime.now(),
        ),
      ]);
    } else {
      // Service call - simpler support flow
      steps.add(JobStep(
        id: '',
        jobId: jobId,
        type: StepType.diagnostics,
        status: StepStatus.pending,
        orderIndex: orderIndex++,
        title: 'Diagnostics',
        description: 'Document your findings and chat with our support team',
        createdAt: DateTime.now(),
      ));
    }

    // Final completion step
    steps.add(JobStep(
      id: '',
      jobId: jobId,
      type: StepType.completion,
      status: StepStatus.pending,
      orderIndex: orderIndex++,
      title: 'Complete Job',
      description: 'Mark job as complete',
      createdAt: DateTime.now(),
    ));

    // Save all steps to Firestore
    for (final step in steps) {
      await _firestore.collection('jobSteps').add(step.toFirestore());
    }
  }

  // Get job by ID
  Future<Job?> getJob(String jobId) async {
    final doc = await _firestore.collection('jobs').doc(jobId).get();
    if (!doc.exists) return null;
    
    final job = Job.fromFirestore(doc);
    final user = _auth.currentUser;
    if (user == null || job.userId != user.uid) {
      throw Exception('Unauthorized: Cannot access job owned by another user');
    }
    
    return job;
  }

  // Get user's jobs
  Stream<List<Job>> getUserJobs() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('jobs')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList());
  }

  // Get job steps
  Stream<List<JobStep>> getJobSteps(String jobId) {
    return _firestore
        .collection('jobSteps')
        .where('jobId', isEqualTo: jobId)
        .orderBy('orderIndex')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => JobStep.fromFirestore(doc)).toList());
  }

  // Update job
  Future<void> updateJob(Job job) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    if (job.userId != user.uid) {
      throw Exception('Unauthorized: Cannot update job owned by another user');
    }

    await _firestore.collection('jobs').doc(job.id).update(
          job.copyWith(updatedAt: DateTime.now()).toFirestore(),
        );
  }

  // Update job step
  Future<void> updateJobStep(JobStep step) async {
    await _firestore.collection('jobSteps').doc(step.id).update(step.toFirestore());
  }

  // Complete job step
  Future<void> completeJobStep(String stepId) async {
    await _firestore.collection('jobSteps').doc(stepId).update({
      'status': StepStatus.completed.name,
      'completedAt': Timestamp.now(),
    });
  }

  // Add equipment to job
  Future<Equipment> addEquipment(Equipment equipment) async {
    final docRef = await _firestore.collection('equipment').add(equipment.toFirestore());
    return equipment.copyWith(id: docRef.id);
  }

  // Get job equipment
  Stream<List<Equipment>> getJobEquipment(String jobId) {
    return _firestore
        .collection('equipment')
        .where('jobId', isEqualTo: jobId)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Equipment.fromFirestore(doc)).toList());
  }

  // Update equipment
  Future<void> updateEquipment(Equipment equipment) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Verify the equipment's job belongs to the current user
    final job = await getJob(equipment.jobId);
    if (job == null || job.userId != user.uid) {
      throw Exception('Unauthorized: Cannot update equipment for job owned by another user');
    }

    await _firestore.collection('equipment').doc(equipment.id).update(
          equipment.copyWith(updatedAt: DateTime.now()).toFirestore(),
        );
  }

  // Complete job
  Future<void> completeJob(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    await _firestore.runTransaction((transaction) async {
      final jobRef = _firestore.collection('jobs').doc(jobId);
      final snapshot = await transaction.get(jobRef);

      if (!snapshot.exists) {
        throw Exception('Job not found');
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      final jobUserId = data?['userId'] as String?;

      if (jobUserId == null || jobUserId != user.uid) {
        throw Exception('Unauthorized: Cannot complete job owned by another user');
      }

      transaction.update(jobRef, {
        'status': JobStatus.completed.name,
        'completedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    });
  }
}
