import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/gradient_scaffold.dart';

class AdminDispatchScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const AdminDispatchScreen({super.key, required this.onToggleTheme});

  @override
  State<AdminDispatchScreen> createState() => _AdminDispatchScreenState();
}

class _AdminDispatchScreenState extends State<AdminDispatchScreen> {
  String _filter = 'new';
  String? _selectedTech;
  String? _selectedCustomer;
  DateTimeRange? _dateRange;
  final List<String> _selectedMessageIds = [];
  final List<Map<String, dynamic>> _techs = [];

  @override
  void initState() {
    super.initState();
    _loadTechs();
  }

  Future<void> _loadTechs() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'tech')
              .get();

      setState(() {
        _techs.clear();
        for (var doc in snapshot.docs) {
          _techs.add({'id': doc.id, 'email': doc['email'] ?? 'Unknown'});
        }
      });
    } catch (e) {
      debugPrint('Error loading techs: $e');
    }
  }

  Future<void> _assignToTech(String messageId, String techId) async {
    try {
      await FirebaseFirestore.instance
          .collection('incomingSMS')
          .doc(messageId)
          .update({'status': 'assigned', 'assignedTechId': techId});
    } catch (e) {
      debugPrint('Error assigning message: $e');
    }
  }

  Future<void> _assignMultipleToTech(
    List<String> messageIds,
    String techId,
  ) async {
    try {
      for (final messageId in messageIds) {
        await FirebaseFirestore.instance
            .collection('incomingSMS')
            .doc(messageId)
            .update({'status': 'assigned', 'assignedTechId': techId});
      }
      setState(() {
        _selectedMessageIds.clear();
      });
    } catch (e) {
      debugPrint('Error bulk assigning: $e');
    }
  }

  Future<void> _createDispatchDialog() async {
    final formKey = GlobalKey<FormState>();
    String title = '';
    String description = '';
    String location = '';
    String phone = '';
    DateTime? scheduledDate;
    String? customerId;

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setLocalState) => AlertDialog(
                  title: const Text('New Dispatch'),
                  content: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Title',
                            ),
                            onChanged: (v) => title = v.trim(),
                            validator:
                                (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                          ),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Description',
                            ),
                            onChanged: (v) => description = v.trim(),
                          ),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Location',
                            ),
                            onChanged: (v) => location = v.trim(),
                          ),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                            ),
                            keyboardType: TextInputType.phone,
                            onChanged: (v) => phone = v.trim(),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                scheduledDate == null
                                    ? 'No date'
                                    : 'Date: ${scheduledDate!.toLocal().toString().split(' ').first}',
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                    initialDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setLocalState(() => scheduledDate = picked);
                                  }
                                },
                                child: const Text('Pick Date'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            future:
                                FirebaseFirestore.instance
                                    .collection('customers')
                                    .orderBy('name')
                                    .limit(100)
                                    .get(),
                            builder: (context, snap) {
                              final docs = snap.data?.docs ?? [];
                              return DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Customer',
                                ),
                                items: [
                                  for (final d in docs)
                                    DropdownMenuItem(
                                      value: d.id,
                                      child: Text(d.data()['name'] ?? d.id),
                                    ),
                                ],
                                onChanged: (v) => customerId = v,
                                validator: (v) => v == null ? 'Required' : null,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        try {
                          await FirebaseFirestore.instance
                              .collection('jobDispatch')
                              .add({
                                'title': title,
                                'description': description,
                                'location': location,
                                'phone': phone,
                                'scheduledDate':
                                    scheduledDate == null
                                        ? null
                                        : Timestamp.fromDate(scheduledDate!),
                                'customerId': customerId,
                                'status': 'unassigned',
                                'createdAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                          if (context.mounted) Navigator.of(ctx).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Dispatch created')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Create'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _createDraftInvoice(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final priceSnap =
          await FirebaseFirestore.instance
              .collection('pricebook')
              .limit(100)
              .get();
      final items =
          priceSnap.docs
              .map(
                (d) => {
                  'itemId': d.id,
                  'name': d.data()['name'],
                  'price': (d.data()['price'] ?? 0) as num,
                  'qty': 1,
                },
              )
              .toList();

      final subtotal = items.fold<num>(
        0,
        (s, it) => s + (it['price'] as num) * (it['qty'] as num),
      );

      await FirebaseFirestore.instance.collection('invoices').add({
        'jobId': doc.id,
        'customerId': data['customerId'],
        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
        'lineItems': items,
        'subtotal': subtotal,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Draft invoice created')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Query _buildQuery() {
    // Align with web UI: jobDispatch collection
    Query query = FirebaseFirestore.instance.collection('jobDispatch');

    // Apply status filter
    if (_filter == 'new') {
      query = query.where('status', isEqualTo: 'unassigned');
    } else if (_filter == 'assigned') {
      query = query.where('status', isEqualTo: 'assigned');
    } else if (_filter == 'replied') {
      // Optional: include completed or replied jobs if used
      query = query.where('status', isEqualTo: 'completed');
    }

    // Apply tech filter
    if (_selectedTech != null) {
      query = query.where('assignedTechId', isEqualTo: _selectedTech);
    }

    // Apply date range
    if (_dateRange != null) {
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_dateRange!.start),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(_dateRange!.end),
          );
    }

    // Avoid requiring composite index; sort client-side instead.
    return query;
  }

  Widget _buildMessageCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'Untitled';
    final customerName = data['customerName'] ?? 'Unknown';
    final description = data['description'] ?? '';
    final location = data['location'] ?? '';
    final phone = data['phone'] ?? '';
    final status = data['status'] ?? 'unassigned';
    final scheduledDate = data['scheduledDate'] ?? '';

    final techEmail =
        _techs.firstWhere(
          (t) => t['id'] == data['assignedTechId'],
          orElse: () => {'id': '', 'email': 'Unassigned'},
        )['email'] ??
        'Unassigned';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Checkbox(
          value: _selectedMessageIds.contains(doc.id),
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                _selectedMessageIds.add(doc.id);
              } else {
                _selectedMessageIds.remove(doc.id);
              }
            });
          },
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: $customerName'),
            if (description.isNotEmpty)
              Text(
                description.length > 80
                    ? '${description.substring(0, 80)}...'
                    : description,
              ),
            if (location.isNotEmpty) Text('Location: $location'),
            if (phone.isNotEmpty) Text('Phone: $phone'),
            if (scheduledDate.toString().isNotEmpty)
              Text('Scheduled: $scheduledDate'),
            Text('Status: $status'),
            Text('Assigned to: $techEmail'),
          ],
        ),
        trailing: DropdownButton<String>(
          hint: const Text('Assign'),
          value: null,
          items:
              _techs.map((tech) {
                return DropdownMenuItem<String>(
                  value: tech['id'],
                  child: Text(tech['email']),
                );
              }).toList(),
          onChanged: (techId) {
            if (techId != null) _assignToTech(doc.id, techId);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dispatch Board'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(
              Icons.brightness_6,
              color: AppColors.textSecondary,
            ),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: Icon(Icons.add_task, color: AppColors.textSecondary),
            onPressed: _createDispatchDialog,
            tooltip: 'New Dispatch',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Status filter
                    DropdownButton<String>(
                      value: _filter,
                      items: const [
                        DropdownMenuItem(value: 'new', child: Text('New')),
                        DropdownMenuItem(
                          value: 'assigned',
                          child: Text('Assigned'),
                        ),
                        DropdownMenuItem(
                          value: 'replied',
                          child: Text('Replied'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _filter = val);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    // Tech filter
                    DropdownButton<String>(
                      value: _selectedTech,
                      hint: const Text('Filter by Tech'),
                      items:
                          _techs.map((tech) {
                            return DropdownMenuItem<String>(
                              value: tech['id'],
                              child: Text(tech['email']),
                            );
                          }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedTech = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    // Customer filter
                    FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      future:
                          FirebaseFirestore.instance
                              .collection('customers')
                              .limit(200)
                              .get(),
                      builder: (context, snap) {
                        final customers = snap.data?.docs ?? [];
                        return DropdownButton<String>(
                          value: _selectedCustomer,
                          hint: const Text('Filter by Customer'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All'),
                            ),
                            ...customers.map(
                              (c) => DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(
                                  (c.data()['name'] ?? c.id) as String,
                                ),
                              ),
                            ),
                          ],
                          onChanged:
                              (val) => setState(() => _selectedCustomer = val),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Date range filter
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _dateRange = picked);
                        }
                      },
                      child: Text(
                        _dateRange == null
                            ? 'Filter by Date'
                            : '${_dateRange!.start.month}/${_dateRange!.start.day} - ${_dateRange!.end.month}/${_dateRange!.end.day}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedMessageIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedTech,
                        hint: const Text('Assign selected to Tech'),
                        items:
                            _techs.map((tech) {
                              return DropdownMenuItem<String>(
                                value: tech['id'],
                                child: Text(tech['email']),
                              );
                            }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedTech = val);
                        },
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          _selectedTech != null
                              ? () => _assignMultipleToTech(
                                _selectedMessageIds,
                                _selectedTech!,
                              )
                              : null,
                      child: const Text('Bulk Assign'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    (() {
                      var q = _buildQuery();
                      if (_selectedCustomer != null) {
                        q = q.where('customerId', isEqualTo: _selectedCustomer);
                      }
                      return q.snapshots();
                    })(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No messages'));
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    child: ListView(
                      children:
                          (() {
                            final docs = snapshot.data!.docs.toList();
                            docs.sort((a, b) {
                              final ma = a.data() as Map<String, dynamic>;
                              final mb = b.data() as Map<String, dynamic>;
                              final ta = ma['updatedAt'] ?? ma['createdAt'];
                              final tb = mb['updatedAt'] ?? mb['createdAt'];
                              final da =
                                  ta is Timestamp
                                      ? ta.toDate()
                                      : DateTime.fromMillisecondsSinceEpoch(0);
                              final db =
                                  tb is Timestamp
                                      ? tb.toDate()
                                      : DateTime.fromMillisecondsSinceEpoch(0);
                              return db.compareTo(da); // descending
                            });
                            return docs.map((d) {
                              final card = _buildMessageCard(d);
                              return Column(
                                children: [
                                  ListTile(
                                    trailing: IconButton(
                                      tooltip: 'Create Invoice',
                                      icon: const Icon(Icons.receipt_long),
                                      onPressed: () => _createDraftInvoice(d),
                                    ),
                                  ),
                                  card,
                                ],
                              );
                            }).toList();
                          })(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
