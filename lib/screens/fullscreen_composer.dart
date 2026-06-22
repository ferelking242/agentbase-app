import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/github_service.dart';
import '../services/prefs_service.dart';
import '../models/saved_prompt.dart';

class FullscreenComposerScreen extends StatefulWidget {
  final String initialText;
  final List<AttachedFile> initialFiles;
  final GitHubService github;

  const FullscreenComposerScreen({
    super.key,
    required this.initialText,
    required this.initialFiles,
    required this.github,
  });

  @override
  State<FullscreenComposerScreen> createState() => _FullscreenComposerScreenState();
}

class _FullscreenComposerScreenState extends State<FullscreenComposerScreen> {
  late final TextEditingController _ctrl;
  late List<AttachedFile> _files;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _files = List<AttachedFile>.from(widget.initialFiles);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true, withData: true, type: FileType.any,
      );
      if (res == null) return;
      setState(() {
        for (final f in res.files) {
          if (f.bytes != null) {
            final ext = f.name.toLowerCase();
            _files.insert(0, AttachedFile(
              name: f.name, bytes: f.bytes!,
              isImage: ext.endsWith('.png') || ext.endsWith('.jpg') ||
                       ext.endsWith('.jpeg') || ext.endsWith('.gif') || ext.endsWith('.webp'),
            ));
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) return;
    final pos = _ctrl.selection.isValid ? _ctrl.selection.baseOffset : _ctrl.text.length;
    final before = _ctrl.text.substring(0, pos);
    final after = _ctrl.text.substring(pos);
    _ctrl.value = TextEditingValue(
      text: before + data.text! + after,
      selection: TextSelection.collapsed(offset: pos + data.text!.length),
    );
    setState(() {});
  }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty && _files.isEmpty) return;

    // Show name dialog
    final defaultName = _ctrl.text.trim().split(' ').take(5).join(' ');
    final name = await _showNameDialog(defaultName);
    if (name == null) return;

    setState(() => _saving = true);

    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final link = await widget.github.pushDirectPrompt(id, _ctrl.text, _files);
      final prompt = SavedPrompt(id: id, name: name.isNotEmpty ? name : defaultName, link: link, created: DateTime.now());
      await PrefsService.addPrompt(prompt);
      if (!mounted) return;
      Navigator.pop(context, prompt);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: ${e.toString().replaceAll("Exception: ", "")}'),
        backgroundColor: const Color(0xFF3A1010),
      ));
    }
  }

  Future<String?> _showNameDialog(String defaultName) {
    final ctrl = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nom du prompt', style: TextStyle(color: Color(0xFFECECEC), fontSize: 16, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFECECEC), fontSize: 15),
          cursorColor: const Color(0xFF6366F1),
          decoration: InputDecoration(
            hintText: 'Ex: Analyse de donnees',
            hintStyle: const TextStyle(color: Color(0xFF555555)),
            filled: true, fillColor: const Color(0xFF0D0D0D),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4A4A8A))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onSubmitted: (v) => Navigator.pop(_, v.trim().isNotEmpty ? v.trim() : defaultName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : defaultName),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _ctrl.text.trim().isNotEmpty || _files.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  // + attach
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF555555), size: 22),
                    onPressed: _pickFiles,
                    tooltip: 'Joindre',
                  ),
                  // paste
                  IconButton(
                    icon: const Icon(Icons.content_paste_rounded, color: Color(0xFF555555), size: 20),
                    onPressed: _paste,
                    tooltip: 'Coller',
                  ),
                  const Spacer(),
                  // compress / close
                  IconButton(
                    icon: const Icon(Icons.fullscreen_exit, color: Color(0xFF555555), size: 24),
                    onPressed: () => Navigator.pop(context, null),
                    tooltip: 'Reduire',
                  ),
                ],
              ),
            ),
            // ── Attached images at top ────────────────────────────────────
            if (_files.isNotEmpty)
              Container(
                height: 80,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _files.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _files[i];
                    return Stack(
                      children: [
                        f.isImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(f.bytes, width: 80, height: 80, fit: BoxFit.cover),
                            )
                          : Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF2A2A2A)),
                              ),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF6366F1), size: 28),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(f.name, style: const TextStyle(color: Color(0xFF999999), fontSize: 9),
                                      maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                                ),
                              ]),
                            ),
                        Positioned(
                          top: 2, right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _files.removeAt(i)),
                            child: Container(
                              width: 18, height: 18,
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            // ── Text area ────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _saving
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 2))
                  : TextField(
                      controller: _ctrl,
                      maxLines: null,
                      expands: true,
                      autofocus: true,
                      textAlignVertical: TextAlignVertical.top,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Color(0xFFECECEC), fontSize: 16, height: 1.6),
                      cursorColor: const Color(0xFF6366F1),
                      decoration: const InputDecoration(
                        hintText: 'Ecris ton prompt ici...',
                        hintStyle: TextStyle(color: Color(0xFF333333), fontSize: 16),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
              ),
            ),
            // ── Bottom bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: hasContent && !_saving ? _send : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: hasContent && !_saving ? const Color(0xFFECECEC) : const Color(0xFF222222),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_upward,
                        size: 20,
                        color: hasContent && !_saving ? Colors.black : const Color(0xFF444444),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
