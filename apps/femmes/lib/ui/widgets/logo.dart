// Copié de apps/mobile/lib/ui/widgets/logo.dart (pas d'import entre applications).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Marque FANILO dessinée en vecteurs (aucune image embarquée) : une
/// silhouette de femme de profil, entourée de feuilles et d'un arc de soleil.
class FaniloMark extends StatelessWidget {
  const FaniloMark({super.key, this.size = 48, this.onDark = false});
  final double size;

  /// Variante pour fond vert foncé.
  final bool onDark;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _MarkPainter(onDark: onDark)),
      );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.onDark});
  final bool onDark;

  void _leaf(Canvas canvas, Offset base, double length, double angle, double width,
      Color color) {
    final dir = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-dir.dy, dir.dx);
    final tip = base + dir * length;
    final mid = base + dir * (length * 0.5);
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(
          (mid + normal * width).dx, (mid + normal * width).dy, tip.dx, tip.dy)
      ..quadraticBezierTo(
          (mid - normal * width).dx, (mid - normal * width).dy, base.dx, base.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    // Nervure.
    canvas.drawLine(
        base + dir * (length * 0.12),
        base + dir * (length * 0.82),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = length * 0.035
          ..strokeCap = StrokeCap.round);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    Offset p(double x, double y) => Offset(x * s, y * s);

    // Disque de fond.
    canvas.drawCircle(p(0.5, 0.5), s * 0.5,
        Paint()..color = onDark ? Colors.white.withValues(alpha: 0.14) : FaniloColors.mint);

    // Arc de soleil (haut droit).
    canvas.drawArc(
      Rect.fromCircle(center: p(0.5, 0.5), radius: s * 0.43),
      -math.pi * 0.95,
      math.pi * 1.05,
      false,
      Paint()
        ..color = FaniloColors.sun
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.055
        ..strokeCap = StrokeCap.round,
    );

    // Silhouette de profil : chignon, tête, cou et épaules.
    final figure = Paint()..color = onDark ? Colors.white : FaniloColors.forest;
    canvas.drawCircle(p(0.47, 0.30), s * 0.075, figure); // chignon
    canvas.drawOval(Rect.fromCenter(center: p(0.575, 0.385), width: s * 0.2, height: s * 0.235),
        figure); // tête
    final body = Path()
      ..moveTo(0.53 * s, 0.47 * s)
      ..lineTo(0.62 * s, 0.47 * s)
      ..quadraticBezierTo(0.63 * s, 0.56 * s, 0.70 * s, 0.60 * s)
      ..quadraticBezierTo(0.80 * s, 0.66 * s, 0.80 * s, 0.82 * s)
      ..lineTo(0.38 * s, 0.82 * s)
      ..quadraticBezierTo(0.40 * s, 0.62 * s, 0.53 * s, 0.56 * s)
      ..close();
    canvas.drawPath(body, figure);

    // Feuilles (bas gauche), en éventail.
    final base = p(0.36, 0.86);
    _leaf(canvas, base, s * 0.40, -math.pi * 0.62, s * 0.085, FaniloColors.leaf);
    _leaf(canvas, base, s * 0.36, -math.pi * 0.80, s * 0.08, FaniloColors.leafLight);
    _leaf(canvas, base, s * 0.30, -math.pi * 0.96, s * 0.07,
        onDark ? FaniloColors.mintStrong : FaniloColors.forestDark);
    _leaf(canvas, base, s * 0.28, -math.pi * 0.42, s * 0.065, FaniloColors.leafLight);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.onDark != onDark;
}

/// Logo complet : marque + « FANILO ».
class FaniloLogo extends StatelessWidget {
  const FaniloLogo({super.key, this.size = 40, this.onDark = false, this.tagline});
  final double size;
  final bool onDark;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : FaniloColors.forest;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaniloMark(size: size, onDark: onDark),
        SizedBox(width: size * 0.25),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FANILO',
                style: TextStyle(
                    fontSize: size * 0.62,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: color)),
            if (tagline != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(tagline!,
                    style: TextStyle(
                        fontSize: math.max(12, size * 0.26),
                        fontWeight: FontWeight.w600,
                        color: onDark ? Colors.white70 : FaniloColors.inkSoft)),
              ),
          ],
        ),
      ],
    );
  }
}
