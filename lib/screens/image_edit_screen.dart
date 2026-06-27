import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../widgets/app_components.dart';

class ImageEditScreen extends StatefulWidget {
  final Uint8List bytes;
  final String name;

  const ImageEditScreen({super.key, required this.bytes, required this.name});

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

enum _EditMode { adjust, draw, rotate }

class _ImageEditScreenState extends State<ImageEditScreen> {
  // Adjust sliders
  double _brightness = 0;
  double _contrast   = 0;
  double _saturation = 0;
  double _rotation   = 0; // degrees

  // Draw mode
  _EditMode _mode = _EditMode.adjust;
  final List<_Stroke> _strokes = [];
  _Stroke? _currentStroke;
  Color _penColor = Colors.redAccent;
  double _penWidth = 4;
  bool _isEraser = false;

  // Decoded image
  ui.Image? _decodedImage;
  bool _saving = false;

  final List<Color> _palette = [
    Colors.redAccent, Colors.orangeAccent, Colors.yellowAccent,
    Colors.greenAccent, Colors.blueAccent, Colors.purpleAccent,
    Colors.white, Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    final codec = await ui.instantiateImageCodec(widget.bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _decodedImage = frame.image);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final result = await _renderImage();
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      setState(() => _saving = false);
      if (mounted) showAppSnack(context, 'Erreur lors du rendu', isError: true);
    }
  }

  Future<Uint8List> _renderImage() async {
    if (_decodedImage == null) return widget.bytes;

    final turns = (_rotation / 90).round() % 4;
    final w = _decodedImage!.width.toDouble();
    final h = _decodedImage!.height.toDouble();
    final rw = (turns == 1 || turns == 3) ? h : w;
    final rh = (turns == 1 || turns == 3) ? w : h;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.save();
    canvas.translate(rw / 2, rh / 2);
    canvas.rotate(_rotation * pi / 180);
    canvas.translate(-w / 2, -h / 2);

    final paint = Paint();
    if (_brightness != 0 || _contrast != 0) {
      final b = _brightness / 100;
      final c = (_contrast / 100) + 1;
      paint.colorFilter = ColorFilter.matrix(<double>[
        c,   0.0, 0.0, 0.0, b * 255,
        0.0, c,   0.0, 0.0, b * 255,
        0.0, 0.0, c,   0.0, b * 255,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    }
    canvas.drawImage(_decodedImage!, Offset.zero, paint);
    canvas.restore();

    // Draw strokes (normalized coords → image coords)
    for (final stroke in _strokes) {
      if (stroke.points.length < 2) continue;
      final sPaint = Paint()
        ..color = stroke.isEraser ? Colors.transparent : stroke.color
        ..strokeWidth = stroke.width * (rw / 400)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;
      final path = Path();
      path.moveTo(stroke.points.first.dx * rw, stroke.points.first.dy * rh);
      for (final p in stroke.points.skip(1)) {
        path.lineTo(p.dx * rw, p.dy * rh);
      }
      canvas.drawPath(path, sPaint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(rw.toInt(), rh.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _undo() {
    if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          color: Colors.black,
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 34, height: 34,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close, size: 17, color: Colors.white60)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (_mode == _EditMode.draw && _strokes.isNotEmpty)
              IconButton(icon: const Icon(Icons.undo_rounded, color: Colors.white60, size: 22), onPressed: _undo),
            AppButton(
              label: _saving ? 'Enregistrement…' : 'Appliquer',
              icon: _saving ? null : Icons.check,
              loading: _saving,
              onTap: _saving ? null : _save,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ]),
        ),

        // Mode tabs
        Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(children: _EditMode.values.map((m) {
            final labels = {_EditMode.adjust: 'Réglages', _EditMode.draw: 'Dessiner', _EditMode.rotate: 'Rotation'};
            final icons  = {_EditMode.adjust: Icons.tune, _EditMode.draw: Icons.edit_rounded, _EditMode.rotate: Icons.rotate_90_degrees_cw_outlined};
            final active = _mode == m;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _mode = m),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? kAccent : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icons[m], size: 14, color: active ? Colors.white : Colors.white38),
                  const SizedBox(width: 5),
                  Text(labels[m]!, style: GoogleFonts.inter(color: active ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
              ),
            ));
          }).toList()),
        ),

        // Image canvas
        Expanded(child: _buildCanvas()),

