import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/github_service.dart';
import '../services/prefs_service.dart';
import '../models/saved_prompt.dart';
import '../models/room.dart';
import '../theme.dart';
import '../widgets/app_components.dart';
import '../widgets/send_sheet.dart';
import '../widgets/prompts_sheet.dart';
import 'fullscreen_composer.dart';
import 'image_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  final GitHubService github;
  final VoidCallback onOpenDrawer;
  final void Function(SavedPrompt)? onPromptSaved;
  final List<SavedPrompt> prompts;
  final VoidCallback onSyncRequest;
  final void Function(String id) onDeletePrompt;

  const HomeScreen({
    super.key,
    required this.github,
    required this.onOpenDrawer,
    this.onPromptSaved,
    required this.prompts,
    required this.onSyncRequest,
    required this.onDeletePrompt,
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

  void _onCtrlChange() {
    final pos = _ctrl.selection.baseOffset;
    if (!_ctrl.selection.isValid || pos < 0 || pos > _ctrl.text.length) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final before = _ctrl.text.substring(0, pos);
    final match  = RegExp(r'@(\w*)$').firstMatch(before);
    final q      = match?.group(1);
    if (q != _mentionQuery) setState(() => _mentionQuery = q);
  }

  List<AttachedFile> get _mentionSuggestions {
    if (_mentionQuery == null || _files.isEmpty) return [];
    if (_mentionQuery!.isEmpty) return _files;
    return _files.where((f) => f.name.toLowerCase().contains(_mentionQuery!.toLowerCase())).toList();
  }

  void _insertMention(AttachedFile f) {
    final pos = _ctrl.selection.baseOffset;
    if (pos < 0) return;
    final before = _ctrl.text.substring(0, pos);
    final after  = _ctrl.text.substring(pos);
    final match  = RegExp(r'@(\w*)$').firstMatch(before);
    final mention  = '@${f.name.replaceAll(' ', '_').replaceAll('.', '_')}';
    final newBefore = match != null ? before.substring(0, match.start) + mention : before + mention;
    _ctrl.value = TextEditingValue(
      text: newBefore + after,
      selection: TextSelection.collapsed(offset: newBefore.length),
    );
    setState(() => _mentionQuery = null);
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AppDragHandle(),
          _AttachOption(icon: Icons.folder_outlined,       title: 'Fichiers',      subtitle: 'Tout type de fichier',  onTap: () { Navigator.pop(context); _pickFiles(); }),
          _AttachOption(icon: Icons.photo_library_outlined, title: 'Galerie',       subtitle: 'Photos et images',      onTap: () { Navigator.pop(context); _pickFromGallery(); }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pickFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true, type: FileType.any);
      if (res == null) return;
      setState(() {
        for (final f in res.files) {
          if (f.bytes == null) continue;
          final n = f.name.toLowerCase();
          _files.insert(0, AttachedFile(
            name: f.name, bytes: f.bytes!,
            isImage: n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.gif') || n.endsWith('.webp'),
          ));
        }
      });
    } catch (_) {}
  }

  Future<void> _pickFromGallery() async {
    try {
      final imgs = await ImagePicker().pickMultiImage(imageQuality: 90);
      if (imgs.isEmpty) return;
      for (int i = 0; i < imgs.length; i++) {
        final bytes = await imgs[i].readAsBytes();
        // Keep the real name from the picker; only fallback to timestamp if it's a temp UUID
        final rawName = imgs[i].name;
        final name = _isTempName(rawName) ? _stampName(i) : rawName;
        if (mounted) setState(() => _files.insert(0, AttachedFile(name: name, bytes: bytes, isImage: true)));
      }
    } catch (_) {}
  }

  bool _isTempName(String n) {
    final l = n.toLowerCase();
    return l.isEmpty ||
        l.startsWith('image_picker_') ||
        l.startsWith('picker_') ||
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}').hasMatch(l);
  }

  String _stampName(int idx) {
    final t = DateTime.now();
    final s = idx > 0 ? '_$idx' : '';
    return 'photo_${t.year}${_p(t.month)}${_p(t.day)}_${_p(t.hour)}${_p(t.minute)}${_p(t.second)}$s.jpg';
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  Future<void> _editImage(int i) async {
    final f = _files[i];
    if (!f.isImage) return;
    final result = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(builder: (_) => ImageEditScreen(bytes: f.bytes, name: f.name)),
    );
    if (result != null && mounted) {
      setState(() => _files[i] = AttachedFile(name: f.name, bytes: result, isImage: true));
    }
  }

  Future<void> _renameFile(int i) async {
    final f   = _files[i];
    final dot = f.name.lastIndexOf('.');
    final nameOnly = dot > 0 ? f.name.substring(0, dot) : f.name;
    final ext      = dot > 0 ? f.name.substring(dot) : '';
    final ctrl = TextEditingController(text: nameOnly);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kBorder, width: 0.5)),
        title: Text('Renommer', style: GoogleFonts.inter(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
        content: AppInput(controller: ctrl, autofocus: true, suffixText: ext, hint: 'Nom du fichier', onSubmitted: (v) => Navigator.pop(_, v.trim())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: Text('Annuler', style: GoogleFonts.inter(color: kMuted))),
          AppButton(label: 'OK', onTap: () => Navigator.pop(_, ctrl.text.trim()), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
        ],
      ),
    );
    ctrl.dispose();
    if (newName != null && newName.isNotEmpty && mounted) {
      setState(() => _files[i] = AttachedFile(name: newName + ext, bytes: f.bytes, isImage: f.isImage));
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) return;
    final pos    = _ctrl.selection.isValid ? _ctrl.selection.baseOffset : _ctrl.text.length;
    final before = _ctrl.text.substring(0, pos);
    final after  = _ctrl.text.substring(pos);
    _ctrl.value = TextEditingValue(
      text: before + data.text! + after,
      selection: TextSelection.collapsed(offset: pos + data.text!.length),
    );
    setState(() {});
  }

  Future<void> _openFullscreen() async {
    final result = await Navigator.push<SavedPrompt?>(
      context,
      MaterialPageRoute(builder: (_) => FullscreenComposerScreen(
        initialText: _ctrl.text,
        initialFiles: List.from(_files),
        github: widget.github,
        preloadedRooms: _rooms,
      )),
    );
    if (result != null) {
      _ctrl.clear();
      setState(() => _files = []);
      widget.onPromptSaved?.call(result);
    }
  }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty && _files.isEmpty) return;
    final defaultName = _ctrl.text.trim().split(' ').take(5).join(' ');
    final result = await showModalBottomSheet<SendResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendSheet(defaultName: defaultName, preloadedRooms: _rooms, github: widget.github),
    );
    if (result == null) return;

    final text      = _ctrl.text;
    final filesCopy = List<AttachedFile>.from(_files);
    setState(() { _msgs.add(_Msg.user(text, filesCopy, result.room)); _ctrl.clear(); _files = []; _sending = true; });
    _scrollBottom();

    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      String? roomContext;
      if (result.room != null) roomContext = await widget.github.fetchContext(result.room!.id);
      final link   = await widget.github.pushDirectPrompt(id, text, filesCopy, room: result.room, roomContext: roomContext);
      final name   = result.name.isNotEmpty ? result.name : defaultName;
      final prompt = SavedPrompt(id: id, name: name, link: link, created: DateTime.now());
      final saved  = await PrefsService.addPrompt(prompt);
      if (!mounted) return;
      setState(() { _msgs.add(_Msg.promptSaved(saved)); _sending = false; });
      widget.onPromptSaved?.call(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.add(_Msg.agentError('Configure ton token dans Paramètres. (${e.toString().replaceAll("Exception: ", "")})'));
        _sending = false;
      });
    }
    _scrollBottom();
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    });
  }

  void _showPromptsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PromptsSheet(
        prompts: widget.prompts,
        github: widget.github,
        onSync: () { Navigator.pop(context); widget.onSyncRequest(); },
        onDelete: (id) { widget.onDeletePrompt(id); },
      ),
    );
  }

  void _showImageFullscreen(Uint8List bytes, String name) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(children: [
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: Colors.white60), onPressed: () => Navigator.pop(_)),
            ]),
          ),
          Expanded(child: InteractiveViewer(minScale: 0.5, maxScale: 5, child: Center(child: Image.memory(bytes)))),
          Padding(padding: const EdgeInsets.all(12), child: Text(name, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center)),
        ])),
      ),
    );
  }

  static const _suggestions = [
    (Icons.lightbulb_outline,   'Analyser un problème'),
    (Icons.rule_outlined,       'Créer une règle agent'),
    (Icons.workspaces_outlined, 'Explorer les rooms'),
    (Icons.settings_outlined,   'Configurer un agent'),
  ];

  @override
  Widget build(BuildContext context) {
    final isEmpty   = _msgs.isEmpty && !_sending;
    final mentions  = _mentionSuggestions;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildHeader(),
      Expanded(child: isEmpty ? _buildHome() : _buildMsgs()),
      if (_mentionQuery != null && mentions.isNotEmpty) _buildMentionOverlay(mentions),
      _buildInput(),
    ]);
  }

  Widget _buildHeader() => SafeArea(
    bottom: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: kBg,
        border: Border(bottom: BorderSide(color: kBorder, width: 0.5)),
      ),
      child: Row(children: [
        // Hamburger → open drawer
        GestureDetector(
          onTap: widget.onOpenDrawer,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
            child: const Icon(Icons.menu_rounded, size: 18, color: kMuted),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kAccent, Color(0xFF4F46E5)]),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.bolt, size: 15, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text('AgentBase', style: GoogleFonts.inter(color: kText, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.4)),
        const Spacer(),
        _IconBtn(icon: Icons.sync_rounded, onTap: widget.onSyncRequest, tooltip: 'Sync'),
        const SizedBox(width: 6),
        _IconBtn(icon: Icons.article_outlined, onTap: _showPromptsSheet, tooltip: 'Prompts',
          badge: widget.prompts.isNotEmpty ? '${widget.prompts.length}' : null),
      ]),
    ),
  );

  Widget _buildMentionOverlay(List<AttachedFile> suggestions) => Container(
    constraints: const BoxConstraints(maxHeight: 180),
    decoration: const BoxDecoration(
      color: kCard,
      border: Border(top: BorderSide(color: kBorder, width: 0.5), bottom: BorderSide(color: kBorder, width: 0.5)),
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
              ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.memory(f.bytes, width: 32, height: 32, fit: BoxFit.cover))
              : Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.insert_drive_file_outlined, size: 16, color: kAccentMid)),
          title: RichText(text: TextSpan(
            style: GoogleFonts.inter(color: kText, fontSize: 13),
            children: [
              TextSpan(text: '@', style: GoogleFonts.inter(color: kAccentMid, fontWeight: FontWeight.w700)),
              TextSpan(text: f.name.replaceAll(' ', '_').replaceAll('.', '_')),
            ],
          )),
          onTap: () => _insertMention(f),
        );
      },
    ),
  );

  Widget _buildHome() => ListView(padding: EdgeInsets.zero, children: [
    const SizedBox(height: 60),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        Text('Que puis-je faire pour toi ?',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: kText, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.3)),
        const SizedBox(height: 6),
        Text('Compose un prompt, attache des fichiers, envoie dans une room.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: kMuted2, fontSize: 13, height: 1.5)),
      ]),
    ),
    const SizedBox(height: 28),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        Row(children: _suggestions.take(2).map((s) => Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _SuggCard(icon: s.$1, label: s.$2, onTap: () { _ctrl.text = s.$2; _focus.requestFocus(); setState(() {}); }),
        ))).toList()),
        const SizedBox(height: 8),
        Row(children: _suggestions.skip(2).map((s) => Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _SuggCard(icon: s.$1, label: s.$2, onTap: () { _ctrl.text = s.$2; _focus.requestFocus(); setState(() {}); }),
        ))).toList()),
      ]),
    ),
    const SizedBox(height: 40),
  ]);

  Widget _buildMsgs() => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    itemCount: _msgs.length + (_sending ? 1 : 0),
    itemBuilder: (_, i) {
      if (i == _msgs.length) return const _TypingDots();
      final m = _msgs[i];
      return m.isUser
          ? _UserBubble(msg: m, onImageTap: _showImageFullscreen)
          : _AgentBubble(msg: m);
    },
  );

  Widget _buildInput() {
    final hasContent = _ctrl.text.trim().isNotEmpty || _files.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        decoration: const BoxDecoration(
          color: kBg,
          border: Border(top: BorderSide(color: kBorder, width: 0.5)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // File chips
          if (_files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _files.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => _FileChip(
                    file: _files[i],
                    onTap:      _files[i].isImage ? () => _showImageFullscreen(_files[i].bytes, _files[i].name) : null,
                    onLongPress: () => _showFileMenu(i),
                    onRemove:   () => setState(() => _files.removeAt(i)),
                  ),
                ),
              ),
            ),
          // Input container
          Container(
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder, width: 0.5),
            ),
            child: Column(children: [
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                maxLines: 6, minLines: 1,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(color: kText, fontSize: 14, height: 1.5),
                cursorColor: kAccent,
                cursorWidth: 1.5,
                decoration: InputDecoration(
                  hintText: 'Écris ton prompt… ou tape @',
                  hintStyle: GoogleFonts.inter(color: kMuted2, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  isDense: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(children: [
                  _ToolBtn(icon: Icons.add, onTap: _showAttachMenu, tooltip: 'Joindre'),
                  _ToolBtn(icon: Icons.content_paste_rounded, onTap: _paste, tooltip: 'Coller'),
                  _ToolBtn(icon: Icons.open_in_full_rounded, onTap: _openFullscreen, tooltip: 'Plein écran'),
                  const Spacer(),
                  GestureDetector(
                    onTap: hasContent ? _send : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: hasContent ? kAccent : kCard2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: hasContent ? Colors.transparent : kBorder, width: 0.5),
                      ),
                      child: Icon(Icons.arrow_upward_rounded, size: 18, color: hasContent ? Colors.white : kMuted2),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showFileMenu(int i) {
    final f = _files[i];
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AppDragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(children: [
              const Icon(Icons.insert_drive_file_outlined, size: 16, color: kMuted2),
              const SizedBox(width: 8),
              Expanded(child: Text(f.name, style: GoogleFonts.inter(color: kText, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ),
          const AppDivider(),
          if (f.isImage)
            ListTile(
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit_outlined, size: 18, color: kAccentMid)),
              title: Text('Éditer l\'image', style: GoogleFonts.inter(color: kText, fontSize: 14)),
              subtitle: Text('Luminosité, contraste, saturation, rotation', style: GoogleFonts.inter(color: kMuted2, fontSize: 11.5)),
              onTap: () { Navigator.pop(context); _editImage(i); },
            ),
          ListTile(
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.drive_file_rename_outline, size: 18, color: kMuted)),
            title: Text('Renommer', style: GoogleFonts.inter(color: kText, fontSize: 14)),
            onTap: () { Navigator.pop(context); _renameFile(i); },
          ),
          ListTile(
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: kRedSub.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.delete_outline, size: 18, color: kRed)),
            title: Text('Supprimer', style: GoogleFonts.inter(color: kRed, fontSize: 14)),
            onTap: () { Navigator.pop(context); setState(() => _files.removeAt(i)); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ── _FileChip ─────────────────────────────────────────────────────────────────
class _FileChip extends StatelessWidget {
  final AttachedFile file;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onRemove;
  const _FileChip({required this.file, this.onTap, this.onLongPress, required this.onRemove});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    onLongPress: onLongPress,
    child: Stack(children: [
      file.isImage
          ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(file.bytes, width: 78, height: 78, fit: BoxFit.cover))
          : Container(
              width: 78, height: 78,
              decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder, width: 0.5)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.insert_drive_file_outlined, color: kAccentMid, size: 24),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(file.name, style: GoogleFonts.inter(color: kMuted2, fontSize: 8.5), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ),
              ])),
      // Edit badge for images (hint)
      if (file.isImage) Positioned(
        bottom: 3, left: 3,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
          child: const Icon(Icons.edit, size: 9, color: Colors.white70),
        ),
      ),
      Positioned(
        top: 2, right: 2,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            width: 18, height: 18,
            decoration: BoxDecoration(color: kBg.withValues(alpha: 0.85), shape: BoxShape.circle, border: Border.all(color: kBorder, width: 0.5)),
            child: const Icon(Icons.close, size: 11, color: kText),
          ),
        ),
      ),
    ]),
  );
}

