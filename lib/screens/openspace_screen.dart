import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/github_service.dart';
import '../theme.dart';
import '../widgets/app_components.dart';

class OpenspaceImage {
  final String name;
  final String mention;
  final String rawUrl;
  final String sha;

  OpenspaceImage({
    required this.name,
    required this.mention,
    required this.rawUrl,
    required this.sha,
  });
}

class OpenspaceScreen extends StatefulWidget {
  final GitHubService github;

  const OpenspaceScreen({super.key, required this.github});

  @override
  State<OpenspaceScreen> createState() => _OpenspaceScreenState();
}

class _OpenspaceScreenState extends State<OpenspaceScreen> {
  List<OpenspaceImage> _images = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await widget.github.fetchOpenspaceImages();
      final imgs = raw.map((m) {
        final map = m as Map<String, dynamic>;
        return OpenspaceImage(
          name: map['name'] as String,
          mention: map['mention'] as String,
          rawUrl: map['rawUrl'] as String,
          sha: map['sha'] as String,
        );
      }).toList();
      if (mounted) setState(() { _images = imgs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _upload() async {
    if (!widget.github.hasPat) {
      showAppSnack(context, 'Configure ton token dans Paramètres', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const AppDragHandle(),
        _AttachOption(icon: Icons.photo_library_outlined, title: 'Galerie', subtitle: 'Photos de la galerie', onTap: () { Navigator.pop(context); _pickGallery(); }),
        _AttachOption(icon: Icons.folder_outlined, title: 'Fichiers', subtitle: 'Tout fichier image', onTap: () { Navigator.pop(context); _pickFile(); }),
        const SizedBox(height: 8),
      ])),
    );
  }

  Future<void> _pickGallery() async {
    try {
      final imgs = await ImagePicker().pickMultiImage(imageQuality: 90);
      if (imgs.isEmpty) return;
      for (final img in imgs) {
        final bytes = await img.readAsBytes();
        await _doUpload(img.name, bytes);
      }
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true, withData: true,
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
      );
      if (res == null) return;
      for (final f in res.files) {
        if (f.bytes == null) continue;
        await _doUpload(f.name, f.bytes!);
      }
    } catch (_) {}
  }

  Future<void> _doUpload(String originalName, Uint8List bytes) async {
    setState(() => _uploading = true);
    try {
      final existingRaw = _images.map((i) => {'name': i.name, 'mention': i.mention, 'rawUrl': i.rawUrl, 'sha': i.sha}).toList();
      final map = await widget.github.uploadOpenspaceImage(originalName, bytes, existingRaw);
      final image = OpenspaceImage(
        name: map['name'] as String,
        mention: map['mention'] as String,
        rawUrl: map['rawUrl'] as String,
        sha: map['sha'] as String,
      );
      if (mounted) {
        setState(() { _images.insert(0, image); _uploading = false; });
        showAppSnack(context, '${image.mention} ajouté à l\'OpenSpace !');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        showAppSnack(context, e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    }
  }

  Future<void> _delete(OpenspaceImage img) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kBorder, width: 0.5)),
        title: Text('Supprimer ?', style: GoogleFonts.inter(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text('${img.name} sera supprimé du dépôt GitHub.', style: GoogleFonts.inter(color: kMuted2, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: Text('Annuler', style: GoogleFonts.inter(color: kMuted))),
          AppButton(label: 'Supprimer', onTap: () => Navigator.pop(_, true), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.github.deleteOpenspaceImage(img.name, img.sha);
      if (mounted) {
        setState(() => _images.removeWhere((i) => i.name == img.name));
        showAppSnack(context, '${img.mention} supprimé');
      }
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _copyMention(String mention) {
    Clipboard.setData(ClipboardData(text: mention));
    showAppSnack(context, '$mention copié !');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: SafeArea(bottom: false, child: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(width: 34, height: 34,
              decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
              child: const Icon(Icons.arrow_back_ios_new, size: 13, color: kMuted)),
          ),
          const SizedBox(width: 12),
          Container(width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10b981), Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.cloud_outlined, size: 15, color: Colors.white)),
          const SizedBox(width: 8),
          Text('OpenSpace', style: GoogleFonts.inter(color: kText, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
          if (!_loading && _images.isNotEmpty) ...[
            const SizedBox(width: 8),
            AppBadge('${_images.length}'),
          ],
          const Spacer(),
          GestureDetector(
            onTap: _load,
            child: Container(width: 34, height: 34,
              decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
              child: const Icon(Icons.sync_rounded, size: 17, color: kMuted)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _uploading ? null : _upload,
            child: AnimatedOpacity(
              opacity: _uploading ? 0.6 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(width: 34, height: 34,
                decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(8)),
                child: _uploading
                  ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.add, size: 18, color: Colors.white)),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kGreenSub.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kGreen.withOpacity(0.2), width: 0.5),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 15, color: kGreen),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Photos partagées — mentionne-les dans tes prompts avec @nom',
              style: GoogleFonts.inter(color: kGreen, fontSize: 12, height: 1.4),
            )),
          ]),
        ),
      ),
      const SizedBox(height: 4),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2))
        : _error != null
          ? _buildError()
          : _images.isEmpty
            ? _buildEmpty()
            : _buildGrid()),
    ])),
  );

  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off_outlined, size: 40, color: kRed),
      const SizedBox(height: 12),
      Text(_error!, style: GoogleFonts.inter(color: kMuted2, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      AppButton(label: 'Réessayer', icon: Icons.refresh, onTap: _load, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
    ]),
  ));

  Widget _buildEmpty() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
        child: const Icon(Icons.add_photo_alternate_outlined, size: 34, color: kMuted2)),
      const SizedBox(height: 16),
      Text('OpenSpace vide', style: GoogleFonts.inter(color: kText, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('Ajoute des photos partagées que toi et d\'autres peuvent mentionner avec @nom dans leurs prompts.', style: GoogleFonts.inter(color: kMuted2, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      AppButton(label: 'Ajouter une photo', icon: Icons.add, onTap: _upload, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11)),
    ]),
  ));

  Widget _buildGrid() => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85),
    itemCount: _images.length,
    itemBuilder: (_, i) => _ImageCard(
      image: _images[i],
      onCopyMention: () => _copyMention(_images[i].mention),
      onDelete: () => _delete(_images[i]),
    ),
  );
}

