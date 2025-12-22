import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/gradient_scaffold.dart';

class DispatchScreen extends StatefulWidget {
  final String? adminUserId;
  final Function()? onThemeToggle;

  const DispatchScreen({super.key, this.adminUserId, this.onThemeToggle});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  late FirebaseFirestore _db;
  DateTime _selectedDate = DateTime.now();
  String _filterStatus = 'all'; // all, unassigned, assigned, completed
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _db = FirebaseFirestore.instance;
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Fetch all jobs (Firestore doesn't support complex client-side filtering as easily)
      final snapshot = await _db.collection('jobDispatch').get();

      List<Map<String, dynamic>> jobs = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final scheduledDate = data['scheduledDate'] as String?;

        // Filter by selected date
        if (scheduledDate != null && scheduledDate.startsWith(dateStr)) {
          // Filter by status if not 'all'
          if (_filterStatus == 'all' || data['status'] == _filterStatus) {
            jobs.add({'id': doc.id, ...data});
          }
        }
      }

      // Sort by scheduled time
      jobs.sort((a, b) {
        final timeA = a['scheduledDate'] as String? ?? '';
        final timeB = b['scheduledDate'] as String? ?? '';
        return timeA.compareTo(timeB);
      });

      if (mounted) {
        setState(() {
          _jobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading jobs: $e');
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading jobs: $e')));
      }
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadJobs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('📋 Dispatch Board'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.onThemeToggle != null)
            IconButton(
              icon: Icon(
                Icons.brightness_6,
                color: AppColors.textSecondary,
              ),
              onPressed: widget.onThemeToggle,
              tooltip: 'Toggle Theme',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryCyan,
                ),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Navigation
                      _buildDateNavigation(),
                      const SizedBox(height: 20),

                      // Filter Buttons
                      _buildFilterButtons(),
                      const SizedBox(height: 20),

                      // Jobs List
                      _buildJobsList(),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.buttonGradientStart.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: 'dispatch_screen_fab',
          onPressed: () => _showCreateJobModal(context),
          tooltip: 'New Job',
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDateNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => _changeDate(-1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                onPressed: () => _changeDate(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => setState(() {
                  _selectedDate = DateTime.now();
                  _loadJobs();
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Today'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    final filters = [
      {'value': 'all', 'label': 'All'},
      {'value': 'unassigned', 'label': 'Unassigned'},
      {'value': 'assigned', 'label': 'Assigned'},
      {'value': 'completed', 'label': 'Completed'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isActive = _filterStatus == filter['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(filter['label'] as String),
              selected: isActive,
              onSelected: (_) {
                setState(() => _filterStatus = filter['value'] as String);
                _loadJobs();
              },
              backgroundColor: Colors.transparent,
              selectedColor: const Color(0xFF667eea),
              side: BorderSide(
                color: isActive ? const Color(0xFF667eea) : Colors.grey,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildJobsList() {
    if (_jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'No jobs found',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _jobs.map((job) {
        return _buildJobCard(job);
      }).toList(),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status'] as String? ?? 'unassigned';
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          job['title'] as String? ?? 'Untitled Job',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              job['location'] as String? ?? 'No location',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  'Time',
                  job['scheduledDate'] as String? ?? 'N/A',
                ),
                _buildDetailRow(
                  'Customer',
                  job['customerName'] as String? ?? 'N/A',
                ),
                _buildDetailRow('Phone', job['phone'] as String? ?? 'N/A'),
                _buildDetailRow(
                  'Description',
                  job['description'] as String? ?? 'No description',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _updateJobStatus(job['id'], 'assigned'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                        ),
                        child: const Text('Assign'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _updateJobStatus(job['id'], 'completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Complete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'unconfirmed':
      case 'unassigned':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateJobStatus(String jobId, String newStatus) async {
    try {
      await _db.collection('jobDispatch').doc(jobId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadJobs();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Job marked as $newStatus')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating job: $e')));
      }
    }
  }

  void _showCreateJobModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            '✏️ Job creation coming soon!\n\nCreate jobs from the admin dashboard.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
