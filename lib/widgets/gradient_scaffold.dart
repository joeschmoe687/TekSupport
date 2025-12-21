import 'package:flutter/material.dart';

/// App-wide color constants matching the web UI
class AppColors {
  // Base colors (matching web --primary-gradient)
  static const Color background = Color(0xFF1A1A2E);
  static const Color surfaceDark = Color(0xFF16213E);
  static const Color surfaceLight = Color(0xFF0F3460);
  static const Color cardBg = Color(0x1E1E2EF2); // rgba(30, 30, 46, 0.95)

  // Accent colors (matching web)
  static const Color primaryCyan = Color(0xFF4EC7F3); // --accent-blue
  static const Color primaryPurple = Color(0xFF764BA2); // --accent-purple
  static const Color accentBlue = Color(0xFF667EEA); // button gradient end

  // Button gradient (matching web .primary-btn)
  static const Color buttonGradientStart = Color(0xFF764BA2);
  static const Color buttonGradientEnd = Color(0xFF667EEA);

  // Text colors (matching web)
  static const Color textPrimary = Color(0xFFE0E0E0); // --text-primary
  static const Color textSecondary = Color(0xFF888888); // --text-secondary
  static const Color textMuted = Color(0xFF6B7280);

  // Border colors
  static const Color border = Color(0x1AFFFFFF); // rgba(255, 255, 255, 0.1)
  static const Color borderLight = Color(0xFF4B5563);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Gradient for buttons (purple to blue - matching web)
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

  // Background gradient (matching web --primary-gradient)
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A2E), // #1a1a2e
      Color(0xFF16213E), // #16213e
      Color(0xFF0F3460), // #0f3460
    ],
    stops: [0.0, 0.5, 1.0],
  );
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
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
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
