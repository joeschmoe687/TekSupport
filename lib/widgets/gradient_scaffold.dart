import 'package:flutter/material.dart';

/// App-wide color constants with theme support
class AppColors {
  // DARK THEME COLORS (original)
  // Base colors (matching web --primary-gradient)
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color darkSurfaceDark = Color(0xFF16213E);
  static const Color darkSurfaceLight = Color(0xFF0F3460);
  static const Color darkCardBg = Color(0x1E1E2EF2); // rgba(30, 30, 46, 0.95)

  // Dark mode text colors
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFF888888);
  static const Color darkTextMuted = Color(0xFF6B7280);

  // Dark mode borders
  static const Color darkBorder = Color(0x1AFFFFFF); // rgba(255, 255, 255, 0.1)
  static const Color darkBorderLight = Color(0xFF4B5563);

  // LIGHT THEME COLORS (outdoor-friendly, rugged, modern)
  // Clean white/light gray base with strong contrast
  static const Color lightBackground = Color(0xFFF5F5F5); // Light gray
  static const Color lightSurfaceDark = Color(0xFFFFFFFF); // Pure white
  static const Color lightSurfaceLight = Color(0xFFFAFAFA); // Off-white
  static const Color lightCardBg = Color(0xFFFFFFFF); // White cards

  // Light mode text colors (dark for high contrast)
  static const Color lightTextPrimary = Color(0xFF1A1A1A); // Near black
  static const Color lightTextSecondary = Color(0xFF4A5568); // Dark gray
  static const Color lightTextMuted = Color(0xFF718096); // Medium gray

  // Light mode borders (subtle but visible)
  static const Color lightBorder = Color(0xFFE2E8F0); // Light gray border
  static const Color lightBorderLight = Color(0xFFCBD5E0); // Slightly darker

  // Accent colors (same for both themes - vibrant and visible)
  static const Color primaryCyan = Color(0xFF0891B2); // Darker cyan for light mode
  static const Color primaryCyanLight = Color(0xFF4EC7F3); // Original for dark mode
  static const Color primaryPurple = Color(0xFF764BA2);
  static const Color accentBlue = Color(0xFF667EEA);

  // Button gradient (same for both themes)
  static const Color buttonGradientStart = Color(0xFF764BA2);
  static const Color buttonGradientEnd = Color(0xFF667EEA);

  // Status colors (optimized for both themes)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Current theme colors (will be updated based on theme mode)
  static Color background = darkBackground;
  static Color surfaceDark = darkSurfaceDark;
  static Color surfaceLight = darkSurfaceLight;
  static Color cardBg = darkCardBg;
  static Color textPrimary = darkTextPrimary;
  static Color textSecondary = darkTextSecondary;
  static Color textMuted = darkTextMuted;
  static Color border = darkBorder;
  static Color borderLight = darkBorderLight;

  /// Update colors based on theme mode
  static void updateTheme(bool isDarkMode) {
    if (isDarkMode) {
      background = darkBackground;
      surfaceDark = darkSurfaceDark;
      surfaceLight = darkSurfaceLight;
      cardBg = darkCardBg;
      textPrimary = darkTextPrimary;
      textSecondary = darkTextSecondary;
      textMuted = darkTextMuted;
      border = darkBorder;
      borderLight = darkBorderLight;
    } else {
      background = lightBackground;
      surfaceDark = lightSurfaceDark;
      surfaceLight = lightSurfaceLight;
      cardBg = lightCardBg;
      textPrimary = lightTextPrimary;
      textSecondary = lightTextSecondary;
      textMuted = lightTextMuted;
      border = lightBorder;
      borderLight = lightBorderLight;
    }
  }

  // Gradient for buttons (same for both themes)
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [buttonGradientStart, buttonGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Pressed button gradient (slightly darker)
  static const LinearGradient buttonGradientPressed = LinearGradient(
    colors: [Color(0xFF5D3A80), Color(0xFF5266C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Background gradient - dark mode
  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A2E), // #1a1a2e
      Color(0xFF16213E), // #16213e
      Color(0xFF0F3460), // #0f3460
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Background gradient - light mode (subtle, clean)
  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF5F5F5), // Light gray
      Color(0xFFEDF2F7), // Slightly bluer gray
      Color(0xFFE2E8F0), // Even lighter blue-gray
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Dynamic gradient based on theme
  static LinearGradient backgroundGradient = darkBackgroundGradient;

  /// Update gradient based on theme
  static void updateGradient(bool isDarkMode) {
    backgroundGradient = isDarkMode ? darkBackgroundGradient : lightBackgroundGradient;
  }
}

/// A scaffold with the gradient background matching the web UI
class GradientScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBodyBehindAppBar;

  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBodyBehindAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: body,
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

/// Gradient button matching the web UI's primary button style
/// Includes press effect with scale and shadow animation
class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final double? width;
  final double height;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.width,
    this.height = 48,
    this.borderRadius = 8,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        height: widget.height,
        transform: Matrix4.identity()..translate(0.0, _isPressed ? 2.0 : 0.0),
        decoration: BoxDecoration(
          gradient: _isPressed
              ? AppColors.buttonGradientPressed
              : AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.buttonGradientStart.withOpacity(
                _isPressed ? 0.3 : 0.4,
              ),
              blurRadius: _isPressed ? 10 : 15,
              offset: Offset(0, _isPressed ? 2 : 4),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                widget.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card with border styling matching the web UI
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 12,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.border.withOpacity(0.5),
        ),
      ),
      child: child,
    );
  }
}
