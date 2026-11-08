import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Fades and slides its child in, optionally after [delay] (used for staggered lists).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;
  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(_curve),
          child: widget.child,
        ),
      );
}

/// Pulsing placeholder shown while data loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 160});
  final double height;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        height: widget.height,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: base.withValues(alpha: 0.05 + 0.05 * _c.value),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (status == 'HELD') ...[
          _Blink(color: c),
          const SizedBox(width: 6),
        ],
        Text(status, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 0.4)),
      ]),
    );
  }
}

class _Blink extends StatefulWidget {
  const _Blink({required this.color});
  final Color color;
  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
        child: Container(width: 7, height: 7, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
      );
}

/// Confirmed (green) and held (amber) seats as animated bar segments.
class SeatMeter extends StatelessWidget {
  const SeatMeter({super.key, required this.confirmed, required this.held, required this.total});
  final int confirmed, held, total;

  @override
  Widget build(BuildContext context) {
    final t = math.max(1, total);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: confirmed / t),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, conf, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: held / t),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, hel, _) => ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
            child: LayoutBuilder(
              builder: (_, box) => Row(children: [
                Container(width: box.maxWidth * conf, color: kOk),
                Container(width: box.maxWidth * hel, color: kWarn),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular countdown. [fraction] is 1.0 (full time left) → 0.0.
class CountdownRing extends StatefulWidget {
  const CountdownRing({super.key, required this.fraction, required this.child, this.urgent = false, this.done = false, this.size = 170});
  final double fraction;
  final Widget child;
  final bool urgent, done;
  final double size;
  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(CountdownRing old) {
    super.didUpdateWidget(old);
    if (widget.urgent && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.urgent && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.urgent) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.035).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: widget.fraction.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 500),
          builder: (_, f, _) => CustomPaint(
            painter: _RingPainter(f, track, widget.urgent ? kDanger : null, widget.done ? kOk : null),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.track, this.solid, this.done);
  final double fraction;
  final Color track;
  final Color? solid, done;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base..color = track);
    final color = done ?? solid;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (color != null) {
      paint.color = color;
    } else {
      paint.shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [kPrimary2, kAccent, kPrimary2],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(arcRect);
    }
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * fraction, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.solid != solid || old.done != done || old.track != track;
}

/// One-shot confetti burst, played when an admission is confirmed.
class Confetti extends StatefulWidget {
  const Confetti({super.key});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  static const _colors = [kPrimary2, kAccent, Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF22C55E), Color(0xFF3B82F6)];
  late final List<_Piece> _pieces = List.generate(
    34,
    (i) => _Piece(
      x: ((i * 37) % 100) / 100,
      delay: (i % 9) * 0.04,
      spin: (i * 53 % 360) * math.pi / 180,
      color: _colors[i % _colors.length],
      w: 6 + (i % 3) * 2.0,
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(animation: _c, builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_pieces, _c.value), size: Size.infinite)),
      );
}

class _Piece {
  _Piece({required this.x, required this.delay, required this.spin, required this.color, required this.w});
  final double x, delay, spin, w;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -12 + (size.height + 24) * Curves.easeIn.transform(local);
      final x = size.width * p.x + math.sin(local * 6 + p.spin) * 18;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin + local * 9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.w, height: p.w * 1.7), const Radius.circular(2)),
        Paint()..color = p.color.withValues(alpha: (1 - local * local).clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Inline error / info banner that shakes in.
class Banner2 extends StatelessWidget {
  const Banner2(this.message, {super.key, this.error = true});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final c = error ? kDanger : kOk;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      builder: (_, v, child) => Transform.translate(offset: Offset(error ? math.sin(v * math.pi * 4) * (1 - v) * 7 : 0, 0), child: Opacity(opacity: v.clamp(0.0, 1.0), child: child)),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: c, fontWeight: FontWeight.w500, height: 1.35))),
        ]),
      ),
    );
  }
}
