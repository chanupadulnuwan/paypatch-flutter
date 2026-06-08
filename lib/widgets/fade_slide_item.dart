import 'package:flutter/material.dart';

/// Wraps a child with a fade + upward-slide entrance animation.
/// Use [index] to stagger multiple items in a list.
class FadeSlideItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDuration;

  const FadeSlideItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: index * 60);
    final total = baseDuration + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: total,
      curve: Curves.easeOutCubic,
      builder: (_, val, child) => Opacity(
        opacity: val.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 24 * (1.0 - val)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
