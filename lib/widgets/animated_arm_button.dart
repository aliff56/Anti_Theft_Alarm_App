import 'package:flutter/material.dart';

class AnimatedArmButton extends StatefulWidget {
  final bool armed;
  final VoidCallback onToggle;
  const AnimatedArmButton({required this.armed, required this.onToggle});

  @override
  State<AnimatedArmButton> createState() => _AnimatedArmButtonState();
}

class _AnimatedArmButtonState extends State<AnimatedArmButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnim;
  late Animation<double> _iconAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: widget.armed ? 1.0 : 0.0,
    );
    _colorAnim = ColorTween(
      begin: Colors.grey[800],
      end: Colors.tealAccent,
    ).animate(_controller);
    _iconAnim = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant AnimatedArmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.armed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _colorAnim.value,
              shape: BoxShape.circle,
              boxShadow: [
                if (widget.armed)
                  BoxShadow(
                    color: Colors.tealAccent.withOpacity(0.4),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: widget.armed
                    ? Icon(
                        Icons.lock_open,
                        key: const ValueKey('armed'),
                        color: Colors.black,
                        size: 48,
                      )
                    : Icon(
                        Icons.lock,
                        key: const ValueKey('disarmed'),
                        color: Colors.white,
                        size: 48,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
