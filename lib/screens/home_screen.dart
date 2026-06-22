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
import 'fullscreen_composer.dart';

class HomeScreen extends StatefulWidget {
  final GitHubService github;
  final ValueChanged<int> onSection;
  final void Function(SavedPrompt)? onPromptSaved;

  const HomeScreen({
    super.key,
    required this.github,
    required this.onSection,
    this.onPromptSaved,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<_Msg> _msgs = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();
  bool _sending = false;
  List<AttachedFile> _files = [];
  String? _mentionQuery;
  List<Room> _rooms = [];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onCtrlChange);
    _loadRooms();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrlChange);
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      final r = await widget.github.fetchRooms();
      if (mounted) setState(() => _rooms = r);
    } catch (_) {}
  }

  // ── @ mention detection ──────────────────────────────────────────────────
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

  // ── Attach ───────────────────────────────────────────────────────────────
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
            final n = f.name.toLowerCase();
            _files.insert(0, AttachedFile(
              name: f.name,
              bytes: f.bytes!,
              isImage: n.endsWith('.png') || n.endsWith('.jpg') ||
                  n.endsWith('.jpeg') || n.endsWith('.gif') || n.endsWith('.webp'),
            ));
          }
        }
      });
    } catch (_) {}
  }

  /// Extracts a clean filename from an XFile, stripping the iOS image_picker UUID prefix.
  String _cleanImageName(dynamic img, int index) {
    // Try path-based name first (sometimes the real filename is in the path)
    final pathParts = (img.path as String).split('/');
    final pathName = pathParts.isNotEmpty ? pathParts.last : '';
    // Use path-based name if it looks like a real file (not a UUID temp file)
    for (final candidate in [pathName, img.name as String]) {
      if (candidate.isNotEmpty && !_isPickerTempName(candidate)) {
        return candidate;
      }
    }
    // Fallback: generate a clean sequential name
    final ext = _extractExt(img.name as String);
    final now = DateTime.now();
    return 'photo_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}_${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}${now.second.toString().padLeft(2,'0')}${index > 0 ? "_$index" : ""}$ext';
  }

  bool _isPickerTempName(String name) {
    final lower = name.toLowerCase();
    return lower.startsWith('image_picker_') ||
        lower.startsWith('picker_') ||
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}').hasMatch(lower);
  }

  String _extractExt(String name) {
    final dot = name.lastIndexOf('.');
    if (dot > 0 && dot < name.length - 1) return name.substring(dot).toLowerCase();
    return '.jpg';
  }

  Future<void> _pickFromGallery() async {
    try {
      final imgs = await ImagePicker().pickMultiImage(imageQuality: 90);
      if (imgs.isEmpty) return;
      for (int i = 0; i < imgs.length; i++) {
        final img = imgs[i];
        final bytes = await img.readAsBytes();
        if (mounted) {
          setState(() => _files.insert(0, AttachedFile(
            name: _cleanImageName(img, i),
            bytes: bytes,
            isImage: true,
          )));
        }
      }
    } catch (_) {}
  }

  // ── Image fullscreen ─────────────────────────────────────────────────────
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
                  onPressed: () => Navigator.pop(_),
                ),
              ]),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Center(child: Image.memory(bytes)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(name,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Rename file ──────────────────────────────────────────────────────────
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

  // ── Paste ────────────────────────────────────────────────────────────────
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

  Future<void> _openFullscreen() async {
    final result = await Navigator.push<SavedPrompt?>(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenComposerScreen(
          initialText: _ctrl.text,
          initialFiles: List.from(_files),
          github: widget.github,
          preloadedRooms: _rooms,
        ),
      ),
    );
    if (result != null) {
      _ctrl.clear();
      setState(() => _files = []);
      widget.onPromptSaved?.call(result);
    }
  }

  // ── Send ─────────────────────────────────────────────────────────────────
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

    final text = _ctrl.text;
    final filesCopy = List<AttachedFile>.from(_files);
    setState(() {
      _msgs.add(_Msg.user(text, filesCopy, result.room));
      _ctrl.clear();
      _files = [];
      _sending = true;
    });
    _scrollBottom();

    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      String? roomContext;
      if (result.room != null) {
        roomContext = await widget.github.fetchContext(result.room!.id);
      }
      final link = await widget.github.pushDirectPrompt(
        id, text, filesCopy,
        room: result.room,
        roomContext: roomContext,
      );
      final name = result.name.isNotEmpty ? result.name : defaultName;
      final prompt = SavedPrompt(id: id, name: name, link: link, created: DateTime.now());
      await PrefsService.addPrompt(prompt);
      if (!mounted) return;
      setState(() { _msgs.add(_Msg.promptSaved(prompt)); _sending = false; });
      widget.onPromptSaved?.call(prompt);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.add(_Msg.agentError(
            'Configure ton PAT dans Parametres. (${e.toString().replaceAll("Exception: ", "")})'));
        _sending = false;
      });
    }
    _scrollBottom();
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  static const _suggestions = [
    (Icons.lightbulb_outline, 'Analyser un probleme'),
    (Icons.rule_outlined, 'Creer une regle agent'),
    (Icons.workspaces_outlined, 'Explorer les rooms'),
    (Icons.settings_outlined, 'Configurer un agent'),
  ];

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEmpty = _msgs.isEmpty && !_sending;
    final mentions = _mentionSuggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: isEmpty ? _buildHome() : _buildMsgs()),
        if (_mentionQuery != null && mentions.isNotEmpty)
          _buildMentionOverlay(mentions),
        _buildInput(),
      ],
    );
  }

  // ── Mention overlay ───────────────────────────────────────────────────────
  Widget _buildMentionOverlay(List<AttachedFile> suggestions) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
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
        itemCount: suggestions.length,
        itemBuilder: (_, i) {
          final f = suggestions[i];
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
    );
  }

  // ── Home (empty state) ────────────────────────────────────────────────────
  Widget _buildHome() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 80),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Que puis-je faire pour toi\u00a0?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFECECEC),
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            Row(children: [
              Expanded(child: _SuggCard(
                icon: _suggestions[0].$1, label: _suggestions[0].$2,
                onTap: () { _ctrl.text = _suggestions[0].$2; _focus.requestFocus(); setState(() {}); })),
              const SizedBox(width: 10),
              Expanded(child: _SuggCard(
                icon: _suggestions[1].$1, label: _suggestions[1].$2,
                onTap: () { _ctrl.text = _suggestions[1].$2; _focus.requestFocus(); setState(() {}); })),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _SuggCard(
                icon: _suggestions[2].$1, label: _suggestions[2].$2,
                onTap: () { _ctrl.text = _suggestions[2].$2; _focus.requestFocus(); setState(() {}); })),
              const SizedBox(width: 10),
              Expanded(child: _SuggCard(
                icon: _suggestions[3].$1, label: _suggestions[3].$2,
                onTap: () { _ctrl.text = _suggestions[3].$2; _focus.requestFocus(); setState(() {}); })),
            ]),
          ]),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildMsgs() => ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        itemCount: _msgs.length + (_sending ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _msgs.length) return const _TypingDots();
          final m = _msgs[i];
          return m.isUser ? _UserBubble(msg: m, onImageTap: _showImageFullscreen) : _AgentBubble(msg: m);
        },
      );

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInput() {
    final hasContent = _ctrl.text.trim().isNotEmpty || _files.isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_files.isNotEmpty)
              SizedBox(
                height: 72,
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
                                child: Image.memory(f.bytes, width: 72, height: 72, fit: BoxFit.cover))
                            : Container(
                                width: 72, height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF2A2A2A))),
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF6366F1), size: 22),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(f.name,
                                      style: const TextStyle(color: Color(0xFF888888), fontSize: 8),
                                      maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                                  ),
                                ])),
                        Positioned(
                          top: 2, right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _files.removeAt(i)),
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 10, color: Colors.white),
                            ),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
              ),
            if (_files.isNotEmpty) const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2F2F2F),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF3F3F3F), width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF8E8EA0), size: 22),
                    onPressed: _showAttachMenu,
                    tooltip: 'Joindre',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      maxLines: 5,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Color(0xFFECECEC), fontSize: 15, height: 1.45),
                      cursorColor: const Color(0xFF8E8EA0),
                      decoration: const InputDecoration(
                        hintText: 'Envoie un message… ou tape @',
                        hintStyle: TextStyle(color: Color(0xFF8E8EA0), fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_paste_rounded, color: Color(0xFF8E8EA0), size: 18),
                    onPressed: _paste,
                    tooltip: 'Coller',
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen, color: Color(0xFF8E8EA0), size: 20),
                    onPressed: _openFullscreen,
                    tooltip: 'Plein ecran',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 7),
                    child: GestureDetector(
                      onTap: hasContent ? _send : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: hasContent ? const Color(0xFFECECEC) : const Color(0xFF555555),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_upward,
                          size: 18,
                          color: hasContent ? Colors.black : const Color(0xFF888888)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'AgentBase peut faire des erreurs. Verifiez les informations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF4A4A5A), fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message model ──────────────────────────────────────────────────────────
class _Msg {
  final bool isUser;
  final String text;
  final List<AttachedFile> files;
  final SavedPrompt? prompt;
  final String? errorText;
  final Room? room;
  const _Msg._({
    required this.isUser,
    this.text = '',
    this.files = const [],
    this.prompt,
    this.errorText,
    this.room,
  });
  factory _Msg.user(String t, List<AttachedFile> f, Room? r) =>
      _Msg._(isUser: true, text: t, files: f, room: r);
  factory _Msg.promptSaved(SavedPrompt p) => _Msg._(isUser: false, prompt: p);
  factory _Msg.agentError(String e) => _Msg._(isUser: false, errorText: e);
}

// ── Suggestion card ────────────────────────────────────────────────────────
class _SuggCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SuggCard({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: const Color(0xFF8E8EA0)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 12.5, fontWeight: FontWeight.w500),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      );
}

