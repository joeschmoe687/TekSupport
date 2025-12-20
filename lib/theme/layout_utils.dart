import 'package:flutter/material.dart';

/// Returns true if the screen height is under 700px (small phone)
bool isSmallScreen(BuildContext context) {
  return MediaQuery.of(context).size.height < 700;
}

/// Returns EdgeInsets that scales nicely with screen size
EdgeInsets safeScreenPadding(BuildContext context) {
  final height = MediaQuery.of(context).size.height;

  if (height < 700) {
    return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  } else if (height < 900) {
    return const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0);
  } else {
    return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0);
  }
}

/// Spacing that grows/shrinks with screen height
double verticalGap(BuildContext context, double base) {
  final height = MediaQuery.of(context).size.height;

  if (height < 700) return base * 0.75;
  if (height < 900) return base;
  return base * 1.25;
}

/// Universal wrapper to prevent vertical stretching and allow scrolling on all screens
class ScreenWrapper extends StatelessWidget {
  final Widget child;

  const ScreenWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: safeScreenPadding(context),
        child: child,
      ),
    );
  }
}
