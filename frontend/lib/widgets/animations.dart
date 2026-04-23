import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuraReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;
  final double beginScale;
  final double beginBlur;

  const AuraReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 700),
    this.beginOffset = const Offset(0, 0.2),
    this.beginScale = 0.95,
    this.beginBlur = 0.0,
  });

  @override
  State<AuraReveal> createState() => _AuraRevealState();
}

class _AuraRevealState extends State<AuraReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  late Animation<double> _scale;
  late Animation<double> _blur;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    const curve = Cubic(0.16, 1, 0.3, 1);

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: curve)),
    );

    _slide = Tween<Offset>(begin: widget.beginOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: curve),
    );

    _scale = Tween<double>(begin: widget.beginScale, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: curve),
    );

    if (widget.beginBlur > 0) {
      _blur = Tween<double>(begin: widget.beginBlur, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: curve),
      );
    } else {
      _blur = const AlwaysStoppedAnimation(0.0);
    }

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(
              _slide.value.dx * MediaQuery.of(context).size.width,
              _slide.value.dy * MediaQuery.of(context).size.height,
            ),
            child: Transform.scale(
              scale: _scale.value,
              child: _blur.value > 0.1
                  ? ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: _blur.value,
                        sigmaY: _blur.value,
                      ),
                      child: child,
                    )
                  : child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class StaggerReveal extends StatelessWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final Duration itemDuration;
  final Offset beginOffset;

  const StaggerReveal({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 80),
    this.itemDuration = const Duration(milliseconds: 600),
    this.beginOffset = const Offset(0, 0.15),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(children.length, (i) {
        return AuraReveal(
          delay: Duration(milliseconds: staggerDelay.inMilliseconds * i),
          duration: itemDuration,
          beginOffset: beginOffset,
          child: children[i],
        );
      }),
    );
  }
}

class GlowPulse extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double minRadius;
  final double maxRadius;
  final double minOpacity;
  final double maxOpacity;
  final Duration duration;

  const GlowPulse({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF8B5CF6),
    this.minRadius = 40,
    this.maxRadius = 80,
    this.minOpacity = 0.0,
    this.maxOpacity = 0.4,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<GlowPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final eased = (1 - (1 - t).clamp(0.0, 1.0)) * t * 4;
        final radius = widget.minRadius + (widget.maxRadius - widget.minRadius) * eased;
        final opacity = widget.minOpacity + (widget.maxOpacity - widget.minOpacity) * eased;

        return CustomPaint(
          painter: _GlowPainter(
            radius: radius,
            color: widget.glowColor,
            opacity: opacity,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _GlowPainter extends CustomPainter {
  final double radius;
  final Color color;
  final double opacity;

  _GlowPainter({
    required this.radius,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(opacity),
          color.withOpacity(opacity * 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) =>
      radius != oldDelegate.radius || opacity != oldDelegate.opacity;
}

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressScale;
  final Duration pressDuration;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressScale = 0.96,
    this.pressDuration = const Duration(milliseconds: 120),
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _brightness;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
    );

    _scale = Tween<double>(begin: 1.0, end: widget.pressScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _brightness = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    HapticFeedback.selectionClick();
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix([
                _brightness.value, 0, 0, 0, 0,
                0, _brightness.value, 0, 0, 0,
                0, 0, _brightness.value, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class MorphContainer extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final Color activeBorderColor;
  final Color inactiveBorderColor;
  final Duration duration;
  final BorderRadius activeBorderRadius;
  final BorderRadius inactiveBorderRadius;

  const MorphContainer({
    super.key,
    required this.child,
    required this.isActive,
    this.activeColor = const Color(0xFF8B5CF6),
    this.inactiveColor = const Color(0x0DFFFFFF),
    this.activeBorderColor = const Color(0xFF8B5CF6),
    this.inactiveBorderColor = const Color(0x1AFFFFFF),
    this.duration = const Duration(milliseconds: 300),
    this.activeBorderRadius = BorderRadius.zero,
    this.inactiveBorderRadius = BorderRadius.zero,
  });

  @override
  State<MorphContainer> createState() => _MorphContainerState();
}

class _MorphContainerState extends State<MorphContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _backgroundColor;
  late Animation<Color?> _borderColor;
  late Animation<double> _borderWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _backgroundColor = ColorTween(
      begin: widget.inactiveColor,
      end: widget.activeColor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _borderColor = ColorTween(
      begin: widget.inactiveBorderColor,
      end: widget.activeBorderColor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _borderWidth = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.isActive) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(MorphContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      widget.isActive ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return AnimatedContainer(
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _backgroundColor.value,
            borderRadius: BorderRadius.lerp(
              widget.inactiveBorderRadius,
              widget.activeBorderRadius,
              _controller.value,
            ),
            border: Border.all(
              color: _borderColor.value ?? Colors.transparent,
              width: _borderWidth.value,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}