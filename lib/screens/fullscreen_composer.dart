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
    return _files.where((f) => f.name.toLowerCase().contains(_mentionQuery!.toLowerCase())).toList();
  }

  void _insertMention(AttachedFile f) {
    final pos = _ctrl.selection.baseOffset;
    if (pos < 0) return;
    final before = _ctrl.text.substring(0, pos);
    final after = _ctrl.text.substring(pos);
    final match = RegExp(r'@(\w*)$').firstMatch(before);
    final mention = '@${f.name.replaceAll(' ', '_')}';
    final newBefore = match != null ? before.substring(0, match.start) + mention : before + mention;
    _ctrl.value = TextEditingValue(text: newBefore + after, selection: TextSelection.collapsed(offset: newBefore.length));
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
          _AttachTile(icon: Icons.folder_outlined, title: 'Fichiers', subtitle: 'Tout type de fichier', onTap: () { Navigator.pop(context); _pickFiles(); }),
          _AttachTile(icon: Icons.photo_library_outlined, title: 'Galerie', subtitle: 'Photos et images', onTap: () { Navigator.pop(context); _pickFromGallery(); }),
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
          if (f.bytes != null) {
            final ext = f.name.toLowerCase();
            _files.insert(0, AttachedFile(
              name: f.name, bytes: f.bytes!,
              isImage: ext.endsWith('.png') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.gif') || ext.endsWith('.webp'),
            ));
          }
        }
      });
    } catch (_) {}
  }

  String _cleanImageName(dynamic img, int index) {
    final pathParts = (img.path as String).split('/');
    final pathName = pathParts.isNotEmpty ? pathParts.last : '';
    for (final candidate in [pathName, img.name as String]) {
      if (candidate.isNotEmpty && !_isPickerTempName(candidate)) return candidate;
    }
    final ext = _extractExt(img.name as String);
    final now = DateTime.now();
    return 'photo_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${index > 0 ? "_$index" : ""}$ext';
  }

  bool _isPickerTempName(String name) {
    final lower = name.toLowerCase();
    return lower.startsWith('image_picker_') || lower.startsWith('picker_') || RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}').hasMatch(lower);
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
        final bytes = await imgs[i].readAsBytes();
        if (mounted) setState(() => _files.insert(0, AttachedFile(name: _cleanImageName(imgs[i], i), bytes: bytes, isImage: true)));
      }
    } catch (_) {}
  }

  void _showImageFullscreen(Uint8List bytes, String name) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
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
          Padding(padding: const EdgeInsets.all(12), child: Text(name, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12))),
        ])),
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
      builder: (_) => SendSheet(defaultName: defaultName, preloadedRooms: _rooms, github: widget.github),
    );
    if (result == null) return;
    setState(() => _saving = true);
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      String? roomContext;
      if (result.room != null) roomContext = await widget.github.fetchContext(result.room!.id);
      final link = await widget.github.pushDirectPrompt(id, _ctrl.text, _files, room: result.room, roomContext: roomContext);
      final name = result.name.isNotEmpty ? result.name : defaultName;
      final prompt = SavedPrompt(id: id, name: name, link: link, created: DateTime.now());
      final saved = await PrefsService.addPrompt(prompt);
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, 'Erreur: ${e.toString().replaceAll("Exception: ", "")}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _ctrl.text.trim().isNotEmpty || _files.isNotEmpty;
    final mentions = _mentionSuggestions;
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(child: Column(children: [
        // Top bar
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
          child: Row(children: [
            _ToolBtn(icon: Icons.add, onTap: _showAttachMenu, tooltip: 'Joindre'),
            _ToolBtn(icon: Icons.content_paste_rounded, onTap: _paste, tooltip: 'Coller'),
            const Spacer(),
            Text(
              '${_ctrl.text.length} car.',
              style: GoogleFonts.inter(color: kMuted2, fontSize: 11.5),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.pop(context, null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.fullscreen_exit_rounded, size: 15, color: kMuted2),
                  const SizedBox(width: 5),
                  Text('Réduire', style: GoogleFonts.inter(color: kMuted2, fontSize: 12.5)),
                ]),
              ),
            ),
          ]),
        ),

        // Files
        if (_files.isNotEmpty)
          Container(
            height: 88,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
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
                        ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(f.bytes, width: 80, height: 80, fit: BoxFit.cover))
                        : Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder, width: 0.5)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.insert_drive_file_outlined, color: kAccentMid, size: 26),
                              const SizedBox(height: 4),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(f.name, style: GoogleFonts.inter(color: kMuted2, fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                            ])),
                    Positioned(
                      top: 3, right: 3,
                      child: GestureDetector(
                        onTap: () => setState(() => _files.removeAt(i)),
                        child: Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(color: kBg.withOpacity(0.88), shape: BoxShape.circle, border: Border.all(color: kBorder, width: 0.5)),
                          child: const Icon(Icons.close, size: 11, color: kText),
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
          child: _saving
              ? const AppLoadingIndicator()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: TextField(
                    controller: _ctrl,
                    maxLines: null,
                    expands: true,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.top,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.inter(color: kText, fontSize: 16, height: 1.65),
                    cursorColor: kAccent,
                    cursorWidth: 1.5,
                    decoration: InputDecoration(
                      hintText: 'Écris ton prompt ici… ou tape @ pour mentionner un fichier',
                      hintStyle: GoogleFonts.inter(color: kMuted2, fontSize: 15, height: 1.6),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
        ),

        // Mention overlay
        if (_mentionQuery != null && mentions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: const BoxDecoration(
              color: kCard,
              border: Border(top: BorderSide(color: kBorder, width: 0.5), bottom: BorderSide(color: kBorder, width: 0.5)),
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
                      ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.memory(f.bytes, width: 32, height: 32, fit: BoxFit.cover))
                      : Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.insert_drive_file_outlined, size: 16, color: kAccentMid)),
                  title: RichText(text: TextSpan(
                    style: GoogleFonts.inter(color: kText, fontSize: 13),
                    children: [
                      TextSpan(text: '@', style: GoogleFonts.inter(color: kAccentMid, fontWeight: FontWeight.w700)),
                      TextSpan(text: f.name),
                    ],
                  )),
                  onTap: () => _insertMention(f),
                );
              },
            ),
          ),

        // Bottom bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorder, width: 0.5))),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (_ctrl.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '${_ctrl.text.split(' ').where((w) => w.isNotEmpty).length} mots',
                  style: GoogleFonts.inter(color: kMuted2, fontSize: 12),
                ),
              ),
            const Spacer(),
            GestureDetector(
              onTap: hasContent && !_saving ? _send : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: hasContent && !_saving ? kAccent : kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: hasContent && !_saving ? Colors.transparent : kBorder, width: 0.5),
                ),
                child: Icon(Icons.arrow_upward_rounded, size: 20,
                    color: hasContent && !_saving ? Colors.white : kMuted2),
              ),
            ),
          ]),
        ),
      ])),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _ToolBtn({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 18, color: kMuted2),
    onPressed: onTap,
    tooltip: tooltip,
    splashRadius: 18,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    padding: const EdgeInsets.all(6),
  );
}

class _AttachTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AttachTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    leading: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: kAccentMid, size: 20),
    ),
    title: Text(title, style: GoogleFonts.inter(color: kText, fontSize: 14, fontWeight: FontWeight.w500)),
    subtitle: Text(subtitle, style: GoogleFonts.inter(color: kMuted2, fontSize: 12)),
    onTap: onTap,
  );
}
