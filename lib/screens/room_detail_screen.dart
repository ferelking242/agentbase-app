import 'dart:convert';
  import 'package:flutter/foundation.dart' show kIsWeb;
  import 'package:flutter/material.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:file_picker/file_picker.dart';
  import '../models/room.dart';
  import '../models/prompt.dart';
  import '../services/github_service.dart';
  import '../theme.dart';
  import '../widgets/prompt_tile.dart';

  class RoomDetailScreen extends StatefulWidget {
    final Room room;
    final GitHubService github;
    const RoomDetailScreen({super.key, required this.room, required this.github});
    @override
    State<RoomDetailScreen> createState() => _RoomDetailScreenState();
  }

  class _RoomDetailScreenState extends State<RoomDetailScreen> {
    List<AgentPrompt> _prompts = [];
    bool _loading = true;
    final _textCtrl = TextEditingController();
    final _focusNode = FocusNode();
    final List<_Att> _attachments = [];
    bool _sending = false;

    Color get _accent {
      try { return Color(int.parse('FF${widget.room.color.replaceAll("#","")}', radix: 16)); }
      catch (_) { return kAccent; }
    }

    @override
    void initState() { super.initState(); _load(); _focusNode.addListener(() => setState(() {})); }

    @override
    void dispose() { _textCtrl.dispose(); _focusNode.dispose(); super.dispose(); }

    Future<void> _load() async {
      setState(() => _loading = true);
      try {
        final p = await widget.github.fetchRoomPrompts(widget.room.id);
        if (mounted) setState(() { _prompts = p; _loading = false; });
      } catch (_) { if (mounted) setState(() => _loading = false); }
    }

    Future<void> _pickImage() async {
      try {
        final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        setState(() => _attachments.add(_Att('image', picked.name, base64Encode(bytes), bytes)));
      } catch (_) {}
    }

    Future<void> _pickCamera() async {
      try {
        final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        setState(() => _attachments.add(_Att('image', 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg', base64Encode(bytes), bytes)));
      } catch (_) {}
    }

    Future<void> _pickFile() async {
      try {
        final result = await FilePicker.platform.pickFiles(withData: true);
        if (result == null || result.files.isEmpty) return;
        final f = result.files.first;
        final ext = f.extension ?? '';
        String type = 'file';
        if (['jpg','jpeg','png','gif','webp'].contains(ext.toLowerCase())) type = 'image';
        else if (['mp3','m4a','wav','ogg','aac'].contains(ext.toLowerCase())) type = 'audio';
        if (f.bytes != null) {
          setState(() => _attachments.add(_Att(type, f.name, base64Encode(f.bytes!), f.bytes!)));
        }
      } catch (_) {}
    }

    Future<void> _send() async {
      final txt = _textCtrl.text.trim();
      if (txt.isEmpty && _attachments.isEmpty) return;
      if (!widget.github.hasPat) {
        _snack('Token GitHub requis — configure dans Paramètres', kRed);
        return;
      }
      setState(() => _sending = true);
      try {
        final id = '${DateTime.now().millisecondsSinceEpoch}';
        final nextNum = _prompts.isEmpty ? 1 : (_prompts.map((p) => p.number).reduce((a,b) => a>b?a:b) + 1);
        final prompt = AgentPrompt(
          id: id, number: nextNum, roomId: widget.room.id,
          text: txt, status: 'pending', createdAt: DateTime.now(),
          attachments: _attachments.map((a) => PromptAttachment(
            type: a.type, name: a.name, path: '', base64Data: a.b64, sizeBytes: a.bytes.length,
          )).toList(),
        );
        await widget.github.pushPrompt(widget.room.id, prompt);
        if (mounted) {
          setState(() { _prompts.insert(0, prompt); _textCtrl.clear(); _attachments.clear(); _sending = false; });
          _snack('Prompt #$nextNum envoyé ✓', kGreen);
        }
      } catch (e) {
        if (mounted) { setState(() => _sending = false); _snack('Erreur: $e', kRed); }
      }
    }

    void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color.withOpacity(0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));

    @override
    Widget build(BuildContext context) {
      final accent = _accent;
      return Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg, elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(9), border: Border.all(color: kBorder)),
              child: const Icon(Icons.arrow_back_ios_new, size: 14, color: kText2),
            ),
          ),
          title: Row(children: [
            Text(widget.room.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.room.name,
              style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3),
              overflow: TextOverflow.ellipsis)),
          ]),
          actions: [
            GestureDetector(
              onTap: _load,
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                width: 34, height: 34,
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(9), border: Border.all(color: kBorder)),
                child: const Icon(Icons.refresh, size: 16, color: kMuted2),
              ),
            ),
          ],
          bottom: PreferredSize(preferredSize: const Size.fromHeight(0.5), child: Container(height: 0.5, color: kBorder)),
        ),
        body: Column(
          children: [
            Expanded(child: _list()),
            _composer(accent),
          ],
        ),
      );
    }

    Widget _list() {
      if (_loading) return const Center(child: CircularProgressIndicator(color: kAccent));
      if (_prompts.isEmpty) return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 56, height: 56,
            decoration: BoxDecoration(color: kAccent.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_outlined, size: 24, color: kAccent2)),
          const SizedBox(height: 14),
          const Text('Aucun prompt', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Compose le premier prompt ci-dessous.',
            style: TextStyle(color: kMuted2, fontSize: 13), textAlign: TextAlign.center),
        ],
      ));
      return RefreshIndicator(
        color: kAccent, backgroundColor: kSurface, onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          itemCount: _prompts.length,
          itemBuilder: (_, i) => PromptTile(prompt: _prompts[i]),
        ),
      );
    }

    Widget _composer(Color accent) {
      return Container(
        decoration: const BoxDecoration(
          color: kBg, border: Border(top: BorderSide(color: kBorder, width: 0.5))),
        padding: EdgeInsets.only(
          left: 12, right: 12, top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10
            : (MediaQuery.of(context).padding.bottom + 10)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachments.isNotEmpty) _attRow(),
            Container(
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _focusNode.hasFocus ? accent.withOpacity(0.6) : kBorder)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: _textCtrl, focusNode: _focusNode,
                  onChanged: (_) => setState(() {}),
                  maxLines: null, minLines: 1,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(color: kText, fontSize: 14, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'Écris un prompt pour l'agent…',
                    hintStyle: TextStyle(color: kMuted, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(14, 12, 14, 4), isDense: true),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                  child: Row(children: [
                    _tool(Icons.image_outlined, _pickImage),
                    if (!kIsWeb) _tool(Icons.camera_alt_outlined, _pickCamera),
                    _tool(Icons.attach_file, _pickFile),
                    const Spacer(),
                    GestureDetector(
                      onTap: (_textCtrl.text.trim().isNotEmpty || _attachments.isNotEmpty) && !_sending ? _send : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: (_textCtrl.text.trim().isNotEmpty || _attachments.isNotEmpty) && !_sending
                            ? accent : kSurface2,
                          borderRadius: BorderRadius.circular(10)),
                        child: _sending
                          ? const Center(child: SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5)))
                          : const Icon(Icons.arrow_upward_rounded, size: 17, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      );
    }

    Widget _attRow() => Container(
      margin: const EdgeInsets.only(bottom: 8), height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final att = _attachments[i];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(9), border: Border.all(color: kBorder)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (att.type == 'image')
                    ClipRRect(borderRadius: BorderRadius.circular(5),
                      child: Image.memory(att.bytes, width: 28, height: 28, fit: BoxFit.cover))
                  else Icon(att.type == 'audio' ? Icons.audiotrack_outlined : Icons.insert_drive_file_outlined, size: 18, color: kMuted2),
                  const SizedBox(width: 6),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 90),
                    child: Text(att.name, style: const TextStyle(color: kText2, fontSize: 11), overflow: TextOverflow.ellipsis)),
                ]),
              ),
              Positioned(top: -6, right: -6,
                child: GestureDetector(
                  onTap: () => setState(() => _attachments.removeAt(i)),
                  child: Container(width: 18, height: 18,
                    decoration: BoxDecoration(color: kSurface3, shape: BoxShape.circle, border: Border.all(color: kBorder)),
                    child: const Icon(Icons.close, size: 10, color: kMuted2)),
                )),
            ],
          );
        },
      ),
    );

    Widget _tool(IconData icon, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30, margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 17, color: kMuted)),
    );
  }

  class _Att {
    final String type, name, b64;
    final List<int> bytes;
    _Att(this.type, this.name, this.b64, dynamic raw)
      : bytes = raw is List<int> ? raw : List<int>.from(raw as List);
  }