// ── _ToolBtn / _IconBtn ───────────────────────────────────────────────────────
class _ToolBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final String tooltip;
  const _ToolBtn({required this.icon, required this.onTap, required this.tooltip});
  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 18, color: kMuted2), onPressed: onTap, tooltip: tooltip,
    splashRadius: 18, constraints: const BoxConstraints(minWidth: 34, minHeight: 34), padding: const EdgeInsets.all(6),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final String tooltip; final String? badge;
  const _IconBtn({required this.icon, required this.onTap, required this.tooltip, this.badge});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
        child: Icon(icon, size: 17, color: kMuted),
      ),
      if (badge != null) Positioned(
        top: -4, right: -4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(99)),
          child: Text(badge!, style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
        ),
      ),
    ]),
  );
}

// ── _SuggCard ─────────────────────────────────────────────────────────────────
class _SuggCard extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _SuggCard({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 15, color: kAccentMid)),
        const SizedBox(height: 10),
        Text(label, style: GoogleFonts.inter(color: kText2, fontSize: 12.5, height: 1.4)),
      ]),
    ),
  );
}

// ── _AttachOption ─────────────────────────────────────────────────────────────
class _AttachOption extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const _AttachOption({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: kAccentMid, size: 20)),
    title: Text(title, style: GoogleFonts.inter(color: kText, fontSize: 14, fontWeight: FontWeight.w500)),
    subtitle: Text(subtitle, style: GoogleFonts.inter(color: kMuted2, fontSize: 12)),
    onTap: onTap,
  );
}