class _ImageCard extends StatelessWidget {
  final OpenspaceImage image;
  final VoidCallback onCopyMention;
  final VoidCallback onDelete;

  const _ImageCard({required this.image, required this.onCopyMention, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: GestureDetector(
          onTap: () => _showFullscreen(context),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: Image.network(
              image.rawUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: kCard2,
                child: const Center(child: Icon(Icons.broken_image_outlined, color: kMuted2, size: 30)),
              ),
              loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(color: kCard2, child: const Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2))),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(image.name, style: GoogleFonts.inter(color: kText, fontSize: 11.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: onCopyMention,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.alternate_email, size: 11, color: kAccentMid),
                    const SizedBox(width: 3),
                    Flexible(child: Text(image.mention.replaceFirst('@', ''),
                      style: GoogleFonts.robotoMono(color: kAccentMid, fontSize: 10.5, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: Container(width: 26, height: 26,
                decoration: BoxDecoration(color: kRedSub.withOpacity(0.4), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.delete_outline, size: 14, color: kRed)),
            ),
          ]),
        ]),
      ),
    ]),
  );

  void _showFullscreen(BuildContext context) {
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
          Expanded(child: InteractiveViewer(minScale: 0.5, maxScale: 5,
            child: Center(child: Image.network(image.rawUrl, fit: BoxFit.contain)))),
          Padding(padding: const EdgeInsets.all(12), child: Text(image.name,
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center)),
        ])),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AttachOption({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 40, height: 40,
      decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 20, color: kAccentMid)),
    title: Text(title, style: GoogleFonts.inter(color: kText, fontSize: 14, fontWeight: FontWeight.w500)),
    subtitle: Text(subtitle, style: GoogleFonts.inter(color: kMuted2, fontSize: 12)),
    onTap: onTap,
  );
}
