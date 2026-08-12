import 'package:flutter/material.dart';

/// Yükleme durumunda ekranı kaplayan yarı-şeffaf overlay.
/// Stack içinde kullanılır.
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? overlayColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // While the scrim is up nothing behind it is reachable, so it must not
        // stay in the semantics tree either -- otherwise TalkBack focus walks
        // into controls the user cannot actually touch.
        ExcludeSemantics(excluding: isLoading, child: child),
        if (isLoading)
          Positioned.fill(
            // The overlay blocks the screen, so a screen-reader user must be
            // told why. Without liveRegion the state change is silent and the
            // app simply stops responding from their point of view.
            child: Semantics(
              liveRegion: true,
              label: message,
              child: Container(
              color:
                  overlayColor ??
                  const Color(0xFF0A1B2A).withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.cyanAccent,
                        ),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        message!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              ),
            ),
          ),
      ],
    );
  }
}
