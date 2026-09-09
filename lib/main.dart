import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'body_editor.dart';
import 'celestial_body.dart';
import 'orbit_math.dart';
import 'solar_system_painter.dart';

void main() {
  runApp(const CelestialTrackerApp());
}

class CelestialTrackerApp extends StatelessWidget {
  const CelestialTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ceal Astronomer',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF6C8CFF),
        useMaterial3: true,
      ),
      home: const SolarSystemScreen(),
    );
  }
}

class SolarSystemScreen extends StatefulWidget {
  const SolarSystemScreen({super.key});

  @override
  State<SolarSystemScreen> createState() => _SolarSystemScreenState();
}

class _SolarSystemScreenState extends State<SolarSystemScreen> {
  final _stepController = TextEditingController(text: '1');

  List<CelestialBody> _bodies = [];
  String? _selectedId;
  double _currentDay = 0;

  double _scale = 1.0;
  Offset _pan = Offset.zero;

  static const double _minScale = 0.01;
  static const double _maxScale = 1000.0;

  CelestialBody? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final body in _bodies) {
      if (body.id == id) return body;
    }
    return null;
  }

  @override
  void dispose() {
    _stepController.dispose();
    super.dispose();
  }

  Future<void> _addBody() async {
    final body = await showDialog<CelestialBody>(
      context: context,
      builder: (_) => const BodyEditorDialog(),
    );
    if (body == null) return;
    setState(() {
      _bodies = [..._bodies, body];
      _selectedId = body.id;
    });
  }

  Future<void> _editSelected() async {
    final selected = _selected;
    if (selected == null) return;

    final edited = await showDialog<CelestialBody>(
      context: context,
      builder: (_) => BodyEditorDialog(initial: selected),
    );
    if (edited == null) return;

    setState(() {
      _bodies = [
        for (final body in _bodies)
          if (body.id == edited.id) edited else body,
      ];
    });
  }

  void _deleteSelected() {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      _bodies = _bodies.where((b) => b.id != selected.id).toList();
      _selectedId = null;
    });
  }

  void _newSystem() {
    setState(() {
      _bodies = [];
      _selectedId = null;
      _currentDay = 0;
      _scale = 1;
      _pan = Offset.zero;
    });
  }

  void _advance(int direction) {
    final step = double.tryParse(_stepController.text.trim());
    if (step == null || !step.isFinite || step < 0) {
      _message('Step size must be a non-negative number.');
      return;
    }
    final delta = step * direction;
    setState(() {
      _currentDay += delta;
      _bodies = [for (final b in _bodies) b.advancedByDays(delta)];
    });
  }

  Future<void> _save() async {
    const types = <XTypeGroup>[
      XTypeGroup(label: 'JSON', extensions: <String>['json']),
    ];

    final location = await getSaveLocation(
      acceptedTypeGroups: types,
      suggestedName: 'solar_system.json',
    );
    if (location == null) return;

    final document = <String, dynamic>{
      'version': 1,
      'currentDay': _currentDay,
      'bodies': _bodies.map((b) => b.toJson()).toList(),
    };

    final pretty = const JsonEncoder.withIndent('  ').convert(document);
    final bytes = Uint8List.fromList(utf8.encode(pretty));
    await XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name: 'solar_system.json',
    ).saveTo(location.path);

    if (mounted) _message('Saved ${location.path}');
  }

  Future<void> _load() async {
    const types = <XTypeGroup>[
      XTypeGroup(label: 'JSON', extensions: <String>['json']),
    ];

    final file = await openFile(acceptedTypeGroups: types);
    if (file == null) return;

    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('The JSON root must be an object.');
      }
      final bodyJson = raw['bodies'];
      if (bodyJson is! List) {
        throw const FormatException('Missing "bodies" array.');
      }

      final loaded = bodyJson
          .map((e) => CelestialBody.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      setState(() {
        _currentDay = (raw['currentDay'] as num?)?.toDouble() ?? 0;
        _bodies = loaded;
        _selectedId = null;
        _scale = 1;
        _pan = Offset.zero;
      });
      if (mounted) _message('Loaded ${file.path}');
    } catch (e) {
      if (mounted) _message('Could not load file: $e');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onPointerSignal(PointerSignalEvent event, Size size) {
    if (event is! PointerScrollEvent) return;

    final oldScale = _scale;
    final factor = math.exp(-event.scrollDelta.dy * 0.0015);
    final newScale = (_scale * factor).clamp(_minScale, _maxScale).toDouble();
    if (newScale == oldScale) return;

    // Keep the world coordinate under the cursor fixed while zooming.
    final center = size.center(Offset.zero);
    final cursorFromOrigin = event.localPosition - center - _pan;
    final worldPixels = cursorFromOrigin / oldScale;
    final newPan = event.localPosition - center - worldPixels * newScale;

    setState(() {
      _scale = newScale;
      _pan = newPan;
    });
  }

  void _selectAt(Offset localPosition, Size size) {
    CelestialBody? nearest;
    var nearestDistance = double.infinity;

    for (final body in _bodies) {
      final worldPx = body.positionKm / kilometersPerViewportPixel;
      final screen = size.center(Offset.zero) + _pan + worldPx * _scale;
      final distance = (localPosition - screen).distance;

      // A minimum hit area makes very small configured bodies selectable.
      final hitRadius = math.max(body.displayRadiusPx, 7.0);
      if (distance <= hitRadius && distance < nearestDistance) {
        nearest = body;
        nearestDistance = distance;
      }
    }

    setState(() => _selectedId = nearest?.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          _toolbar(),
          const Spacer(),
          TextButton.icon(
            onPressed: _newSystem,
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('New system'),
          ),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.folder_open),
            label: const Text('Load'),
          ),
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          Expanded(child: _viewport()),
          SizedBox(
            width: 320,
            child: _detailsPanel(),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            FilledButton.icon(
              onPressed: _addBody,
              icon: const Icon(Icons.add),
              label: const Text('Add body'),
            ),
            const SizedBox(width: 16),
            Text(
              'Day ${_formatNumber(_currentDay)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 20),
            const Text('Step (days)'),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _stepController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {},
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'Backward by step',
              onPressed: () => _advance(-1),
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              tooltip: 'Forward by step',
              onPressed: () => _advance(1),
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: 16),
            Text('${_formatNumber(_scale)}×'),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _scale = 1;
                _pan = Offset.zero;
              }),
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Reset view'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewport() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Listener(
          onPointerSignal: (event) => _onPointerSignal(event, size),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              setState(() => _pan += details.delta);
            },
            onTapUp: (details) => _selectAt(details.localPosition, size),
            child: MouseRegion(
              cursor: SystemMouseCursors.precise,
              child: CustomPaint(
                painter: SolarSystemPainter(
                  bodies: _bodies,
                  selectedId: _selectedId,
                  scale: _scale,
                  pan: _pan,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailsPanel() {
    final selected = _selected;

    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white12)),
      ),
      child: selected == null
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Click a celestial body to select it.\n\n'
                'Mouse wheel: zoom\n'
                'Left-drag: pan',
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: selected.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selected.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: _editSelected,
            icon: const Icon(Icons.edit),
            label: const Text('Edit selected'),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _deleteSelected,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete selected'),
          ),
          const Divider(height: 28),
          _property('Phase', _formatNumber(selected.phase)),
          _property('Semi-major axis',
              '${_formatNumber(selected.semiMajorAxisKm)} km'),
          _property('Eccentricity', _formatNumber(selected.eccentricity)),
          _property('Period',
              '${_formatNumber(selected.orbitalPeriodDays)} days'),
          _property(
            'Longitude of perihelion',
            '${_formatNumber(selected.longitudeOfPerihelionDeg)}°',
          ),
          const Divider(height: 28),
          Text(
            'Distances',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_bodies.length == 1)
            const Text('No other celestial bodies.')
          else
            ..._bodies.where((b) => b.id != selected.id).map((other) {
              final d = distanceKm(selected.positionKm, other.positionKm);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: other.color,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(other.name),
                subtitle: Text('${_formatNumber(d)} km'),
                onTap: () => setState(() => _selectedId = other.id),
              );
            }),
        ],
      ),
    );
  }

  Widget _property(String name, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(name, style: const TextStyle(color: Colors.white60))),
          const SizedBox(width: 8),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    if (value.abs() >= 1000000) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
