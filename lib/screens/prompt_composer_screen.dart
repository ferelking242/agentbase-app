import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/room.dart';
import '../models/prompt.dart';
import '../services/github_service.dart';
import '../theme.dart';

class PromptComposerScreen extends StatefulWidget {
  final Room room;
  final GitHubService github;
  final int nextNumber;

  const PromptComposerScreen({
    super.key,
    required this.room,
    required this.github,
    required this.nextNumber,
  });

  @override
  State<PromptComposerScreen> createState() => _PromptComposerScreenState();
}

class _PromptComposerScreenState extends State<PromptComposerScreen> {
  final _textCtrl = TextEditingController();
  final List<PromptAttachment> _attachments = [];
  bool _sending = false;
  String? _error;

  Color get _accent {
    try {
      final h = widget.room.color.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return kAccent;
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final b64 = base64Encode(bytes);
      setState(() {
        _attachments.add(PromptAttachment(
          type: 'image',
          name: picked.name,
          path: picked.path,
          base64Data: b64,
          sizeBytes: bytes.length,
        ));
      });
    } catch (e) {
      _showError('Erreur image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final b64 = base64Encode(bytes);
      setState(() {
        _attachments.add(PromptAttachment(
          type: 'image',
          name: 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
          path: picked.path,
          base64Data: b64,
          sizeBytes: bytes.length,
        ));
      });
    } catch (e) {
      _showError('Erreur caméra: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final b64 = file.bytes != null ? base64Encode(file.bytes!) : null;
      setState(() {
        _attachments.add(PromptAttachment(
          type: _guessType(file.extension ?? ''),
          name: file.name,
          path: file.path ?? '',
          base64Data: b64,
          sizeBytes: file.size,
        ));
      });
    } catch (e) {
      _showError('Erreur fichier: $e');
    }
  }

  String _guessType(String ext) {
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext.toLowerCase())) return 'image';
    if (['mp3', 'm4a', 'wav', 'aac', 'ogg'].contains(ext.toLowerCase())) return 'audio';
    return 'file';
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
  }

  void _showError(String msg) {
    setState(() => _error = msg);
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      _showError('Le prompt ne peut pas être vide.');
      return;
    }
    if (!widget.github.hasPat) {
      _showError('Aucun PAT configuré. Retournez à l\'accueil pour le configurer.');
      return;
    }

    setState(() { _sending = true; _error = null; });

    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    final prompt = AgentPrompt(
      id: id,
      number: widget.nextNumber,
      roomId: widget.room.id,
      text: text,
      attachments: List.from(_attachments),
      createdAt: now,
      status: 'pending',
    );

    try {
      await widget.github.pushPrompt(widget.room.id, prompt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Prompt #${prompt.number} publié avec succès'),
          backgroundColor: kGreen.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.pop(context, prompt);
      }
    } catch (e) {
      if (mounted) setState(() { _sending = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg2,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: kBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 14, color: kText2),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nouveau Prompt'),
            Text(
              '${widget.room.icon} ${widget.room.name}  •  #${widget.nextNumber}',
              style: const TextStyle(
                color: kMuted2,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kBorder),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNumberBadge(accent),
                  const SizedBox(height: 20),
                  _buildTextArea(),
                  const SizedBox(height: 20),
                  _buildAttachments(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _buildError(),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildBottomBar(accent),
        ],
      ),
    );
  }

  Widget _buildNumberBadge(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 13, color: accent),
          const SizedBox(width: 6),
          Text(
            'Prompt #${widget.nextNumber}',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Instructions pour l\'agent', style: TextStyle(
          color: kMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.08,
        )),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: TextField(
            controller: _textCtrl,
            maxLines: null,
            minLines: 8,
            style: const TextStyle(color: kText, fontSize: 14, height: 1.65),
            decoration: const InputDecoration(
              hintText: 'Décrivez ce que vous voulez que l\'agent fasse…\n\nEx: Analyse le code dans le dossier src/, identifie les bugs, et crée un rapport détaillé.',
              hintStyle: TextStyle(color: kMuted, fontSize: 13.5, height: 1.65),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pièces jointes', style: TextStyle(
          color: kMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.08,
        )),
        const SizedBox(height: 8),
        Row(
          children: [
            _attachBtn(Icons.image_outlined, 'Galerie', kAccent, _pickImage),
            const SizedBox(width: 8),
            _attachBtn(Icons.camera_alt_outlined, 'Caméra', kGreen, _takePhoto),
            const SizedBox(width: 8),
            _attachBtn(Icons.attach_file, 'Fichier', kPurple, _pickFile),
          ],
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._attachments.asMap().entries.map((e) {
            final i = e.key;
            final att = e.value;
            IconData icon;
            switch (att.type) {
              case 'image':
                icon = Icons.image_outlined;
                break;
              case 'audio':
                icon = Icons.mic_outlined;
                break;
              default:
                icon = Icons.attach_file;
            }
            final color = att.type == 'image' ? kAccent : att.type == 'audio' ? kGreen : kPurple;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(att.name, style: const TextStyle(
                          color: kText2, fontSize: 12.5, fontWeight: FontWeight.w500)),
                        if (att.sizeBytes != null)
                          Text(_formatSize(att.sizeBytes!),
                            style: const TextStyle(color: kMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeAttachment(i),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: kRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.close, size: 14, color: kRed),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _attachBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: kRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!, style: const TextStyle(
              color: kRed, fontSize: 12.5, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Color accent) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: const BoxDecoration(
        color: kBg2,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_attachments.length} pièce${_attachments.length != 1 ? "s" : ""} jointe${_attachments.length != 1 ? "s" : ""}',
                  style: const TextStyle(color: kMuted, fontSize: 11.5),
                ),
                const Text('Publié sur GitHub • Lu par l\'agent', 
                  style: TextStyle(color: kMuted, fontSize: 10.5)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                color: _sending ? kSurface2 : accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 7),
                        const Text('Publier', style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
