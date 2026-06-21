import 'dart:convert';
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
    final List<_Attachment> _attachments = [];
    bool _sending = false;
    final _scrollCtrl = ScrollController();

    Color get _accent {
      try {
        final h = widget.room.color.replaceAll('#', '');
        return Color(int.parse('FF$h', radix: 16));
      } catch (_) { return kAccent; }
    }

    @override
    void initState() {
      super.initState();
      _loadPrompts();
    }

    @override
    void dispose() {
      _textCtrl.dispose();
      _focusNode.dispose();
      _scrollCtrl.dispose();
      super.dispose();
    }

    Future<void> _loadPrompts() async {
      setState(() => _loading = true);
      try {
        final prompts = await widget.github.fetchRoomPrompts(widget.room.id);
        if (mounted) setState(() { _prompts = prompts; _loading = false; });
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    }

    Future<void> _pickImage() async {
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        setState(() => _attachments.add(_Attachment('image', picked.name, base64Encode(bytes), bytes)));
      } catch (_) {}
    }

    Future<void> _pickCamera() async {
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        setState(() => _attachments.add(_Attachment('image', 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg', base64Encode(bytes), bytes)));
      } catch (_) {}
    }

    Future<void> _pickFile() async {
      try {
        final result = await FilePicker.platform.pickFiles(withData: true);
        if (result == null || result.files.isEmpty) return;
        final f = result.files.first;
        final type = _guessType(f.extension ?? '');
        setState(() => _attachments.add(_Attachment(type, f.name, f.bytes != null ? base64Encode(f.bytes!) : null, f.bytes)));
      } catch (_) {}
    }

    String _guessType(String ext) {
      if (['jpg','jpeg','png','gif','webp','heic'].contains(ext.toLowerCase())) return 'image';
      if (['mp3','m4a','wav','ogg','aac'].contains(ext.toLowerCase())) return 'audio';
      return 'file';
    }

    Future<void> _send() async {
      final txt = _textCtrl.text.trim();
      if (txt.isEmpty && _attachments.isEmpty) return;
      if (!widget.github.hasPat) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Token GitHub requis — configure dans Paramètres'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      setState(() => _sending = true);
      try {
        final nextNum = _prompts.isEmpty ? 1 : (_prompts.map((p) => p.number).reduce((a,b) => a>b?a:b) + 1);
        final attachList = _attachments.map((a) => PromptAttachment(
          type: a.type, name: a.name, path: '',
          base64Data: a.b64, sizeBytes: a.bytes?.length ?? 0,
        )).toList();
        final prompt = AgentPrompt(
          number: nextNum,
          text: txt,
          status: 'pending',
          createdAt: DateTime.now(),
          attachments: attachList,
        );
        await widget.github.pushPrompt(widget.room.id, prompt);
        if (mounted) {
          setState(() {
            _prompts.insert(0, prompt);
            _textCtrl.clear();
            _attachments.clear();
            _sending = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Prompt #$nextNum envoyé ✓'),
            backgroundColor: kGreen.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _sending = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: kRed.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }

    @override
    Widget build(BuildContext context) {
      final accent = _accent;
      return Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kSurface, borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 14, color: kText2),
            ),
          ),
          title: Row(
            children: [
              Text(widget.room.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.room.name,
                style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                overflow: TextOverflow.ellipsis)),
            ],
          ),
          actions: [
            GestureDetector(
              onTap: _loadPrompts,
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: kSurface, borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: kBorder),
                ),
                child: const Icon(Icons.refresh, size: 16, color: kMuted2),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: kBorder),
          ),
        ),
        body: Column(
          children: [
            Expanded(child: _buildList()),
            _buildComposer(accent),
          ],
        ),
      );
    }

    Widget _buildList() {
      if (_loading) return const Center(child: CircularProgressIndicator(color: kAccent));
      if (_prompts.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_outlined, size: 24, color: kAccent2),
              ),
              const SizedBox(height: 14),
              const Text('Aucun prompt', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Compose le premier prompt ci-dessous.',
                style: TextStyle(color: kMuted2, fontSize: 13), textAlign: TextAlign.center),
            ],
          ),
        );
      }
      return RefreshIndicator(
        color: kAccent,
        backgroundColor: kSurface,
        onRefresh: _loadPrompts,
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          itemCount: _prompts.length,
          itemBuilder: (_, i) => PromptTile(prompt: _prompts[i]),
        ),
      );
    }

    Widget _buildComposer(Color accent) {
      return Container(
        decoration: const BoxDecoration(
          color: kBg,
          border: Border(top: BorderSide(color: kBorder, width: 0.5)),
        ),
        padding: EdgeInsets.only(
          left: 12, right: 12, top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : MediaQuery.of(context).padding.bottom + 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachments.isNotEmpty) _buildAttachmentRow(),
            Container(
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _focusNode.hasFocus ? accent.withOpacity(0.6) : kBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _textCtrl,
                    focusNode: _focusNode,
                    onChanged: (_) => setState(() {}),
                    maxLines: null,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(color: kText, fontSize: 14, height: 1.5),
                    decoration: const InputDecoration(
                      hintText: 'Écris un prompt pour l'agent…',
                      hintStyle: TextStyle(color: kMuted, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(14, 12, 14, 4),
                      isDense: true,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                    child: Row(
                      children: [
                        _toolBtn(Icons.image_outlined, _pickImage),
                        _toolBtn(Icons.camera_alt_outlined, _pickCamera),
                        _toolBtn(Icons.attach_file, _pickFile),
                        const Spacer(),
                        GestureDetector(
                          onTap: (_textCtrl.text.trim().isNotEmpty || _attachments.isNotEmpty) && !_sending
                              ? _send : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: (_textCtrl.text.trim().isNotEmpty || _attachments.isNotEmpty) && !_sending
                                  ? accent : kSurface2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _sending
                              ? const Center(child: SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5)))
                              : const Icon(Icons.arrow_upward_rounded, size: 17, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildAttachmentRow() {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 52,
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
                  decoration: BoxDecoration(
                    color: kSurface2,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (att.type == 'image' && att.bytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.memory(att.bytes!, width: 28, height: 28, fit: BoxFit.cover),
                        )
                      else
                        Icon(att.type == 'audio' ? Icons.audiotrack_outlined : Icons.insert_drive_file_outlined,
                          size: 18, color: kMuted2),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 90),
                        child: Text(att.name,
                          style: const TextStyle(color: kText2, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -6, right: -6,
                  child: GestureDetector(
                    onTap: () => setState(() => _attachments.removeAt(i)),
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: kSurface3, shape: BoxShape.circle,
                        border: Border.all(color: kBorder),
                      ),
                      child: const Icon(Icons.close, size: 10, color: kMuted2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    Widget _toolBtn(IconData icon, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 17, color: kMuted),
        ),
      );
    }
  }

  class _Attachment {
    final String type;
    final String name;
    final String? b64;
    final List<int>? bytes;
    _Attachment(this.type, this.name, this.b64, dynamic rawBytes)
      : bytes = rawBytes is List<int> ? rawBytes : (rawBytes != null ? List<int>.from(rawBytes as List) : null);
  }