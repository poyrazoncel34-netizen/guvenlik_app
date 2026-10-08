import 'package:flutter/material.dart';

/// A tap target that dips to 90% while pressed and reports the tap on release.
///
/// Moved verbatim out of `countdown_screen.dart` (accepted size debt) so the
/// countdown can take its fixes without growing.
class ScaleTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const ScaleTapButton({super.key, required this.child, required this.onTap});

  @override
  State<ScaleTapButton> createState() => _ScaleTapButtonState();
}

class _ScaleTapButtonState extends State<ScaleTapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