// ── User bubble ────────────────────────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final _Msg msg;
  final void Function(Uint8List, String) onImageTap;
  const _UserBubble({required this.msg, required this.onImageTap});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (msg.room != null)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: msg.room!.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: msg.room!.accentColor.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(msg.room!.iconData, size: 10, color: msg.room!.accentColor),
                  const SizedBox(width: 4),
                  Text(msg.room!.name,
                    style: TextStyle(color: msg.room!.accentColor, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ),
            if (msg.files.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: msg.files.map((f) => f.isImage
                      ? GestureDetector(
                          onTap: () => onImageTap(f.bytes, f.name),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(f.bytes, width: 120, height: 90, fit: BoxFit.cover)))
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(8)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.insert_drive_file_outlined, size: 14, color: Color(0xFF8E8EA0)),
                            const SizedBox(width: 6),
                            Text(f.name, style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 12)),
                          ]))).toList(),
                ),
              ),
            if (msg.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F2F2F),
                  borderRadius: BorderRadius.circular(18)),
                child: Text(msg.text,
                  style: const TextStyle(color: Color(0xFFECECEC), fontSize: 15, height: 1.5)),
              ),
          ]),
        ),
      );
}

// ── Agent bubble ───────────────────────────────────────────────────────────
class _AgentBubble extends StatelessWidget {
  final _Msg msg;
  const _AgentBubble({required this.msg});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 24),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.bolt, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: msg.prompt != null
                  ? _PromptLinkCard(prompt: msg.prompt!)
                  : Text(msg.errorText ?? '',
                      style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14, height: 1.55)),
            ),
          ),
        ]),
      );
}

