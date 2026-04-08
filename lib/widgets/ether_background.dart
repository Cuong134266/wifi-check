import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// =======================================================================
// ANTIGRAVITY PARTICLE ANIMATION — integrated into wifi-check
// Replaces the old EtherBackground with the Antigravity particle system
// =======================================================================

const _kBgColor = Color(0xFFF4F6FA);

class EtherBackground extends StatefulWidget {
  final Widget child;
  const EtherBackground({super.key, required this.child});

  @override
  State<EtherBackground> createState() => _EtherBackgroundState();
}

class _EtherBackgroundState extends State<EtherBackground>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _elapsed = 0;

  // Particles — flat arrays for performance
  static const int _countX = 40;
  static const int _countY = 25;
  static const int _count = _countX * _countY;
  final _baseX = List<double>.filled(_count, 0);
  final _baseY = List<double>.filled(_count, 0);
  final _randoms = List<double>.filled(_count, 0);

  // Pointer
  Offset? _pointerPos;
  double _lastPointerTime = -10;
  bool _hovering = false;

  // Halo (smooth follow, in normalized 0..1 coords)
  double _haloNX = 0.5;
  double _haloNY = 0.5;

  // Last known size
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _initGrid();
    _ticker = createTicker(_onTick)..start();
  }

  void _initGrid() {
    final rng = Random(42);
    int i = 0;
    for (int y = 0; y < _countY; y++) {
      for (int x = 0; x < _countX; x++) {
        _baseX[i] = x / (_countX - 1) + (rng.nextDouble() - 0.5) * 0.035;
        _baseY[i] = y / (_countY - 1) + (rng.nextDouble() - 0.5) * 0.035;
        _randoms[i] = rng.nextDouble();
        i++;
      }
    }
  }

  void _onTick(Duration duration) {
    _elapsed = duration.inMicroseconds / 1e6;
    if (!mounted) return;

    final idleTime = _elapsed - _lastPointerTime;
    final isIdle = idleTime > 2.0 || !_hovering;

    double targetNX, targetNY;
    if (isIdle) {
      final autoSpeed = _elapsed * 0.3;
      targetNX = 0.5 + sin(autoSpeed) * 0.25;
      targetNY = 0.5 + sin(autoSpeed * 2.0) * 0.15;
    } else if (_pointerPos != null && _size.width > 0) {
      targetNX = _pointerPos!.dx / _size.width;
      targetNY = _pointerPos!.dy / _size.height;
    } else {
      targetNX = 0.5;
      targetNY = 0.5;
    }

    final drag = isIdle ? 0.02 : 0.06;
    _haloNX += (targetNX - _haloNX) * drag;
    _haloNY += (targetNY - _haloNY) * drag;

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanUpdate: (d) {
            _pointerPos = d.localPosition;
            _hovering = true;
            _lastPointerTime = _elapsed;
          },
          onPanEnd: (_) => _hovering = false,
          child: MouseRegion(
            onHover: (e) {
              _pointerPos = e.localPosition;
              _hovering = true;
              _lastPointerTime = _elapsed;
            },
            onEnter: (_) => _hovering = true,
            onExit: (_) => _hovering = false,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _AntigravityPainter(
                  baseX: _baseX,
                  baseY: _baseY,
                  count: _count,
                  elapsed: _elapsed,
                  haloNX: _haloNX,
                  haloNY: _haloNY,
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---- Optimized Painter ----

class _AntigravityPainter extends CustomPainter {
  final List<double> baseX, baseY;
  final int count;
  final double elapsed;
  final double haloNX, haloNY;

  _AntigravityPainter({
    required this.baseX,
    required this.baseY,
    required this.count,
    required this.elapsed,
    required this.haloNX,
    required this.haloNY,
  });

  static double _smoothstep(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  static double _hash(double x, double y) {
    return (sin(x * 12.9898 + y * 78.233) * 43758.5453) % 1.0;
  }

  static double _noise(double x, double y) {
    final ix = x.floor().toDouble();
    final iy = y.floor().toDouble();
    var fx = x - ix;
    var fy = y - iy;
    fx = fx * fx * (3.0 - 2.0 * fx);
    fy = fy * fy * (3.0 - 2.0 * fy);
    final a = _hash(ix, iy);
    final b = _hash(ix + 1, iy);
    final c = _hash(ix, iy + 1);
    final d = _hash(ix + 1, iy + 1);
    final ab = a + (b - a) * fx;
    final cd = c + (d - c) * fx;
    return ab + (cd - ab) * fy;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Background
    canvas.drawRect(Offset.zero & size, Paint()..color = _kBgColor);

    final w = size.width;
    final h = size.height;
    final aspect = w / h;

    final driftSpeed = elapsed * 0.2;
    final breathCycle = sin(elapsed * 0.8);
    final colorTime = elapsed * 1.2;

    final hx = haloNX;
    final hy = haloNY;
    final haloBaseRadius = 0.25 + breathCycle * 0.02;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      var nx = baseX[i];
      var ny = baseY[i];

      final wx = (nx - 0.5) * 20.0;
      final wy = (ny - 0.5) * 12.0;
      final dx = sin(driftSpeed + wy * 0.5) + sin(driftSpeed * 0.5 + wy * 2.0);
      final dy = cos(driftSpeed + wx * 0.5) + cos(driftSpeed * 0.5 + wx * 2.0);
      nx += dx * 0.015;
      ny += dy * 0.015;

      final relX = (nx - hx) * aspect;
      final relY = ny - hy;
      final distFromHalo = sqrt(relX * relX + relY * relY);
      final angleToHalo = atan2(relY, relX);

      final shapeFactor = _noise(angleToHalo * 2.0, elapsed * 0.1);
      final haloRadius = haloBaseRadius + shapeFactor * 0.03;
      const rimWidth = 0.20;
      final rimInfluence = _smoothstep(
        rimWidth,
        0.0,
        (distFromHalo - haloRadius).abs(),
      );

      final invDist = 1.0 / (distFromHalo + 0.0001);
      final pushX = relX * invDist;
      final pushY = relY * invDist;
      final pushAmt = (breathCycle * 0.6 + 0.5) * 0.04;
      nx += pushX * pushAmt * rimInfluence / aspect;
      ny += pushY * pushAmt * rimInfluence;

      final sx = nx * w;
      final sy = ny * h;

      if (sx < -20 || sx > w + 20 || sy < -20 || sy > h + 20) continue;

      final baseSize = 1.0;
      final currentSize = baseSize + rimInfluence * 3.5;
      final pw = currentSize * 1.3;
      final ph = currentSize * 0.7;

      if (pw < 0.8) continue;

      // Color — spatial gradient
      final cx = (nx - 0.5) * 20.0;
      final cy = (ny - 0.5) * 12.0;
      final g1 = sin(cx * 0.18 + cy * 0.12 + colorTime) * 0.5 + 0.5;
      final g2 = sin(cx * 0.12 - cy * 0.15 + colorTime * 0.9) * 0.5 + 0.5;
      final g3 = cos(cy * 0.2 + cx * 0.08 - colorTime * 0.7) * 0.5 + 0.5;
      final g4 =
          sin(sqrt(cx * cx + cy * cy) * 0.12 + colorTime * 0.6) * 0.5 + 0.5;

      final s1 = _smoothstep(0.2, 0.8, g1);
      var r = 0.19 + (0.99 - 0.19) * s1;
      var g = 0.52 + (0.25 - 0.52) * s1;
      var b = 1.0 + (0.24 - 1.0) * s1;

      final s2 = _smoothstep(0.35, 0.65, g2);
      r += (0.98 - r) * s2;
      g += (0.74 - g) * s2;
      b += (0.02 - b) * s2;

      final s3 = _smoothstep(0.4, 0.7, g3);
      r += (0.0 - r) * s3;
      g += (0.73 - g) * s3;
      b += (0.36 - b) * s3;

      final s4 = _smoothstep(0.5, 0.8, g4) * 0.4;
      r += (0.55 - r) * s4;
      g += (0.36 - g) * s4;
      b += (0.80 - b) * s4;

      final alpha = 0.12 + 0.83 * _smoothstep(0.0, 0.5, rimInfluence);

      paint.color = Color.fromRGBO(
        (r * 255).round().clamp(0, 255),
        (g * 255).round().clamp(0, 255),
        (b * 255).round().clamp(0, 255),
        alpha,
      );

      canvas.save();
      canvas.translate(sx, sy);
      canvas.rotate(angleToHalo);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: pw, height: ph),
          Radius.circular(ph / 2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AntigravityPainter old) => true;
}
