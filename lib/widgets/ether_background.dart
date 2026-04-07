import 'dart:math';
import 'package:flutter/material.dart';

// ============================================================
//  GOOGLE ANTIGRAVITY — faithful Flutter recreation
//  Reference: https://antigravity.google  (screenshot 2026-04-07)
//
//  Key visual traits extracted from the original:
//   • Background : very light off-white / cool-grey (#EEEEF2)
//   • Particles  : short, thin, slightly-tilted capsule dashes
//   • Colors     : Google-brand Blue, Red/Orange, Purple, Yellow
//   • Micro-dots : tiny 1-px grey dots scattered everywhere
//   • Layout     : dense vortex/spiral in the upper-LEFT quadrant,
//                  very sparse towards the right & bottom
//   • Mouse      : gentle parallax / slight repulsion (not aggressive)
// ============================================================

const _kBgColor = Color(0xFFEEEEF2); // cool off-white

// Google brand palette for dashes
const List<Color> _kColors = [
  Color(0xFF4285F4), // Google Blue
  Color(0xFF4285F4), // Blue (weighted heavier)
  Color(0xFF4285F4),
  Color(0xFFEA4335), // Google Red
  Color(0xFFFA7B17), // Google Orange
  Color(0xFF9C27B0), // Purple
  Color(0xFF7986CB), // Indigo / blue-purple
  Color(0xFFAD1457), // Deep pink
];

const _kMicroDotColor = Color(0xFFBDBDBD); // faint grey micro-dots

// ─────────────────────────────────────────────
//  Data model for one dash particle
// ─────────────────────────────────────────────
class _Dash {
  // Polar coordinates in the vortex space
  double angle;    // radians
  double radius;   // distance from the vortex origin
  double speed;    // orbital speed multiplier
  double phase;    // wave phase offset

  // Visual
  final Color color;
  final double length;   // dash length px (at scale 1)
  final double width;    // dash thickness px (at scale 1)
  final double tiltAngle; // dash orientation angle (radians)

  // Current projected screen position
  double sx = 0, sy = 0;
  double scale = 1.0;

  _Dash({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.color,
    required this.length,
    required this.width,
    required this.tiltAngle,
  });
}

// ─────────────────────────────────────────────
//  Data model for one micro-dot
// ─────────────────────────────────────────────
class _MicroDot {
  final double x;
  final double y; // normalised 0..1
  final double size;
  _MicroDot(this.x, this.y, this.size);
}

// ─────────────────────────────────────────────
//  Widget
// ─────────────────────────────────────────────
class EtherBackground extends StatefulWidget {
  final Widget child;
  const EtherBackground({super.key, required this.child});

  @override
  State<EtherBackground> createState() => _EtherBackgroundState();
}

