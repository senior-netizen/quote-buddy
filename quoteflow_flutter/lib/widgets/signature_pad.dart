import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Opens a modal signature pad. Returns the drawn signature as a
/// `data:image/png;base64,` URL, or null when dismissed without signing.
Future<String?> showSignaturePad(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SignaturePadSheet(),
  );
}

class _SignaturePadSheet extends StatefulWidget {
  const _SignaturePadSheet();

  @override
  State<_SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignaturePadSheetState extends State<_SignaturePadSheet> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;
  bool _hasInk = false;
  Size? _padSize;

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _current = [d.localPosition];
      _hasInk = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _current!.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails d) {
    setState(() {
      if (_current != null && _current!.isNotEmpty) {
        _strokes.add(_current!);
      }
      _current = null;
    });
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _current = null;
      _hasInk = false;
    });
  }

  Future<void> _save() async {
    final bytes = await _renderPng();
    if (bytes == null) return;
    if (!mounted) return;
    Navigator.of(context).pop('data:image/png;base64,${base64Encode(bytes)}');
  }

  /// Renders the strokes onto an opaque white 600x200 PNG so the signature
  /// stays legible on any PDF surface.
  Future<Uint8List?> _renderPng() async {
    final strokes = [..._strokes, if (_current != null) _current!]
      ..removeWhere((s) => s.isEmpty);
    if (strokes.isEmpty) return null;

    final padSize = _padSize ?? const Size(320, 200);
    const exportSize = Size(600, 200);
    final scale = math.min(
      exportSize.width / padSize.width,
      exportSize.height / padSize.height,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.drawRect(
      Offset.zero & padSize,
      Paint()..color = const Color(0xFFFFFFFF),
    );

    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.5, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        final mid = Offset(
          (stroke[i - 1].dx + stroke[i].dx) / 2,
          (stroke[i - 1].dy + stroke[i].dy) / 2,
        );
        path.quadraticBezierTo(
          stroke[i - 1].dx,
          stroke[i - 1].dy,
          mid.dx,
          mid.dy,
        );
      }
      path.lineTo(stroke.last.dx, stroke.last.dy);
      canvas.drawPath(path, paint);
    }

    final image = await recorder.endRecording().toImage(
      exportSize.width.round(),
      exportSize.height.round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Sign document',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _hasInk ? _clear : null,
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _padSize = constraints.biggest;
                      return GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _SignaturePainter(
                            strokes: _strokes,
                            current: _current,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign with your finger or mouse',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _hasInk ? _save : null,
                      child: const Text('Use signature'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? current;

  _SignaturePainter({required this.strokes, this.current});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final all = [...strokes, if (current != null) current!];
    for (final stroke in all) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.5, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        final mid = Offset(
          (stroke[i - 1].dx + stroke[i].dx) / 2,
          (stroke[i - 1].dy + stroke[i].dy) / 2,
        );
        path.quadraticBezierTo(
          stroke[i - 1].dx,
          stroke[i - 1].dy,
          mid.dx,
          mid.dy,
        );
      }
      path.lineTo(stroke.last.dx, stroke.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
