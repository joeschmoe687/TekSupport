import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'widgets/gradient_scaffold.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'services/error_log_service.dart';
import 'tools/services/calibration_service.dart';
import 'tools/services/gauge_zero_service.dart';
import 'tools/services/ml_data_service.dart';
import 'tools/screens/devices_screen.dart';
import 'tools/screens/device_scan_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ .env file not found: $e");
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize error logging service (must be early to catch all errors)
  await ErrorLogService().initialize();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize payment service
  await PaymentService().initialize();

  // Initialize calibration service (for persistent sensor offsets)
  await CalibrationService().init();

  // Load gauge zero offsets from persistent storage
  await GaugeZeroService().loadZeroOffsets();

  // Initialize ML data service
  await MLDataService().init();

  // Initialize live data sync service (only on mobile, not web)
  // TODO: Implement LiveDataSyncService
  // await LiveDataSyncService().init();

  runApp(const TekToolApp());
}

class TekToolApp extends StatefulWidget {
  const TekToolApp({super.key});

  @override
  State<TekToolApp> createState() => _TekToolAppState();
}

class _TekToolAppState extends State<TekToolApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkTheme') ?? true; // Default to dark
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    // Update AppColors based on theme
    AppColors.updateTheme(isDark);
    AppColors.updateGradient(isDark);
  }

  Future<void> _toggleTheme() async {
    final newMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final isDark = newMode == ThemeMode.dark;
    setState(() {
      _themeMode = newMode;
    });
    
    // Update AppColors based on theme
    AppColors.updateTheme(isDark);
    AppColors.updateGradient(isDark);
    
    // Persist the preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TekTool',
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.light(
          primary: AppColors.primaryCyan,
          secondary: AppColors.primaryPurple,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primaryCyan,
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primaryCyan,
              width: 2,
            ),
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryCyan,
          secondary: AppColors.primaryPurple,
          tertiary: AppColors.accentBlue,
          surface: AppColors.surfaceDark,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark.withOpacity(0.95),
          selectedItemColor: AppColors.primaryCyan,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceDark.withOpacity(0.5),
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
            borderSide: const BorderSide(
              color: AppColors.primaryCyan,
              width: 2,
            ),
          ),
          hintStyle: TextStyle(color: AppColors.textMuted),
        ),
        dividerColor: AppColors.border,
        snackBarTheme: SnackBarThemeData(
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      routes: {
        '/devices': (context) => DevicesScreen(onToggleTheme: _toggleTheme),
        '/device-scan': (context) =>
            DeviceScanScreen(onToggleTheme: _toggleTheme),
      },
      // Start on Welcome; it routes into MainNavigationScreen after login
      home: WelcomeScreen(onToggleTheme: _toggleTheme),
    );
  }
}
