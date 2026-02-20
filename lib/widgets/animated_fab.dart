import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedFab extends StatefulWidget {
  final VoidCallback onPressed;

  const AnimatedFab({super.key, required this.onPressed});

  @override
  State<AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<AnimatedFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedBuilder(
        animation: _rotationAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value * 2 * math.pi,
            child: FloatingActionButton.extended(
              onPressed: () {
                _controller.reverse().then((_) {
                  _controller.forward();
                });
                widget.onPressed();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Transaction'),
              backgroundColor: Colors.blue,
              elevation: 8,
            ),
          );
        },
      ),
    );
  }
}
