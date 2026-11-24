import 'dart:math';
import 'package:flutter/material.dart';

/// True circular clip reveal theme transition.
/// Clips the incoming theme screen in an expanding circle starting directly
/// from the center of the theme toggle icon outward to engulf the entire screen.
class CircularThemeReveal extends StatefulWidget {
  final Widget child;

  const CircularThemeReveal({
    super.key,
    required this.child,
  });

  static CircularThemeRevealState? of(BuildContext context) {
    return context.findAncestorStateOfType<CircularThemeRevealState>();
  }

  @override
  State<CircularThemeReveal> createState() => CircularThemeRevealState();
}

class CircularThemeRevealState extends State<CircularThemeReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Offset _epicenter = Offset.zero;
  bool _isAnimating = false;
  Color _oldThemeBackground = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimating = false;
        });
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Triggers the circular reveal transition from [iconKey] or [tapPosition]
  void triggerReveal({
    GlobalKey? iconKey,
    Offset? tapPosition,
    required VoidCallback onToggle,
  }) {
    if (_isAnimating) return;

    Offset center = tapPosition ?? Offset.zero;
    if (iconKey != null && iconKey.currentContext != null) {
      final box = iconKey.currentContext!.findRenderObject() as RenderBox?;
      if (box != null) {
        final pos = box.localToGlobal(Offset.zero);
        final size = box.size;
        center = Offset(pos.dx + size.width / 2, pos.dy + size.height / 2);
      }
    }

    if (center == Offset.zero) {
      final size = MediaQuery.of(context).size;
      center = Offset(size.width - 48, 56);
    }

    final isCurrentlyDark = Theme.of(context).brightness == Brightness.dark;
    final currentBg = isCurrentlyDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);

    setState(() {
      _epicenter = center;
      _oldThemeBackground = currentBg;
      _isAnimating = true;
    });

    // Switch the theme underneath
    onToggle();

    // Start expanding the circle
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAnimating) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Underneath: Old theme's solid background color
        Container(color: _oldThemeBackground),

        // On top: The new theme widget tree clipped inside an expanding circular hole!
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return ClipPath(
              clipper: _CircularRevealClipper(
                center: _epicenter,
                fraction: _animation.value,
              ),
              child: child,
            );
          },
          child: widget.child,
        ),
      ],
    );
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double fraction;

  _CircularRevealClipper({
    required this.center,
    required this.fraction,
  });

  @override
  Path getClip(Size size) {
    final Path path = Path();
    if (fraction <= 0.0) {
      return path;
    }

    final double maxRadius = _calcMaxRadius(center, size);
    final double currentRadius = maxRadius * fraction;

    path.addOval(Rect.fromCircle(center: center, radius: currentRadius));
    return path;
  }

  double _calcMaxRadius(Offset center, Size size) {
    final double w = max(center.dx, size.width - center.dx);
    final double h = max(center.dy, size.height - center.dy);
    return sqrt(w * w + h * h) * 1.05;
  }

  @override
  bool shouldReclip(covariant _CircularRevealClipper oldClipper) {
    return oldClipper.fraction != fraction || oldClipper.center != center;
  }
}
