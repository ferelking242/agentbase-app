import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

class _ImageEditScreenState extends State<ImageEditScreen> {
  double _brightness = 0.0;   // -1 to 1
  double _contrast   = 1.0;   // 0.5 to 2
  double _saturation = 1.0;   // 0 to 2
  int    _rotation   = 0;     // 0, 90, 180, 270

  final _repaintKey = GlobalKey();
  bool _saving = false;

  List<double> _satMatrix(double s) {
    const lr = 0.299, lg = 0.587, lb = 0.114;
    final sr = lr * (1 - s);
    final sg = lg * (1 - s);
    final sb = lb * (1 - s);
    return [
      sr + s, sg,     sb,     0, 0,
      sr,     sg + s, sb,     0, 0,
      sr,     sg,     sb + s, 0, 0,
      0,      0,      0,      1, 0,
    ];
  }

  List<double> _contrastMatrix(double c) {
    final t = (1 - c) * 128;
    return [
      c, 0, 0, 0, t,
      0, c, 0, 0, t,
      0, 0, c, 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _brightnessMatrix(double b) {
    final v = b * 255;
    return [
      1, 0, 0, 0, v,
      0, 1, 0, 0, v,
      0, 0, 1, 0, v,
      0, 0, 0, 1, 0,
    ];
  }

  bool get _isEdited =>
      _brightness != 0 || _contrast != 1 || _saturation != 1 || _rotation != 0;

  Future<void> _confirm() async {
    if (!_isEdited) { Navigator.pop(context, widget.bytes); return; }
    setState(() => _saving = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 3.0);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final result = data!.buffer.asUint8List();
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnack(context, 'Erreur lors de l\'export', isError: true);
      }
    }
  }

  void _reset() => setState(() {
    _brightness = 0; _contrast = 1; _saturation = 1; _rotation = 0;
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: const Color(0xFF111111),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context, null),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.close, color: Colors.white70, size: 22),
        ),
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (_isEdited) Text('Modifié', style: GoogleFonts.inter(color: kAccentMid, fontSize: 11)),
      ]),
      actions: [
        if (_isEdited)
          GestureDetector(
            onTap: _reset,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('Reset', style: GoogleFonts.inter(color: kMuted, fontSize: 13)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
              : GestureDetector(
                  onTap: _confirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(8)),
                    child: Text('Appliquer', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
        ),
      ],
    ),
    body: Column(children: [
      // Preview
      Expanded(
        child: Center(
          child: RepaintBoundary(
            key: _repaintKey,
            child: Transform.rotate(
              angle: _rotation * pi / 180,
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(_brightnessMatrix(_brightness)),
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(_contrastMatrix(_contrast)),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(_satMatrix(_saturation)),
                    child: Image.memory(
                      widget.bytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      // Controls
      Container(
        color: const Color(0xFF111111),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(children: [
          // Rotate buttons
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _RotBtn(icon: Icons.rotate_left, onTap: () => setState(() => _rotation = (_rotation - 90) % 360)),
            const SizedBox(width: 16),
            Text('${_rotation}°', style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
            const SizedBox(width: 16),
            _RotBtn(icon: Icons.rotate_right, onTap: () => setState(() => _rotation = (_rotation + 90) % 360)),
          ]),
          const SizedBox(height: 12),

          _Slider(
            label: 'Luminosité',
            value: _brightness,
            min: -1, max: 1,
            icon: Icons.wb_sunny_outlined,
            onChanged: (v) => setState(() => _brightness = v),
            displayValue: '${(_brightness * 100).round()}%',
          ),
          _Slider(
            label: 'Contraste',
            value: _contrast,
            min: 0.5, max: 2,
            icon: Icons.contrast,
            onChanged: (v) => setState(() => _contrast = v),
            displayValue: '${(_contrast * 100).round()}%',
          ),
          _Slider(
            label: 'Saturation',
            value: _saturation,
            min: 0, max: 2,
            icon: Icons.palette_outlined,
            onChanged: (v) => setState(() => _saturation = v),
            displayValue: '${(_saturation * 100).round()}%',
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ]),
      ),
    ]),
  );
}

class _Slider extends StatelessWidget {
  final String label;
  final double value, min, max;
  final IconData icon;
  final ValueChanged<double> onChanged;
  final String displayValue;

  const _Slider({required this.label, required this.value, required this.min, required this.max, required this.icon, required this.onChanged, required this.displayValue});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.white54),
      const SizedBox(width: 8),
      SizedBox(width: 76, child: Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12))),
      Expanded(child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          trackHeight: 2,
          activeTrackColor: kAccentMid,
          inactiveTrackColor: Colors.white12,
          thumbColor: Colors.white,
          overlayColor: kAccent.withValues(alpha: 0.2),
        ),
        child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      )),
      SizedBox(width: 44, child: Text(displayValue, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11), textAlign: TextAlign.right)),
    ]),
  );
}

class _RotBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RotBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 20, color: Colors.white70),
    ),
  );
}
