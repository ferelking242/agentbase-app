import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/github_service.dart';
import '../services/prefs_service.dart';
import '../models/saved_prompt.dart';
import '../models/room.dart';
import '../widgets/send_sheet.dart';

class FullscreenComposerScreen extends StatefulWidget {
  final String initialText;
  final List<AttachedFile> initialFiles;
  final GitHubService github;
  final List<Room> preloadedRooms;

  const FullscreenComposerScreen({
    super.key,
    required this.initialText,
    required this.initialFiles,
    required this.github,
    this.preloadedRooms = const [],
  });

  @override
  State<FullscreenComposerScreen> createState() => _FullscreenComposerScreenState();
}

class _FullscreenComposerScreenState extends State<FullscreenComposerScreen> {
  late final TextEditingController _ctrl;
  late List<AttachedFile> _files;
  bool _saving = false;
  String? _mentionQuery;
  List<Room> _rooms = [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _files = List<AttachedFile>.from(widget.initialFiles);
    _rooms = List.from(widget.preloadedRooms);
    _ctrl.addListener(_onCtrlChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    });
    if (_rooms.isEmpty) _loadRooms();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrlChange);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      final r = await widget.github.fetchRooms();
      if (mounted) setState(() => _rooms = r);
    } catch (_) {}
  }

  // ── @ mention ─────────────────────────────────────────────────────────────
  void _onCtrlChange() {
    final pos = _ctrl.selection.baseOffset;
    if (!_ctrl.selection.isValid || pos < 0 || pos > _ctrl.text.length) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final before = _ctrl.text.substring(0, pos);
    final match = RegExp(r'@(\w*)$').firstMatch(before);
    final q = match?.group(1);
    if (q != _mentionQuery) setState(() => _mentionQuery = q);
  }

  List<AttachedFile> get _mentionSuggestions {
    if (_mentionQuery == null || _files.isEmpty) return [];
    if (_mentionQuery!.isEmpty) return _files;
    return _files
        .where((f) => f.name.toLowerCase().contains(_mentionQuery!.toLowerCase()))
        .toList();
  }

  void _insertMention(AttachedFile f) {
    final pos = _ctrl.selection.baseOffset;
    if (pos < 0) return;
    final before = _ctrl.text.substring(0, pos);
    final after = _ctrl.text.substring(pos);
    final match = RegExp(r'@(\w*)$').firstMatch(before);
    final mention = '@${f.name.replaceAll(' ', '_')}';
    final newBefore = match != null
        ? before.substring(0, match.start) + mention
        : before + mention;
    _ctrl.value = TextEditingValue(
      text: newBefore + after,
      selection: TextSelection.collapsed(offset: newBefore.length),
    );
    setState(() => _mentionQuery = null);
  }

  // ── Attach ────────────────────────────────────────────────────────────────
  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.folder_outlined, color: Color(0xFF6366F1)),
            title: const Text('Fichiers', style: TextStyle(color: Color(0xFFECECEC), fontSize: 15)),
            subtitle: const Text('Tout type de fichier', style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
            onTap: () { Navigator.pop(context); _pickFiles(); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF6366F1)),
            title: const Text('Galerie', style: TextStyle(color: Color(0xFFECECEC), fontSize: 15)),
            subtitle: const Text('Photos et images', style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
            onTap: () { Navigator.pop(context); _pickFromGallery(); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pickFiles() async {
    try {
      final res = await FilePicker.platform
          .pickFiles(allowMultiple: true, withData: true, type: FileType.any);
      if (res == null) return;
      setState(() {
        for (final f in res.files) {
          if (f.bytes != null) {
            final ext = f.name.toLowerCase();
            _files.insert(0, AttachedFile(
              name: f.name,
              bytes: f.bytes!,
              isImage: ext.endsWith('.png') || ext.endsWith('.jpg') ||
                  ext.endsWith('.jpeg') || ext.endsWith('.gif') || ext.endsWith('.webp'),
            ));
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _pickFromGallery() async {
    try {
      final imgs = await ImagePicker().pickMultiImage(imageQuality: 90);
      if (imgs.isEmpty) return;
      for (final img in imgs) {
        final bytes = await img.readAsBytes();
        if (mounted) {
          setState(() => _files.insert(0, AttachedFile(
            name: img.name, bytes: bytes, isImage: true)));
        }
      }
    } catch (_) {}
  }

  void _showImageFullscreen(Uint8List bytes, String name) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(_)),
              ]),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5, maxScale: 5,
                child: Center(child: Image.memory(bytes)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(name, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _renameFile(int i) async {
    final f = _files[i];
    final dot = f.name.lastIndexOf('.');
    final nameOnly = dot > 0 ? f.name.substring(0, dot) : f.name;
    final ext = dot > 0 ? f.name.substring(dot) : '';
    final ctrl = TextEditingController(text: nameOnly);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Renommer',
            style: TextStyle(color: Color(0xFFECECEC), fontSize: 15, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFECECEC), fontSize: 14),
          cursorColor: const Color(0xFF6366F1),
          decoration: InputDecoration(
            suffixText: ext,
            suffixStyle: const TextStyle(color: Color(0xFF555555), fontSize: 14),
            filled: true, fillColor: const Color(0xFF0D0D0D),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6366F1))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onSubmitted: (v) => Navigator.pop(_, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF666666)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName != null && newName.isNotEmpty && mounted) {
      setState(() {
        _files[i] = AttachedFile(name: newName + ext, bytes: f.bytes, isImage: f.isImage);
      });
    }
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
    final defaultName = _ctrl.text.trim().split(' ').take(5).join(' ');
    final result = await showModalBottomSheet<SendResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendSheet(
        defaultName: defaultName,
        preloadedRooms: _rooms,
        github: widget.github,
      ),
    );
    if (result == null) return;
    setState(() => _saving = true);
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      String? roomContext;
      if (result.room != null) {
        roomContext = await widget.github.fetchContext(result.room!.id);
      }
      final link = await widget.github.pushDirectPrompt(
        id, _ctrl.text, _files,
        room: result.room,
        roomContext: roomContext,
      );
      final name = result.name.isNotEmpty ? result.name : defaultName;
      final prompt = SavedPrompt(id: id, name: name, link: link, created: DateTime.now());
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

  @override
  Widget build(BuildContext context) {
    final hasContent = _ctrl.text.trim().isNotEmpty || _files.isNotEmpty;
    final mentions = _mentionSuggestions;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E16),
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF555555), size: 22),
                onPressed: _showAttachMenu,
                tooltip: 'Joindre',
              ),
              IconButton(
                icon: const Icon(Icons.content_paste_rounded, color: Color(0xFF555555), size: 20),
                onPressed: _paste,
                tooltip: 'Coller',
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Color(0xFF555555), size: 24),
                onPressed: () => Navigator.pop(context, null),
                tooltip: 'Reduire',
              ),
            ]),
          ),

          // Attached files
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
                  return GestureDetector(
                    onTap: f.isImage ? () => _showImageFullscreen(f.bytes, f.name) : null,
                    onLongPress: () => _renameFile(i),
                    child: Stack(children: [
                      f.isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(f.bytes, width: 80, height: 80, fit: BoxFit.cover))
                        : Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF2A2A2A))),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF6366F1), size: 28),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(f.name,
                                  style: const TextStyle(color: Color(0xFF999999), fontSize: 9),
                                  maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                              ),
                            ])),
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
                    ]),
                  );
                },
              ),
            ),

          // Text area
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
                      hintText: 'Ecris ton prompt ici… ou tape @',
                      hintStyle: TextStyle(color: Color(0xFF333333), fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
            ),
          ),

          // @ Mention overlay
          if (_mentionQuery != null && mentions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(
                  top: BorderSide(color: Color(0xFF2A2A2A)),
                  bottom: BorderSide(color: Color(0xFF2A2A2A)),
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: mentions.length,
                itemBuilder: (_, i) {
                  final f = mentions[i];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: f.isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(f.bytes, width: 32, height: 32, fit: BoxFit.cover))
                        : Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E2E),
                              borderRadius: BorderRadius.circular(4)),
                            child: const Icon(Icons.insert_drive_file_outlined,
                                size: 16, color: Color(0xFF6366F1))),
                    title: RichText(text: TextSpan(
                      style: const TextStyle(color: Color(0xFFECECEC), fontSize: 13),
                      children: [
                        const TextSpan(text: '@', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
                        TextSpan(text: f.name),
                      ],
                    )),
                    onTap: () => _insertMention(f),
                  );
                },
              ),
            ),

          // Bottom bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
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
                    color: hasContent && !_saving ? Colors.black : const Color(0xFF444444)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