// ── Msg model ─────────────────────────────────────────────────────────────────
enum _MsgKind { user, promptSaved, agentError }

class _Msg {
  final _MsgKind kind;
  final String text;
  final List<AttachedFile> files;
  final Room? room;
  final SavedPrompt? prompt;
  _Msg._({required this.kind, this.text = '', this.files = const [], this.room, this.prompt});
  factory _Msg.user(String t, List<AttachedFile> f, Room? r)   => _Msg._(kind: _MsgKind.user, text: t, files: f, room: r);
  factory _Msg.promptSaved(SavedPrompt p)                       => _Msg._(kind: _MsgKind.promptSaved, prompt: p);
  factory _Msg.agentError(String t)                             => _Msg._(kind: _MsgKind.agentError, text: t);
  bool get isUser => kind == _MsgKind.user;
}

// ── _UserBubble ───────────────────────────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final _Msg msg;
  final void Function(Uint8List, String) onImageTap;
  const _UserBubble({required this.msg, required this.onImageTap});

  AttachedFile? _findFile(String mention) {
    final needle = mention.toLowerCase();
    for (final f in msg.files) {
      final normalized = f.name.replaceAll(' ', '_').replaceAll('.', '_').toLowerCase();
      if (normalized == needle || f.name.toLowerCase() == needle) return f;
      // Partial match: allow @screenshot matches screenshot_227.png
      if (normalized.startsWith(needle) || needle.startsWith(normalized.split('.').first)) return f;
    }
    return null;
  }

  List<InlineSpan> _buildSpans(String text) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'@(\w+)');
    int lastEnd = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final f = _findFile(match.group(1)!);
      if (f != null && f.isImage) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: GestureDetector(
              onTap: () => onImageTap(f.bytes, f.name),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(f.bytes, width: 220, fit: BoxFit.cover),
              ),
            ),
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: match.group(0),
          style: const TextStyle(color: kAccentMid, fontWeight: FontWeight.w600),
        ));
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) spans.add(TextSpan(text: text.substring(lastEnd)));
    return spans;
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Non-@mentioned images (thumbnail strip)
          if (msg.files.where((f) => f.isImage).isNotEmpty) Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.end,
              children: msg.files.where((f) {
                if (!f.isImage) return false;
                // Don't show thumbnail if this file is @mentioned in text
                final norm = f.name.replaceAll(' ', '_').replaceAll('.', '_').toLowerCase();
                final baseName = norm.contains('.') ? norm.substring(0, norm.lastIndexOf('_')) : norm;
                return !msg.text.toLowerCase().contains('@$norm') && !msg.text.toLowerCase().contains('@$baseName');
              }).map((f) =>
                GestureDetector(
                  onTap: () => onImageTap(f.bytes, f.name),
                  child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(f.bytes, width: 64, height: 64, fit: BoxFit.cover)),
                )
              ).toList(),
            ),
          ),
          // File chips (non-images)
          ...msg.files.where((f) => !f.isImage).map((f) => Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(6), border: Border.all(color: kBorder, width: 0.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.attach_file, size: 12, color: kAccentMid),
              const SizedBox(width: 4),
              Text(f.name, style: GoogleFonts.inter(color: kMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          )),
          // Text bubble (with inline @mention images)
          if (msg.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: kAccent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14), topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14), bottomRight: Radius.circular(3),
                ),
              ),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13.5, height: 1.5),
                  children: _buildSpans(msg.text),
                ),
              ),
            ),
          if (msg.room != null) Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.workspaces_outlined, size: 10, color: kAccentMid.withValues(alpha: 0.7)),
              const SizedBox(width: 3),
              Text(msg.room!.name, style: GoogleFonts.inter(color: kMuted2, fontSize: 10.5)),
            ]),
          ),
        ]),
      ),
    ),
  );
}

