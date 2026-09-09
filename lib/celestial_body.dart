import 'dart:ui';

import 'orbit_math.dart';

class CelestialBody {
  const CelestialBody({
    required this.id,
    required this.name,
    required this.color,
    required this.displayRadiusPx,
    required this.semiMajorAxisKm,
    required this.eccentricity,
    required this.orbitalPeriodDays,
    required this.longitudeOfPerihelionDeg,
    required this.phase,
  });

  final String id;
  final String name;
  final Color color;
  final double displayRadiusPx;
  final double semiMajorAxisKm;
  final double eccentricity;
  final double orbitalPeriodDays;
  final double longitudeOfPerihelionDeg;
  final double phase;

  Offset get positionKm => orbitalPositionKm(
        semiMajorAxisKm: semiMajorAxisKm,
        eccentricity: eccentricity,
        longitudeOfPerihelionDeg: longitudeOfPerihelionDeg,
        phase: phase,
      );

  CelestialBody copyWith({
    String? id,
    String? name,
    Color? color,
    double? displayRadiusPx,
    double? semiMajorAxisKm,
    double? eccentricity,
    double? orbitalPeriodDays,
    double? longitudeOfPerihelionDeg,
    double? phase,
  }) {
    return CelestialBody(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      displayRadiusPx: displayRadiusPx ?? this.displayRadiusPx,
      semiMajorAxisKm: semiMajorAxisKm ?? this.semiMajorAxisKm,
      eccentricity: eccentricity ?? this.eccentricity,
      orbitalPeriodDays: orbitalPeriodDays ?? this.orbitalPeriodDays,
      longitudeOfPerihelionDeg:
          longitudeOfPerihelionDeg ?? this.longitudeOfPerihelionDeg,
      phase: phase ?? this.phase,
    );
  }

  CelestialBody advancedByDays(double days) {
    if (orbitalPeriodDays <= 0) return this;
    return copyWith(phase: normalizedPhase(phase + days / orbitalPeriodDays));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': _colorToHex(color),
        'displayRadiusPx': displayRadiusPx,
        'semiMajorAxisKm': semiMajorAxisKm,
        'eccentricity': eccentricity,
        'orbitalPeriodDays': orbitalPeriodDays,
        'longitudeOfPerihelionDeg': longitudeOfPerihelionDeg,
        'phase': normalizedPhase(phase),
      };

  factory CelestialBody.fromJson(Map<String, dynamic> json) {
    return CelestialBody(
      id: (json['id'] as String?) ?? _fallbackId(),
      name: json['name'] as String,
      color: colorFromHex(json['color'] as String),
      displayRadiusPx: (json['displayRadiusPx'] as num).toDouble(),
      semiMajorAxisKm: (json['semiMajorAxisKm'] as num).toDouble(),
      eccentricity: (json['eccentricity'] as num).toDouble(),
      orbitalPeriodDays: (json['orbitalPeriodDays'] as num).toDouble(),
      longitudeOfPerihelionDeg:
          (json['longitudeOfPerihelionDeg'] as num).toDouble(),
      phase: normalizedPhase((json['phase'] as num).toDouble()),
    );
  }

  static String _fallbackId() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  static String _colorToHex(Color color) {
    int channel(double value) =>
        (value * 255.0).round().clamp(0, 255).toInt();
    final a = channel(color.a).toRadixString(16).padLeft(2, '0');
    final r = channel(color.r).toRadixString(16).padLeft(2, '0');
    final g = channel(color.g).toRadixString(16).padLeft(2, '0');
    final b = channel(color.b).toRadixString(16).padLeft(2, '0');
    return '#${a.toUpperCase()}${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }
}

Color colorFromHex(String input) {
  var hex = input.trim().replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) {
    throw const FormatException('Color must be #RRGGBB or #AARRGGBB.');
  }
  return Color(int.parse(hex, radix: 16));
}
