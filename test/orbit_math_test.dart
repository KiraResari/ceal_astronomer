import 'dart:math' as math;

import 'package:ceal_astronomer/orbit_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase zero is perihelion', () {
    final p = orbitalPositionKm(
      semiMajorAxisKm: 100,
      eccentricity: 0.2,
      longitudeOfPerihelionDeg: 0,
      phase: 0,
    );

    expect(p.dx, closeTo(80, 1e-9));
    expect(p.dy, closeTo(0, 1e-9));
  });

  test('circular quarter phase is ninety degrees', () {
    final p = orbitalPositionKm(
      semiMajorAxisKm: 100,
      eccentricity: 0,
      longitudeOfPerihelionDeg: 0,
      phase: 0.25,
    );

    expect(p.dx, closeTo(0, 1e-9));
    expect(p.dy, closeTo(100, 1e-9));
  });

  test('longitude rotates perihelion', () {
    final p = orbitalPositionKm(
      semiMajorAxisKm: 100,
      eccentricity: 0.2,
      longitudeOfPerihelionDeg: 90,
      phase: 0,
    );

    expect(p.dx, closeTo(0, 1e-9));
    expect(p.dy, closeTo(80, 1e-9));
  });

  test('Kepler solver satisfies equation', () {
    const e = 0.7;
    const m = 2.1;
    final E = solveEccentricAnomaly(
      meanAnomalyRadians: m,
      eccentricity: e,
    );

    expect(E - e * math.sin(E), closeTo(m, 1e-10));
  });

  test('phase normalization wraps backward', () {
    expect(normalizedPhase(-0.25), closeTo(0.75, 1e-12));
  });
}