class _EtherBackgroundState extends State<EtherBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Dash> _dashes = [];
  final List<_MicroDot> _microDots = [];
  final _rand = Random(42);

  Size _size = Size.zero;
  Offset? _cursor; // screen-space cursor
  Offset? _smoothCursor;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )
      ..addListener(_tick)
      ..repeat();
    _buildParticles();
  }

  // ── Build particle lists ─────────────────────────────────
  void _buildParticles() {
    _dashes.clear();
    _microDots.clear();

    // Dashes — concentrated in top-left quadrant.
    // We use polar coords around (0,0) in normalised space;
    // the vortex origin maps to roughly (-0.05 , 0.15) of the screen.
    const int N = 420;
    for (int i = 0; i < N; i++) {
      // Bias radius: most particles are close to origin (dense) with a
      // long power-law tail (a few scattered particles far away).
      final double u = _rand.nextDouble();
      // Exponential distribution → dense core, sparse tail
      final double rawR = -log(1 - u * 0.999) * 0.28; // 0..~2 normalised

      // Clamp to actual useful range and convert to pixels later
      final double r = rawR.clamp(0.05, 1.8);

      // Angle — biased towards the top-left arc (roughly -π/4 .. 3π/4)
      // to match the screenshot where particles cascade from upper-left
      // outward to the right.
      final double a = _rand.nextDouble() * 2 * pi;

      final Color c = _kColors[_rand.nextInt(_kColors.length)];
      final double len = 5.0 + _rand.nextDouble() * 8.0;   // 5–13 px
      final double wid = 1.2 + _rand.nextDouble() * 1.2;    // 1.2–2.4 px
      // Dash tilt: the original dashes are roughly \ tilted (~45°)
      final double tilt = -pi / 4 + (_rand.nextDouble() - 0.5) * 0.8;

      _dashes.add(_Dash(
        angle: a,
        radius: r,
        speed: 0.6 + _rand.nextDouble() * 0.8, // orbital speed
        phase: _rand.nextDouble() * 2 * pi,
        color: c,
        length: len,
        width: wid,
        tiltAngle: tilt,
      ));
    }

    // Micro-dots — random across the whole screen
    const int MD = 180;
    for (int i = 0; i < MD; i++) {
      _microDots.add(_MicroDot(
        _rand.nextDouble(),
        _rand.nextDouble(),
        0.8 + _rand.nextDouble() * 1.0,
      ));
    }
  }

  // ── Per-frame tick ───────────────────────────────────────
  void _tick() {
    if (_size == Size.zero) return;
    final double t =
        (_ctrl.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;

    final double W = _size.width;
    final double H = _size.height;

    // Vortex origin: upper-left of screen (matches screenshot)
    final double ox = W * -0.06; // slightly off-screen left
    final double oy = H * 0.12;

    // Scale: 1 normalised unit = this many pixels
    // We want the dense core (r~0.2) at ~80-150px from origin,
    // and the tail extending across most of the screen.
    final double unitPx = W * 0.38;

    // Smooth cursor (lerp for parallax softness)
    if (_cursor != null) {
      _smoothCursor ??= _cursor;
      _smoothCursor = Offset(
        _smoothCursor!.dx + (_cursor!.dx - _smoothCursor!.dx) * 0.07,
        _smoothCursor!.dy + (_cursor!.dy - _smoothCursor!.dy) * 0.07,
      );
    } else {
      _smoothCursor = null;
    }

    for (final d in _dashes) {
      // Orbital motion: angle increases over time
      final double a = d.angle + t * d.speed * 0.18;

      // Gentle breathing (radial oscillation)
      final double r = d.radius * (1 + 0.04 * sin(t * 0.4 + d.phase));

      // 3-D perspective: treat y-spread as a mild tilt
      // Particles behind (sin(a) < 0) appear slightly smaller
      final double perspScale = 1.0 - 0.12 * sin(a);
      d.scale = perspScale;

      // Project to screen
      double px = ox + cos(a) * r * unitPx;
      double py = oy + sin(a) * r * unitPx * 0.55 // flatten Y for ellipse
          + sin(t * 0.6 + d.phase * 2) * r * 8; // subtle vertical sway

      // ── Cursor parallax / gentle repulsion ─────────────
      if (_smoothCursor != null) {
        final double cdx = px - _smoothCursor!.dx;
        final double cdy = py - _smoothCursor!.dy;
        final double cDist = sqrt(cdx * cdx + cdy * cdy);
        const double repRadius = 140.0;
        if (cDist < repRadius && cDist > 1) {
          final double strength =
              pow((repRadius - cDist) / repRadius, 2).toDouble() * 30;
          px += (cdx / cDist) * strength;
          py += (cdy / cDist) * strength;
        }
      }

      d.sx = px;
      d.sy = py;
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final s = Size(constraints.maxWidth, constraints.maxHeight);
      if (_size != s) _size = s;

      return MouseRegion(
        cursor: SystemMouseCursors.basic,
        onHover: (e) => _cursor = e.localPosition,
        onExit: (_) {
          _cursor = null;
          _smoothCursor = null;
        },
        child: GestureDetector(
          onPanUpdate: (d) => _cursor = d.localPosition,
          onPanEnd: (_) {
            _cursor = null;
            _smoothCursor = null;
          },
          child: CustomPaint(
            painter: _AntigravityPainter(
              dashes: _dashes,
              microDots: _microDots,
              screenSize: _size,
            ),
            child: widget.child,
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────
//  Painter
// ─────────────────────────────────────────────
class _AntigravityPainter extends CustomPainter {
  final List<_Dash> dashes;
  final List<_MicroDot> microDots;
  final Size screenSize;

  _AntigravityPainter({
    required this.dashes,
    required this.microDots,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. Background ─────────────────────────────────────
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _kBgColor,
    );

    // Optional: very subtle radial vignette / light haze from upper-left
    final Paint vignette = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-1.2, -1.0),
        radius: 1.6,
        colors: const [
          Color(0x08C5CAE9), // very faint blue-indigo tint
          Color(0x00EEEEF2),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    // ── 2. Micro-dots ─────────────────────────────────────
    final Paint dotPaint = Paint()
      ..color = _kMicroDotColor
      ..style = PaintingStyle.fill;

    for (final md in microDots) {
      canvas.drawCircle(
        Offset(md.x * size.width, md.y * size.height),
        md.size * 0.6,
        dotPaint,
      );
    }

    // ── 3. Dash particles ─────────────────────────────────
    // Sort by scale so back-particles are drawn first (painter's algorithm)
    final sorted = List.of(dashes)
      ..sort((a, b) => a.scale.compareTo(b.scale));

    for (final d in sorted) {
      // Skip particles off-screen (performance)
      if (d.sx < -80 || d.sx > size.width + 80 ||
          d.sy < -80 || d.sy > size.height + 80) continue;

      // Fade out particles that are far to the right / bottom
      // (the original has very few particles there)
      final double normX = d.sx / size.width;
      final double normY = d.sy / size.height;
      double screenFade = 1.0;
      if (normX > 0.5) screenFade *= (1 - (normX - 0.5) * 1.6).clamp(0, 1);
      if (normY > 0.7) screenFade *= (1 - (normY - 0.7) * 2.5).clamp(0, 1);

      final double alpha = (0.55 + d.scale * 0.35) * screenFade;
      if (alpha < 0.01) continue;

      final double scaledLen = d.length * d.scale;
      final double scaledWidth = d.width * d.scale;

      final double halfLen = scaledLen * 0.5;
      final double cos_ = cos(d.tiltAngle);
      final double sin_ = sin(d.tiltAngle);

      final Offset p1 = Offset(d.sx - cos_ * halfLen, d.sy - sin_ * halfLen);
      final Offset p2 = Offset(d.sx + cos_ * halfLen, d.sy + sin_ * halfLen);

      final Paint p = Paint()
        ..color = d.color.withValues(alpha: alpha)
        ..strokeWidth = scaledWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(p1, p2, p);
    }
  }

  @override
  bool shouldRepaint(covariant _AntigravityPainter old) => true;
}
