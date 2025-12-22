import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dispatch_screen.dart';
import '../widgets/gradient_scaffold.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const AdminDashboardScreen({super.key, required this.onToggleTheme});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAdmin = false;
  bool _roleLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isAdmin = false;
          _roleLoaded = true;
          _tabController = TabController(length: 6, vsync: this);
        });
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      final role = (data['role'] ?? '').toString().toLowerCase();
      final isAdmin = role == 'admin';
      setState(() {
        _isAdmin = isAdmin;
        _roleLoaded = true;
        _tabController = TabController(length: isAdmin ? 7 : 6, vsync: this);
      });
    } catch (_) {
      setState(() {
        _isAdmin = false;
        _roleLoaded = true;
        _tabController = TabController(length: 6, vsync: this);
      });
    }
  }

  @override
  void dispose() {
    if (_roleLoaded) {
      _tabController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabLabelStyle = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    // Show loading indicator until role is loaded
    if (!_roleLoaded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryCyan),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryCyan,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: tabLabelStyle,
          tabs: [
            const Tab(
              icon: Icon(Icons.dashboard, color: AppColors.textSecondary),
              text: 'Overview',
            ),
            const Tab(
              icon: Icon(Icons.assignment, color: AppColors.textSecondary),
              text: 'Dispatch',
            ),
            const Tab(
              icon: Icon(Icons.people, color: AppColors.textSecondary),
              text: 'Customers',
            ),
            const Tab(
              icon: Icon(Icons.receipt_long, color: AppColors.textSecondary),
              text: 'Invoices',
            ),
            const Tab(
              icon: Icon(Icons.price_change, color: AppColors.textSecondary),
              text: 'Pricebook',
            ),
            const Tab(
              icon: Icon(Icons.settings, color: AppColors.textSecondary),
              text: 'Settings',
            ),
            if (_isAdmin)
              const Tab(
                icon: Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.textSecondary,
                ),
                text: 'Admin',
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.brightness_6,
              color: AppColors.textSecondary,
            ),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Overview
            _OverviewPane(primaryAccent: AppColors.primaryCyan),
            // Dispatch (existing screen)
            DispatchScreen(onThemeToggle: widget.onToggleTheme),
            // Customers
            const _CustomersPane(),
            // Invoices
            const _InvoicesPane(),
            // Pricebook
            const _PricebookPane(),
            // Settings
            const _SettingsPane(),
            if (_isAdmin) const _AdminPane(),
          ],
        ),
      ),
    );
  }
}