// ── _AgentBubble ──────────────────────────────────────────────────────────────
class _AgentBubble extends StatelessWidget {
  final _Msg msg;
  const _AgentBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isError = msg.kind == _MsgKind.agentError;
    if (msg.kind == _MsgKind.promptSaved) {
      final p = msg.prompt!;
      final num = p.number > 0 ? ' #${p.number}' : '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          padding: const EdgeInsets.all(12),
          color: kGreenSub.withValues(alpha: 0.5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.check_circle_outline, size: 15, color: kGreen),
              const SizedBox(width: 6),
              if (p.number > 0) ...[
                AppBadge('Prompt$num', bg: kGreenSub, fg: kGreen),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(p.name, style: GoogleFonts.inter(color: kText, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: p.link));
                showAppSnack(context, 'Lien copié !');
              },
              child: Text(p.link, style: GoogleFonts.robotoMono(color: kBlue, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isError ? kRedSub.withValues(alpha: 0.6) : kCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3), topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14),
              ),
              border: Border.all(color: isError ? kRed.withValues(alpha: 0.3) : kBorder, width: 0.5),
            ),
            child: Text(msg.text, style: GoogleFonts.inter(color: isError ? kRed : kText2, fontSize: 13.5, height: 1.5)),
          ),
        ),
      ),
    );
  }
}

// ── _TypingDots ───────────────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = ((_ctrl.value - i * 0.15) % 1.0).clamp(0.0, 1.0);
        final opacity = (0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2)).clamp(0.3, 1.0);
        return Container(
          margin: const EdgeInsets.only(right: 4),
          width: 7, height: 7,
          decoration: BoxDecoration(color: kMuted2.withValues(alpha: opacity), shape: BoxShape.circle),
        );
      },
    ))),
  );
}