        // Bottom panel
        _buildBottomPanel(),
      ])),
    );
  }

  Widget _buildCanvas() {
    if (_decodedImage == null) return const Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2));

    if (_mode == _EditMode.draw) {
      return LayoutBuilder(builder: (_, constraints) {
        return GestureDetector(
          onPanStart: (d) {
            final norm = _normalize(d.localPosition, constraints.biggest);
            setState(() => _currentStroke = _Stroke(color: _isEraser ? Colors.transparent : _penColor, width: _penWidth, isEraser: _isEraser, points: [norm]));
          },
          onPanUpdate: (d) {
            if (_currentStroke != null) setState(() => _currentStroke!.points.add(_normalize(d.localPosition, constraints.biggest)));
          },
          onPanEnd: (_) {
            if (_currentStroke != null) setState(() { _strokes.add(_currentStroke!); _currentStroke = null; });
          },
          child: CustomPaint(
            painter: _DrawPainter(image: _decodedImage!, strokes: _strokes, currentStroke: _currentStroke),
            size: constraints.biggest,
          ),
        );
      });
    }

    return Center(child: ColorFiltered(
      colorFilter: _buildColorFilter(),
      child: Transform.rotate(
        angle: _rotation * pi / 180,
        child: Image.memory(widget.bytes, fit: BoxFit.contain),
      ),
    ));
  }

  Offset _normalize(Offset pos, Size size) => Offset(pos.dx / size.width, pos.dy / size.height);

  ColorFilter _buildColorFilter() {
    final b = _brightness / 100;
    final c = (_contrast / 100) + 1;
    return ColorFilter.matrix(<double>[
      c,   0.0, 0.0, 0.0, b * 255,
      0.0, c,   0.0, 0.0, b * 255,
      0.0, 0.0, c,   0.0, b * 255,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ]);
  }

  Widget _buildBottomPanel() {
    switch (_mode) {
      case _EditMode.adjust: return _buildAdjustPanel();
      case _EditMode.draw:   return _buildDrawPanel();
      case _EditMode.rotate: return _buildRotatePanel();
    }
  }

  Widget _buildAdjustPanel() => Container(
    color: Colors.black,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _SliderRow(label: 'Luminosité', value: _brightness, min: -100, max: 100, onChanged: (v) => setState(() => _brightness = v)),
      _SliderRow(label: 'Contraste',  value: _contrast,   min: -100, max: 100, onChanged: (v) => setState(() => _contrast  = v)),
      _SliderRow(label: 'Saturation', value: _saturation, min: -100, max: 100, onChanged: (v) => setState(() => _saturation = v)),
    ]),
  );

  Widget _buildDrawPanel() => Container(
    color: Colors.black,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        ..._palette.map((c) => GestureDetector(
          onTap: () => setState(() { _penColor = c; _isEraser = false; }),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: c, shape: BoxShape.circle,
              border: Border.all(color: (_penColor == c && !_isEraser) ? Colors.white : Colors.white24, width: 2),
            ),
          ),
        )),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _isEraser = !_isEraser),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isEraser ? Colors.white24 : Colors.white10,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _isEraser ? Colors.white54 : Colors.white12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.auto_fix_high, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text('Gomme', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11.5)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Text('Taille', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
        Expanded(child: SliderTheme(
          data: SliderTheme.of(context).copyWith(activeTrackColor: kAccent, inactiveTrackColor: Colors.white12, thumbColor: Colors.white, overlayColor: kAccent.withOpacity(0.2), trackHeight: 3),
          child: Slider(value: _penWidth, min: 1, max: 20, divisions: 19, onChanged: (v) => setState(() => _penWidth = v)),
        )),
        Container(width: _penWidth.clamp(6, 20), height: _penWidth.clamp(6, 20), decoration: BoxDecoration(color: _isEraser ? Colors.white30 : _penColor, shape: BoxShape.circle)),
      ]),
    ]),
  );

  Widget _buildRotatePanel() => Container(
    color: Colors.black,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Rotation', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, letterSpacing: 0.5)),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _RotBtn(icon: Icons.rotate_left, label: '−90°', onTap: () => setState(() => _rotation = (_rotation - 90) % 360)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
          child: Text('${_rotation.toInt()}°', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        _RotBtn(icon: Icons.rotate_right, label: '+90°', onTap: () => setState(() => _rotation = (_rotation + 90) % 360)),
      ]),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => setState(() => _rotation = 0),
        child: Text('Réinitialiser', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
      ),
    ]),
  );
}

// ── _SliderRow ────────────────────────────────────────────────────────────────
class _SliderRow extends StatelessWidget {
  final String label; final double value, min, max; final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.value, required this.min, required this.max, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12))),
      Expanded(child: SliderTheme(
        data: SliderTheme.of(context).copyWith(activeTrackColor: kAccent, inactiveTrackColor: Colors.white12, thumbColor: Colors.white, overlayColor: kAccent.withOpacity(0.2), trackHeight: 3),
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      )),
      SizedBox(width: 38, child: Text('${value.toInt()}', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11.5), textAlign: TextAlign.end)),
    ]),
  );
}

// ── _RotBtn ───────────────────────────────────────────────────────────────────
class _RotBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _RotBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 22, color: Colors.white70)),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
    ]),
  );
}

// ── _Stroke ───────────────────────────────────────────────────────────────────
class _Stroke {
  final Color color;
  final double width;
  final bool isEraser;
  final List<Offset> points;
  _Stroke({required this.color, required this.width, required this.isEraser, required this.points});
}

// ── _DrawPainter ─────────────────────────────────────────────────────────────
class _DrawPainter extends CustomPainter {
  final ui.Image image;
  final List<_Stroke> strokes;
  final _Stroke? currentStroke;

  const _DrawPainter({required this.image, required this.strokes, this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    // Fit image in canvas
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = _fitRect(srcRect, size);
    canvas.drawImageRect(image, srcRect, dstRect, Paint());

    void drawStroke(_Stroke stroke) {
      if (stroke.points.length < 2) return;
      final paint = Paint()
        ..color = stroke.isEraser ? Colors.white.withOpacity(0.3) : stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      path.moveTo(stroke.points.first.dx * size.width, stroke.points.first.dy * size.height);
      for (final p in stroke.points.skip(1)) path.lineTo(p.dx * size.width, p.dy * size.height);
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) drawStroke(s);
    if (currentStroke != null) drawStroke(currentStroke!);
  }

  Rect _fitRect(Rect src, Size dst) {
    final srcAspect = src.width / src.height;
    final dstAspect = dst.width / dst.height;
    double w, h;
    if (srcAspect > dstAspect) { w = dst.width; h = w / srcAspect; }
    else { h = dst.height; w = h * srcAspect; }
    return Rect.fromLTWH((dst.width - w) / 2, (dst.height - h) / 2, w, h);
  }

  @override
  bool shouldRepaint(_DrawPainter old) => true;
}
