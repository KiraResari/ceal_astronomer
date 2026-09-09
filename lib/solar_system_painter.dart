import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'celestial_body.dart';
import 'orbit_math.dart';

class SolarSystemPainter extends CustomPainter {
  SolarSystemPainter({
    required this.bodies,
    required this.selectedId,
    required this.scale,
    required this.pan,
  });

  final List<CelestialBody> bodies;
  final String? selectedId;
  final double scale;
  final Offset pan;

  Offset _worldToScreen(Offset km, Size size) {
    final pixels = km / kilometersPerViewportPixel;
    return size.center(Offset.zero) + pan + pixels * scale;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF020308),
    );

    final origin = _worldToScreen(Offset.zero, size);

    // A tiny cross marks the shared occupied focus.
    final originPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    canvas.drawLine(origin - const Offset(5, 0), origin + const Offset(5, 0), originPaint);
    canvas.drawLine(origin - const Offset(0, 5), origin + const Offset(0, 5), originPaint);

    for (final body in bodies) {
      _drawOrbit(canvas, size, body);
    }

    for (final body in bodies) {
      _drawBody(canvas, size, body);
    }
  }

  void _drawOrbit(Canvas canvas, Size size, CelestialBody body) {
    final aPx = body.semiMajorAxisKm / kilometersPerViewportPixel * scale;
    final bPx = aPx * math.sqrt(math.max(0.0, 1.0 - body.eccentricity * body.eccentricity));
    final centerOffsetKm = Offset(-body.semiMajorAxisKm * body.eccentricity, 0);
    final omega = body.longitudeOfPerihelionDeg * math.pi / 180.0;

    final rotatedCenterKm = Offset(
      centerOffsetKm.dx * math.cos(omega) - centerOffsetKm.dy * math.sin(omega),
      centerOffsetKm.dx * math.sin(omega) + centerOffsetKm.dy * math.cos(omega),
    );

    final center = _worldToScreen(rotatedCenterKm, size);
    final paint = Paint()
      ..color = body.color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(omega);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: aPx * 2,
        height: bPx * 2,
      ),
      paint,
    );
    canvas.restore();
  }

  void _drawBody(Canvas canvas, Size size, CelestialBody body) {
    final point = _worldToScreen(body.positionKm, size);

    canvas.drawCircle(
      point,
      body.displayRadiusPx,
      Paint()..color = body.color,
    );

    if (body.id == selectedId) {
      canvas.drawCircle(
        point,
        body.displayRadiusPx + 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SolarSystemPainter oldDelegate) {
    return oldDelegate.bodies != bodies ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.scale != scale ||
        oldDelegate.pan != pan;
  }
}