class _AdminPane extends StatelessWidget {
  const _AdminPane();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Developer Tools',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tools for debugging and device integration',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Device Registry Card
          _AdminToolCard(
            icon: Icons.device_hub,
            title: 'Device Registry',
            description:
                'View and manage supported HVAC tool profiles (Weytek, CCS, Testo, etc.)',
            accentColor: AppColors.accentBlue,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Device Registry coming soon'),
                  backgroundColor: AppColors.warning,
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // ML Device Learning Card
          _AdminToolCard(
            icon: Icons.psychology,
            title: 'ML Device Learning',
            description:
                'Train the app to recognize new Bluetooth HVAC devices automatically',
            accentColor: AppColors.primaryPurple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const _MLDeviceLearningScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // P/T Chart Tester Card
          _AdminToolCard(
            icon: Icons.thermostat,
            title: 'P/T Chart Tester',
            description:
                'Test superheat/subcool calculations for different refrigerants',
            accentColor: AppColors.success,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('P/T Chart Tester coming soon'),
                  backgroundColor: AppColors.warning,
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Debug Info Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.textMuted, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Debug Info',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DebugInfoRow(label: 'App Version', value: '1.0.0'),
                _DebugInfoRow(label: 'Flutter BLE+', value: '1.36.8'),
                _DebugInfoRow(label: 'Hive Storage', value: 'Enabled'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final VoidCallback onTap;

  const _AdminToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: accentColor, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _DebugInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _OverviewPane extends StatelessWidget {
  final Color primaryAccent;
  const _OverviewPane({required this.primaryAccent});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome, Admin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Quick stats and shortcuts',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _JobsTodayStat(accent: primaryAccent)),
              const SizedBox(width: 12),
              Expanded(child: _OpenInvoicesStat(accent: primaryAccent)),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _QuickAction(icon: Icons.assignment, label: 'Create Job'),
              _QuickAction(icon: Icons.person_add, label: 'Add Customer'),
              _QuickAction(icon: Icons.receipt, label: 'New Invoice'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobsTodayStat extends StatelessWidget {
  final Color accent;
  const _JobsTodayStat({required this.accent});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final todayStr = '$yyyy-$mm-$dd';

    // jobDispatch date stored as 'YYYY-MM-DD' in web fix
    final query = FirebaseFirestore.instance
        .collection('jobDispatch')
        .where('date', isEqualTo: todayStr);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return _StatCard(label: 'Jobs Today', value: '$count', accent: accent);
      },
    );
  }
}

class _OpenInvoicesStat extends StatelessWidget {
  final Color accent;
  const _OpenInvoicesStat({required this.accent});

  @override
  Widget build(BuildContext context) {
    // Count invoices where status != 'paid'
    final query = FirebaseFirestore.instance
        .collection('invoices')
        .where('status', isNotEqualTo: 'paid');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return _StatCard(
          label: 'Open Invoices',
          value: '$count',
          accent: accent,
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  const _QuickAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4EC7F3).withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

// Removed placeholder pane after wiring real panes

class _PricebookPane extends StatefulWidget {
  const _PricebookPane();

  @override
  State<_PricebookPane> createState() => _PricebookPaneState();
}

class _PricebookPaneState extends State<_PricebookPane> {
  final Set<String> _expandedCategories = {}; // Track expanded categories

  @override
  Widget build(BuildContext context) {
    // Assumes collections: 'pricebookCategories' and 'pricebookItems' with item.categoryId
    final categoriesStream = FirebaseFirestore.instance
        .collection('pricebookCategories')
        .orderBy('name')
        .snapshots();
    final itemsStream =
        FirebaseFirestore.instance.collection('pricebookItems').snapshots();
    final pricingStream = FirebaseFirestore.instance
        .collection('settings')
        .doc('pricing')
        .snapshots();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pricebook',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Local jobs pricing and remote support',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                // Support Chat Pricing Section
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: pricingStream,
                  builder: (context, snapshot) {
                    final pricing = snapshot.data?.data() ?? {};
                    return _buildSupportPricingCard(context, pricing);
                  },
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),

                // Local Jobs Categories
                const Text(
                  'Local Jobs Pricing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: categoriesStream,
                  builder: (context, catSnap) {
                    if (!catSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final categories = catSnap.data!.docs;
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: itemsStream,
                      builder: (context, itemSnap) {
                        final items = itemSnap.hasData
                            ? itemSnap.data!.docs
                            : const <QueryDocumentSnapshot<
                                Map<String, dynamic>>>[];
                        return Column(
                          children: categories.map((catDoc) {
                            final cat = catDoc.data();
                            final catId = (cat['id'] ?? catDoc.id).toString();
                            final name = (cat['name'] ?? 'Category').toString();
                            final categoryItems = items.where((d) {
                              final data = d.data();
                              final itemCatId =
                                  (data['categoryId'] ?? '').toString();
                              return itemCatId == catId;
                            }).toList();

                            final isExpanded =
                                _expandedCategories.contains(catId);

                            return _buildCollapsibleCategory(
                              name: name,
                              itemCount: categoryItems.length,
                              isExpanded: isExpanded,
                              onToggle: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedCategories.remove(catId);
                                  } else {
                                    _expandedCategories.add(catId);
                                  }
                                });
                              },
                              items: categoryItems,
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportPricingCard(
      BuildContext context, Map<String, dynamic> pricing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, color: AppColors.primaryCyan, size: 20),
              SizedBox(width: 8),
              Text(
                'Remote Support Chat Pricing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Business hours pricing
          _buildPricingRow(
            'Text Chat (9-5 CST)',
            pricing['bizMessage']?.toDouble() ?? 5.0,
            'bizMessage',
            pricing,
          ),
          _buildPricingRow(
            'Phone Call (9-5 CST)',
            pricing['bizPhone']?.toDouble() ?? 45.0,
            'bizPhone',
            pricing,
          ),
          _buildPricingRow(
            'Video Call (9-5 CST)',
            pricing['bizVideo']?.toDouble() ?? 60.0,
            'bizVideo',
            pricing,
          ),
          const Divider(color: Colors.white12, height: 24),
          // 24/7 pricing
          _buildPricingRow(
            'Text Chat (24/7)',
            pricing['twentyFourMessage']?.toDouble() ?? 45.0,
            'twentyFourMessage',
            pricing,
          ),
          _buildPricingRow(
            'Phone Call (24/7)',
            pricing['twentyFourPhone']?.toDouble() ?? 60.0,
            'twentyFourPhone',
            pricing,
          ),
          _buildPricingRow(
            'Video Call (24/7)',
            pricing['twentyFourVideo']?.toDouble() ?? 80.0,
            'twentyFourVideo',
            pricing,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRow(String label, double currentPrice, String field,
      Map<String, dynamic> pricing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Text(
            '\$${currentPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.primaryCyan,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white54, size: 18),
            onPressed: () => _editPrice(label, currentPrice, field),
            tooltip: 'Edit price',
          ),
        ],
      ),
    );
  }

  Future<void> _editPrice(
      String label, double currentPrice, String field) async {
    final controller =
        TextEditingController(text: currentPrice.toStringAsFixed(2));

    final newPrice = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title:
            Text('Edit Price', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: AppColors.textSecondary),
            prefixText: '\$',
            prefixStyle: TextStyle(color: AppColors.textPrimary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null) {
                Navigator.pop(context, price);
              }
            },
            child: Text('Save', style: TextStyle(color: AppColors.primaryCyan)),
          ),
        ],
      ),
    );

    if (newPrice != null) {
      // Update in Firebase
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('pricing')
          .set({field: newPrice}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label updated to \$${newPrice.toStringAsFixed(2)}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Widget _buildCollapsibleCategory({
    required String name,
    required int itemCount,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Items: $itemCount',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white54,
            ),
            onTap: onToggle,
          ),
          if (isExpanded) ...[
            const Divider(color: Colors.white12, height: 1),
            ...items.map((itemDoc) {
              final data = itemDoc.data();
              final itemName = (data['name'] ?? 'Item').toString();
              final price = (data['price'] ?? '').toString();
              final code = (data['code'] ?? '').toString();
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                  title: Text(
                    itemName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  trailing: Text(
                    price.isEmpty ? '' : '\$$price',
                    style: const TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}

class _SettingsPane extends StatefulWidget {
  const _SettingsPane();

  @override
  State<_SettingsPane> createState() => _SettingsPaneState();
}

class _SettingsPaneState extends State<_SettingsPane> {
  @override
  Widget build(BuildContext context) {
    // Assumes a single doc 'admin' in 'settings' with booleans/toggles
    final adminSettingsStream = FirebaseFirestore.instance
        .collection('settings')
        .doc('admin')
        .snapshots();
    
    final geminiSettingsStream = FirebaseFirestore.instance
        .collection('settings')
        .doc('gemini')
        .snapshots();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Preferences, roles, integrations',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                // Admin Settings Section
                const Text(
                  'General Settings',
                  style: TextStyle(
                    color: AppColors.primaryCyan,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: adminSettingsStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data = snapshot.data!.data() ?? {};
                    final enableChatNotify =
                        (data['enableChatNotifications'] ?? true) == true;
                    final enableDispatch = (data['enableDispatch'] ?? true) == true;
                    final requireAdminLogin =
                        (data['requireAdminLogin'] ?? true) == true;
                    
                    return Column(
                      children: [
                        _SettingsToggle(
                          title: 'Chat Notifications',
                          value: enableChatNotify,
                          onChanged: (v) async {
                            await FirebaseFirestore.instance
                                .collection('settings')
                                .doc('admin')
                                .set({
                              'enableChatNotifications': v,
                            }, SetOptions(merge: true));
                          },
                        ),
                        _SettingsToggle(
                          title: 'Dispatch Enabled',
                          value: enableDispatch,
                          onChanged: (v) async {
                            await FirebaseFirestore.instance
                                .collection('settings')
                                .doc('admin')
                                .set({
                              'enableDispatch': v,
                            }, SetOptions(merge: true));
                          },
                        ),
                        _SettingsToggle(
                          title: 'Require Admin Login',
                          value: requireAdminLogin,
                          onChanged: (v) async {
                            await FirebaseFirestore.instance
                                .collection('settings')
                                .doc('admin')
                                .set({
                              'requireAdminLogin': v,
                            }, SetOptions(merge: true));
                          },
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 24),
                
                // Gemini AI Settings Section
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primaryPurple, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Gemini AI Assistant',
                      style: TextStyle(
                        color: AppColors.primaryPurple,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'AI-powered chat responses (fallback for TekMate)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: geminiSettingsStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data = snapshot.data!.data() ?? {};
                    final geminiEnabled = (data['enabled'] ?? false) == true;
                    final hasApiKey = (data['apiKey'] as String?)?.isNotEmpty ?? false;
                    
                    return Column(
                      children: [
                        _SettingsToggle(
                          title: 'Enable Gemini AI',
                          subtitle: hasApiKey ? 'API key configured' : 'API key required',
                          value: geminiEnabled,
                          onChanged: (v) async {
                            if (v && !hasApiKey) {
                              _showApiKeyDialog(context);
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('settings')
                                  .doc('gemini')
                                  .set({
                                'enabled': v,
                              }, SetOptions(merge: true));
                            }
                          },
                        ),
                        
                        // API Key Button
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            tileColor: const Color(0xFF121212),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Colors.white10),
                            ),
                            leading: Icon(
                              hasApiKey ? Icons.key : Icons.key_off,
                              color: hasApiKey ? AppColors.success : Colors.white54,
                            ),
                            title: Text(
                              hasApiKey ? 'API Key Configured' : 'Set API Key',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              hasApiKey ? 'Tap to update' : 'Required for Gemini',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, 
                                color: Colors.white54, size: 16),
                            onTap: () => _showApiKeyDialog(context),
                          ),
                        ),
                        
                        // Personality Tuning Button
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            tileColor: const Color(0xFF121212),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Colors.white10),
                            ),
                            leading: const Icon(Icons.psychology, 
                                color: AppColors.primaryPurple),
                            title: const Text(
                              'Personality Tuning',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text(
                              'Customize AI response style',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, 
                                color: Colors.white54, size: 16),
                            onTap: () => _showPersonalityDialog(context, data['personality']),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Gemini API Key', 
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google Gemini API key:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'AIza...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Get your API key from:\naistudio.google.com/app/apikey',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final apiKey = controller.text.trim();
              if (apiKey.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('settings')
                    .doc('gemini')
                    .set({
                  'apiKey': apiKey,
                }, SetOptions(merge: true));
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('API key saved successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Save', 
                style: TextStyle(color: AppColors.primaryCyan)),
          ),
        ],
      ),
    );
  }

  void _showPersonalityDialog(BuildContext context, String? currentPersonality) {
    final controller = TextEditingController(
      text: currentPersonality ?? 
            'You are a helpful HVAC technical support assistant. '
            'You provide clear, professional guidance to HVAC technicians and homeowners. '
            'Be concise, practical, and safety-conscious in your responses. '
            'When providing troubleshooting advice, explain the reasoning behind your recommendations.',
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Personality Tuning', 
            style: TextStyle(color: AppColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customize how Gemini AI responds to queries:',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 8,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Enter personality instructions...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, 
                            color: AppColors.info, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Tips:',
                          style: TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Define tone (professional, friendly, technical)\n'
                      '• Set response length preferences\n'
                      '• Specify safety considerations\n'
                      '• Include domain expertise level',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final personality = controller.text.trim();
              if (personality.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('settings')
                    .doc('gemini')
                    .set({
                  'personality': personality,
                }, SetOptions(merge: true));
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Personality updated successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Save', 
                style: TextStyle(color: AppColors.primaryCyan)),
          ),
        ],
      ),
    );
  }
}

class _PricebookItemsPane extends StatelessWidget {
  final String categoryId;
  final String categoryName;
  const _PricebookItemsPane({
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final itemsStream = FirebaseFirestore.instance
        .collection('pricebookItems')
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('name')
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          categoryName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: itemsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'No items in this category',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12),
              itemBuilder: (context, i) {
                final data = docs[i].data();
                final name = (data['name'] ?? 'Item').toString();
                final price = (data['price'] ?? '').toString();
                final code = (data['code'] ?? '').toString();
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListTile(
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      [
                        code.isEmpty ? null : 'Code: $code',
                        price.isEmpty ? null : 'Price: $price',
                      ].whereType<String>().join(' • '),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                    ),
                    onTap: () {
                      // Future: item detail/edit
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsToggle({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF4EC7F3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CustomersPane extends StatefulWidget {
  const _CustomersPane();

  @override
  State<_CustomersPane> createState() => _CustomersPaneState();
}

class _CustomersPaneState extends State<_CustomersPane> {
  String _search = '';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final baseQuery = FirebaseFirestore.instance.collection('customers');
    final stream = baseQuery.snapshots();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name, email, phone',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF121212),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF4EC7F3),
                  width: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                final filtered = docs.where((d) {
                  final data = d.data();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  if (_search.isEmpty) return true;
                  return name.contains(_search) ||
                      email.contains(_search) ||
                      phone.contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No customers found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12),
                  itemBuilder: (context, i) {
                    final data = filtered[i].data();
                    final name = (data['name'] ?? 'Unnamed').toString();
                    final email = (data['email'] ?? '').toString();
                    final phone = (data['phone'] ?? '').toString();
                    return ListTile(
                      tileColor: const Color(0xFF121212),
                      title: Text(
                        name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        [email, phone].where((s) => s.isNotEmpty).join(' • '),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white54,
                      ),
                      onTap: () => _openCustomerDetail(filtered[i]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openCustomerDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final emailCtrl = TextEditingController(text: data['email'] ?? '');
    final phoneCtrl = TextEditingController(text: data['phone'] ?? '');
    final addressCtrl = TextEditingController(text: data['address'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer Detail',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildField('Name', nameCtrl),
                const SizedBox(height: 12),
                _buildField('Email', emailCtrl),
                const SizedBox(height: 12),
                _buildField('Phone', phoneCtrl),
                const SizedBox(height: 12),
                _buildField('Address', addressCtrl, maxLines: 2),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.background,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save, size: 16),
                        label: Text(_saving ? 'Saving...' : 'Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4EC7F3),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _saving
                            ? null
                            : () => _saveCustomer(
                                  doc.id,
                                  nameCtrl.text.trim(),
                                  emailCtrl.text.trim(),
                                  phoneCtrl.text.trim(),
                                  addressCtrl.text.trim(),
                                ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.receipt_long, size: 16),
                        label: const Text('Create Invoice'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4EC7F3),
                          side: const BorderSide(color: Color(0xFF4EC7F3)),
                        ),
                        onPressed: () => _showCreateInvoice(
                          doc.id,
                          nameCtrl.text.trim().isEmpty
                              ? 'Customer'
                              : nameCtrl.text.trim(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF121212),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF4EC7F3)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveCustomer(
    String id,
    String name,
    String email,
    String phone,
    String address,
  ) async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('customers').doc(id).update({
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Customer updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showCreateInvoice(
    String customerId,
    String customerName,
  ) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: const Text(
            'New Invoice',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final now = DateTime.now().millisecondsSinceEpoch;
                final number = 'INV-$now';
                final amount = amountCtrl.text.trim();
                await FirebaseFirestore.instance.collection('invoices').add({
                  'number': number,
                  'status': 'unpaid',
                  'amount': amount,
                  'description': descCtrl.text.trim(),
                  'customerId': customerId,
                  'customerName': customerName,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invoice $number created')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}

class _InvoicesPane extends StatelessWidget {
  const _InvoicesPane();

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF2ECC71); // green
      case 'overdue':
        return const Color(0xFFE74C3C); // red
      case 'unpaid':
      default:
        return const Color(0xFFF1C40F); // amber
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream =
        FirebaseFirestore.instance.collection('invoices').snapshots();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoices',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No invoices found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12),
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final number = (data['number'] ?? '—').toString();
                    final status = (data['status'] ?? 'unpaid').toString();
                    final amount = (data['amount'] ?? '').toString();
                    final color = _statusColor(status);
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(
                              'Invoice $number',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: color.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          amount.isEmpty ? 'Amount: —' : 'Amount: $amount',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                        ),
                        onTap: () {
                          // Future: open invoice detail
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ML Device Learning Screen (Admin Only)
class _MLDeviceLearningScreen extends StatefulWidget {
  const _MLDeviceLearningScreen();

  @override
  State<_MLDeviceLearningScreen> createState() =>
      _MLDeviceLearningScreenState();
}

class _MLDeviceLearningScreenState extends State<_MLDeviceLearningScreen> {
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _rawDataController = TextEditingController();
  final TextEditingController _actualValueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _sessionActive = false;
  int _sampleCount = 0;

  @override
  void dispose() {
    _deviceNameController.dispose();
    _rawDataController.dispose();
    _actualValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    final deviceName = _deviceNameController.text.trim();
    if (deviceName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a device name')),
      );
      return;
    }

    setState(() {
      _sessionActive = true;
      _sampleCount = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Learning session started for: $deviceName'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _recordSample() async {
    final rawData = _rawDataController.text.trim();
    final actualValue = _actualValueController.text.trim();

    if (rawData.isEmpty || actualValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter both raw data and actual value')),
      );
      return;
    }

    setState(() {
      _sampleCount++;
    });

    // Clear inputs for next sample
    _rawDataController.clear();
    _actualValueController.clear();
    _notesController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sample $_sampleCount recorded'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _generatePattern() async {
    if (_sampleCount < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 3 samples to generate a pattern'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // In a real implementation, this would call the ML service
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Pattern Generated',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Successfully learned communication pattern for ${_deviceNameController.text}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'Samples: $_sampleCount',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Confidence: 85%',
              style: TextStyle(color: AppColors.primaryCyan),
            ),
            const SizedBox(height: 16),
            const Text(
              'The device will now be auto-recognized in future connections.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _endSession();
            },
            child: const Text('Done',
                style: TextStyle(color: AppColors.primaryCyan)),
          ),
        ],
      ),
    );
  }

  void _endSession() {
    setState(() {
      _sessionActive = false;
      _sampleCount = 0;
      _deviceNameController.clear();
      _rawDataController.clear();
      _actualValueController.clear();
      _notesController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'ML Device Learning',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppColors.info, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1. Start a learning session for a new device\n'
                      '2. Record 3-10 data samples with the actual readings\n'
                      '3. The ML system analyzes patterns and generates a parser\n'
                      '4. Device will be auto-recognized in future connections',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Device name input
              TextField(
                controller: _deviceNameController,
                enabled: !_sessionActive,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'e.g., New Brand Gauge Model X',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF121212),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF4EC7F3)),
                  ),
                  prefixIcon:
                      const Icon(Icons.devices, color: AppColors.primaryCyan),
                ),
              ),
              const SizedBox(height: 16),

              // Start/End session button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sessionActive ? _endSession : _startSession,
                  icon: Icon(_sessionActive ? Icons.stop : Icons.play_arrow),
                  label: Text(_sessionActive
                      ? 'End Session'
                      : 'Start Learning Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sessionActive
                        ? AppColors.error
                        : AppColors.primaryCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              if (_sessionActive) ...[
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 24),

                // Sample counter
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primaryCyan.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.data_usage,
                          color: AppColors.primaryCyan),
                      const SizedBox(width: 12),
                      Text(
                        'Samples Collected: $_sampleCount',
                        style: const TextStyle(
                          color: AppColors.primaryCyan,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Raw data input
                TextField(
                  controller: _rawDataController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Raw Data (Hex)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: '0A3B4C...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF121212),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Actual value input
                TextField(
                  controller: _actualValueController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Actual Reading',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'What the device displays',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF121212),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Notes input
                TextField(
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'Any observations...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF121212),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Record sample button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _recordSample,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Record Sample'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Generate pattern button (enabled after 3 samples)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sampleCount >= 3 ? _generatePattern : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate Pattern'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
