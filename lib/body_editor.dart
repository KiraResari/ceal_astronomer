import 'package:flutter/material.dart';

import 'celestial_body.dart';
import 'orbit_math.dart';

class BodyEditorDialog extends StatefulWidget {
  const BodyEditorDialog({super.key, this.initial});

  final CelestialBody? initial;

  @override
  State<BodyEditorDialog> createState() => _BodyEditorDialogState();
}

class _BodyEditorDialogState extends State<BodyEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _color;
  late final TextEditingController _radius;
  late final TextEditingController _a;
  late final TextEditingController _e;
  late final TextEditingController _period;
  late final TextEditingController _longitude;
  late final TextEditingController _phase;

  static const _presets = <Color>[
    Color(0xFFFFC857),
    Color(0xFF4CC9F0),
    Color(0xFFF72585),
    Color(0xFFB8F2E6),
    Color(0xFF9B5DE5),
    Color(0xFFFF6B6B),
    Color(0xFFFFFFFF),
    Color(0xFF90BE6D),
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    _name = TextEditingController(text: b?.name ?? '');
    _color = TextEditingController(
      text: b == null ? '#FFFFC857' : _hex(b.color),
    );
    _radius = TextEditingController(text: '${b?.displayRadiusPx ?? 7}');
    _a = TextEditingController(text: '${b?.semiMajorAxisKm ?? 149600000}');
    _e = TextEditingController(text: '${b?.eccentricity ?? 0.0167}');
    _period = TextEditingController(text: '${b?.orbitalPeriodDays ?? 365.25}');
    _longitude =
        TextEditingController(text: '${b?.longitudeOfPerihelionDeg ?? 0}');
    _phase = TextEditingController(text: '${b?.phase ?? 0}');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _color,
      _radius,
      _a,
      _e,
      _period,
      _longitude,
      _phase,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _hex(Color c) {
    int channel(double v) => (v * 255).round().clamp(0, 255).toInt();
    final r = channel(c.r).toRadixString(16).padLeft(2, '0');
    final g = channel(c.g).toRadixString(16).padLeft(2, '0');
    final b = channel(c.b).toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  double? _number(String text) => double.tryParse(text.trim());

  String? _requiredNumber(
    String? value, {
    double? min,
    double? max,
    bool maxExclusive = false,
  }) {
    final n = _number(value ?? '');
    if (n == null || !n.isFinite) return 'Enter a valid number.';
    if (min != null && n < min) return 'Must be ≥ $min.';
    if (max != null && (maxExclusive ? n >= max : n > max)) {
      return maxExclusive ? 'Must be < $max.' : 'Must be ≤ $max.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Color parsedColor;
    try {
      parsedColor = colorFromHex(_color.text);
    } on FormatException {
      return;
    }

    final old = widget.initial;
    final body = CelestialBody(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      color: parsedColor,
      displayRadiusPx: _number(_radius.text)!,
      semiMajorAxisKm: _number(_a.text)!,
      eccentricity: _number(_e.text)!,
      orbitalPeriodDays: _number(_period.text)!,
      longitudeOfPerihelionDeg: _number(_longitude.text)!,
      phase: normalizedPhase(_number(_phase.text)!),
    );
    Navigator.of(context).pop(body);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add celestial body' : 'Edit celestial body'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _color,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    helperText: 'Hex: #RRGGBB or #AARRGGBB',
                  ),
                  validator: (v) {
                    try {
                      colorFromHex(v ?? '');
                      return null;
                    } on FormatException catch (e) {
                      return e.message.toString();
                    }
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets.map((c) {
                    return InkWell(
                      onTap: () => setState(() => _color.text = _hex(c)),
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white54),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _field(_radius, 'Display size — radius (px)',
                    validator: (v) => _requiredNumber(v, min: 1)),
                _field(_a, 'Semi-major axis (km)',
                    validator: (v) => _requiredNumber(v, min: 0)),
                _field(_e, 'Eccentricity',
                    validator: (v) =>
                        _requiredNumber(v, min: 0, max: 1, maxExclusive: true)),
                _field(_period, 'Orbital period (days)',
                    validator: (v) => _requiredNumber(v, min: 0.000000001)),
                _field(_longitude, 'Longitude of perihelion (°)',
                    validator: _requiredNumber),
                _field(_phase, 'Current phase (0–1)',
                    validator: (v) =>
                        _requiredNumber(v, min: 0, max: 1, maxExclusive: true)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.initial == null ? 'Add' : 'Save changes'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(labelText: label),
        validator: validator,
      ),
    );
  }
}
