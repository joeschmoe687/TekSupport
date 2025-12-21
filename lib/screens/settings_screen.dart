import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/gradient_scaffold.dart';
import '../tools/screens/storage_screen.dart';
import '../auto_responder/auto_responder_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const SettingsScreen({super.key, required this.onToggleTheme});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoResponderEnabled = false;
  bool _hasSmsPermissions = false;
  int _repliesSent = 0;
  int _startHour = 7;
  int _endHour = 19;
  final _replyTextController = TextEditingController();
  bool _isDarkTheme = true;

  String role = 'user';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadAutoResponderSettings();
    _checkSmsPermissions();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDarkTheme = prefs.getBool('isDarkTheme') ?? true;
      });
    }
  }

  Future<void> _checkSmsPermissions() async {
    final hasPermissions = await AutoResponderService.checkPermissions();
    final status = await AutoResponderService.getStatus();
    if (mounted) {
      setState(() {
        _hasSmsPermissions = hasPermissions;
        _repliesSent = status['repliesSent'] ?? 0;
      });
    }
  }

  Future<void> _requestSmsPermissions() async {
    await AutoResponderService.requestPermissions();
    // Check again after request
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkSmsPermissions();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        role = userDoc.data()?['role'] as String? ?? 'user';
      });
    }
  }

  Future<void> _loadAutoResponderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoResponderEnabled = prefs.getBool('autoResponderEnabled') ?? false;
      _startHour = prefs.getInt('autoResponderStartHour') ?? 7;
      _endHour = prefs.getInt('autoResponderEndHour') ?? 19;
      _replyTextController.text = prefs.getString('autoReplyText') ??
          "Hi! Thanks for messaging. We'll follow up soon!";
    });
  }

  Future<void> _saveAutoResponderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoResponderEnabled', _autoResponderEnabled);
    await prefs.setInt('autoResponderStartHour', _startHour);
    await prefs.setInt('autoResponderEndHour', _endHour);
    await prefs.setString('autoReplyText', _replyTextController.text);

    // Sync to native Android
    await AutoResponderService.setEnabled(_autoResponderEnabled);
    await AutoResponderService.setReplyHours(_startHour, _endHour);
    await AutoResponderService.setReplyText(_replyTextController.text);
  }

  void _showTestSmsDialog() {
    final phoneController = TextEditingController(text: '4796010711');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Send Test SMS',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: TextStyle(color: AppColors.textPrimary),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Text(
              'Will send: "${_replyTextController.text}"',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await AutoResponderService.sendTestSms(
                phoneController.text,
                _replyTextController.text,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(success ? 'Test SMS sent!' : 'Failed to send SMS'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
            ),
            child: const Text('Send', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AuthScreen(
            isTechnician: false,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String formatHourLabel(int hour) {
      final h = hour % 24;
      final isPM = h >= 12;
      final displayHour = (h % 12 == 0) ? 12 : (h % 12);
      return '$displayHour:00 ${isPM ? 'PM' : 'AM'}';
    }

    String formatOffset(Duration offset) {
      final sign = offset.isNegative ? '-' : '+';
      final abs = offset.abs();
      final hh = abs.inHours.toString().padLeft(2, '0');
      final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
      return 'UTC$sign$hh:$mm';
    }

    return GradientScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Dark theme toggle
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile(
                value: _isDarkTheme,
                onChanged: (_) async {
                  setState(() {
                    _isDarkTheme = !_isDarkTheme;
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isDarkTheme', _isDarkTheme);
                  widget.onToggleTheme();
                },
                title: Text(
                  _isDarkTheme ? 'Dark Theme' : 'Light Theme',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  'Toggle between dark and light mode',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                activeColor: AppColors.primaryCyan,
              ),
            ),
            const SizedBox(height: 12),
            // Storage tile
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: ListTile(
                leading: Icon(Icons.storage, color: AppColors.primaryCyan),
                title: Text(
                  'Storage',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  'View saved devices, ML data & profiles',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                trailing: Icon(Icons.chevron_right, color: AppColors.textMuted),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StorageScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Auto-responder section - only for admin/tech
            if (role == 'admin' || role == 'tech') ...[
              const SizedBox(height: 12),
              // Permission status banner
              if (!_hasSmsPermissions)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SMS Permissions Required',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Grant SMS permissions to enable auto-responder',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _requestSmsPermissions,
                        child: const Text('Grant'),
                      ),
                    ],
                  ),
                ),
              // Status indicator
              if (_hasSmsPermissions && _autoResponderEnabled)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primaryCyan.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.primaryCyan),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Auto-Responder Active',
                              style: TextStyle(
                                color: AppColors.primaryCyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Replies sent: $_repliesSent | Active outside ${formatHourLabel(_startHour)} - ${formatHourLabel(_endHour)}',
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
                ),
              // Auto-responder toggle
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: SwitchListTile(
                  value: _autoResponderEnabled,
                  onChanged: _hasSmsPermissions
                      ? (val) {
                          setState(() => _autoResponderEnabled = val);
                          _saveAutoResponderSettings();
                        }
                      : null,
                  title: Text(
                    'Enable Auto-Responder',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    _hasSmsPermissions
                        ? 'Auto-reply to SMS during off-hours'
                        : 'Grant SMS permissions first',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  activeColor: AppColors.primaryCyan,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Time zone: ${DateTime.now().timeZoneName} (${formatOffset(DateTime.now().timeZoneOffset)})',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-Reply Hours',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'From:',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: DropdownButton<int>(
                                value: _startHour,
                                dropdownColor: AppColors.surfaceDark,
                                style: TextStyle(color: AppColors.textPrimary),
                                underline: const SizedBox(),
                                items: List.generate(
                                  24,
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text(formatHourLabel(i)),
                                  ),
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _startHour = val);
                                    _saveAutoResponderSettings();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'To:',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: DropdownButton<int>(
                                value: _endHour,
                                dropdownColor: AppColors.surfaceDark,
                                style: TextStyle(color: AppColors.textPrimary),
                                underline: const SizedBox(),
                                items: List.generate(
                                  24,
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text(formatHourLabel(i)),
                                  ),
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _endHour = val);
                                    _saveAutoResponderSettings();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _replyTextController,
                decoration: InputDecoration(
                  labelText: 'Auto Reply Message',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceDark.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.primaryCyan,
                      width: 2,
                    ),
                  ),
                ),
                style: TextStyle(color: AppColors.textPrimary),
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => _saveAutoResponderSettings(),
              ),
              const SizedBox(height: 16),
              // Send test SMS button
              if (_hasSmsPermissions)
                GestureDetector(
                  onTap: () => _showTestSmsDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primaryCyan.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send,
                            color: AppColors.primaryCyan, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Send Test SMS',
                          style: TextStyle(
                            color: AppColors.primaryCyan,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 30),
            // Logout button - red gradient
            GestureDetector(
              onTap: _logout,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
