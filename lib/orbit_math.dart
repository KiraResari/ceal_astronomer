import 'dart:math' as math;
import 'dart:ui';

const double kilometersPerViewportPixel = 1000000.0;

double normalizedPhase(double phase) {
  final value = phase % 1.0;
  return value < 0 ? value + 1.0 : value;
}

/// Solves M = E - e sin(E) for eccentric anomaly E.
///
/// Newton-Raphson converges quickly for the supported 0 <= e < 1 elliptical
/// orbits. The fallback iteration limit prevents malformed data hanging UI.
double solveEccentricAnomaly({
  required double meanAnomalyRadians,
  required double eccentricity,
}) {
  var e = eccentricity < 0 ? 0.0 : eccentricity;
  if (e >= 1.0) e = 0.999999999;

  final m = meanAnomalyRadians;
  var eccentricAnomaly = e < 0.8 ? m : math.pi;

  for (var i = 0; i < 32; i++) {
    final f = eccentricAnomaly - e * math.sin(eccentricAnomaly) - m;
    final fp = 1.0 - e * math.cos(eccentricAnomaly);
    final delta = f / fp;
    eccentricAnomaly -= delta;
    if (delta.abs() < 1e-12) break;
  }

  return eccentricAnomaly;
}

/// Position relative to the occupied focus, in kilometers.
///
/// Before rotation:
///   x = a(cos(E) - e)
///   y = a sqrt(1-e^2) sin(E)
///
/// That places the star/system origin at one focus rather than at the ellipse
/// center. The result is then rotated by longitude of perihelion.
Offset orbitalPositionKm({
  required double semiMajorAxisKm,
  required double eccentricity,
  required double longitudeOfPerihelionDeg,
  required double phase,
}) {
  final a = semiMajorAxisKm;
  final e = eccentricity;
  final meanAnomaly = normalizedPhase(phase) * 2.0 * math.pi;
  final eccentricAnomaly = solveEccentricAnomaly(
    meanAnomalyRadians: meanAnomaly,
    eccentricity: e,
  );

  final x = a * (math.cos(eccentricAnomaly) - e);
  final y = a *
      math.sqrt(math.max(0.0, 1.0 - e * e)) *
      math.sin(eccentricAnomaly);

  final omega = longitudeOfPerihelionDeg * math.pi / 180.0;
  final cosO = math.cos(omega);
  final sinO = math.sin(omega);

  return Offset(
    x * cosO - y * sinO,
    x * sinO + y * cosO,
  );
}

double distanceKm(Offset a, Offset b) => (a - b).distance;