// ── Prompt link card ───────────────────────────────────────────────────────
class _PromptLinkCard extends StatefulWidget {
  final SavedPrompt prompt;
  const _PromptLinkCard({required this.prompt});
  @override State<_PromptLinkCard> createState() => _PromptLinkCardState();
}
class _PromptLinkCardState extends State<_PromptLinkCard> {
  bool _copied = false;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1A0A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1A3A1A)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF22C55E), size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text('"${widget.prompt.name}"',
                style: const TextStyle(color: Color(0xFF22C55E), fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 6),
          Text('ID: ${widget.prompt.id}', style: const TextStyle(color: Color(0xFF446644), fontSize: 11)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF050F05), borderRadius: BorderRadius.circular(8)),
            child: Text(widget.prompt.link,
              style: const TextStyle(color: Color(0xFF5A9A5A), fontSize: 11, fontFamily: 'monospace'),
              maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.prompt.link));
                setState(() => _copied = true);
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => _copied = false);
                });
              },
              icon: Icon(_copied ? Icons.check : Icons.copy, size: 15),
              label: Text(_copied ? 'Copie !' : 'Copier le lien agent'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _copied ? const Color(0xFF14532D) : const Color(0xFF1A3A1A),
                foregroundColor: _copied ? const Color(0xFF22C55E) : const Color(0xFF86EFAC),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      );
}

// ── Typing dots ────────────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override State<_TypingDots> createState() => _TypingDotsState();
}
class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.bolt, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                children: List.generate(3, (i) {
                  final t = (_ctrl.value - i * 0.33).clamp(0.0, 1.0);
                  final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(color: Color(0xFF8E8EA0), shape: BoxShape.circle)),
                    ),
                  );
                }),
              ),
            ),
          ),
        ]),
      );
}
