import 'dart:convert';
  import 'dart:typed_data';
  import 'package:flutter/foundation.dart' show kIsWeb;
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:file_picker/file_picker.dart';
  import '../models/room.dart';
  import '../models/prompt.dart';
  import '../services/github_service.dart';
  import '../theme.dart';

  // Used by HomeScreen (wide) inline and pushed (mobile)
  class RoomDetailView extends StatefulWidget {
    final Room room;
    final GitHubService github;
    const RoomDetailView({super.key, required this.room, required this.github});
    @override
    State<RoomDetailView> createState() => _RoomDetailViewState();
  }

  class RoomDetailScreen extends StatelessWidget {
    final Room room;
    final GitHubService github;
    const RoomDetailScreen({super.key, required this.room, required this.github});
    @override
    Widget build(BuildContext context) => Scaffold(
      backgroundColor: kBg,
      body: RoomDetailView(room: room, github: github),
    );
  }

  class _RoomDetailViewState extends State<RoomDetailView> {
    String? _context;
    String? _rules;
    List<TimelineEntry> _timeline = [];
    bool _loading = true;
    bool _ctxExpanded = true;
    bool _rulesExpanded = true;
    final _textCtrl = TextEditingController();
    final _focusNode = FocusNode();
    final List<_Att> _attachments = [];
    bool _sending = false;

    Color get _accent => widget.room.accentColor;

    @override
    void initState() { super.initState(); _load(); _focusNode.addListener(() => setState(() {})); }
    @override
    void dispose() { _textCtrl.dispose(); _focusNode.dispose(); super.dispose(); }
    @override
    void didUpdateWidget(RoomDetailView old) {
      super.didUpdateWidget(old);
      if (old.room.id != widget.room.id) { _context = null; _rules = null; _timeline = []; _load(); }
    }

    Future<void> _load() async {
      setState(() => _loading = true);
      final rid = widget.room.id;
      final results = await Future.wait([
        widget.github.fetchContext(rid),
        widget.github.fetchRules(rid),
        widget.github.fetchTimeline(rid),
      ]);
      if (!mounted) return;
      setState(() {
        _context = results[0] as String?;
        _rules = results[1] as String?;
        _timeline = results[2] as List<TimelineEntry>;
        _loading = false;
      });
    }

    Future<void> _pickImage() async {
      try {
        final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (x == null) return;
        final b = await x.readAsBytes();
        setState(() => _attachments.add(_Att('image', x.name, base64Encode(b), b)));
      } catch (_) {}
    }

    Future<void> _pickCamera() async {
      try {
        final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
        if (x == null) return;
        final b = await x.readAsBytes();
        setState(() => _attachments.add(_Att('image', 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg', base64Encode(b), b)));
      } catch (_) {}
    }

    Future<void> _pickFile() async {
      try {
        final r = await FilePicker.platform.pickFiles(withData: true);
        if (r == null || r.files.isEmpty) return;
        final f = r.files.first;
        if (f.bytes == null) return;
        final ext = (f.extension ?? '').toLowerCase();
        String type = 'file';
        if (['jpg','jpeg','png','gif','webp'].contains(ext)) type = 'image';
        else if (['mp3','m4a','wav'].contains(ext)) type = 'audio';
        setState(() => _attachments.add(_Att(type, f.name, base64Encode(f.bytes!), f.bytes!)));
      } catch (_) {}
    }

    Future<void> _send() async {
      final txt = _textCtrl.text.trim();
      if (txt.isEmpty && _attachments.isEmpty) return;
      if (!widget.github.hasPat) { _snack('Token GitHub requis — voir Parametres', kYellow); return; }
      setState(() => _sending = true);
      try {
        final id = '${DateTime.now().millisecondsSinceEpoch}';
        final maxN = _timeline.whereType<PromptEntry>().map((e) => e.p.number).fold(0, (a, b) => a > b ? a : b);
        final prompt = AgentPrompt(
          id: id, number: maxN + 1, roomId: widget.room.id,
          text: txt, status: 'pending', createdAt: DateTime.now(),
          attachments: _attachments.map((a) => PromptAttachment(
            type: a.type, name: a.name, path: '', base64Data: a.b64, sizeBytes: a.bytes.length)).toList(),
        );
        await widget.github.pushPrompt(widget.room.id, prompt);
        if (mounted) {
          setState(() {
            _timeline.insert(0, PromptEntry(prompt));
            _textCtrl.clear(); _attachments.clear(); _sending = false;
          });
          _snack('Prompt #${maxN + 1} envoye', kGreen);
        }
      } catch (e) {
        if (mounted) { setState(() => _sending = false); _snack('Erreur: $e', kRed); }
      }
    }

    void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color.withOpacity(0.9), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 2),
    ));

    @override
    Widget build(BuildContext context) {
      final accent = _accent;
      final isNarrow = MediaQuery.of(context).size.width < 720;
      return Column(children: [
        // ── Header bar ──
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
          child: Row(children: [
            if (isNarrow) GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(margin: const EdgeInsets.only(right: 10), width: 28, height: 28,
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(7), border: Border.all(color: kBorder)),
                child: const Icon(Icons.arrow_back_ios_new, size: 12, color: kMuted2)),
            ),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Icon(widget.room.iconData, size: 16, color: accent),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.room.name,
              style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.2),
              overflow: TextOverflow.ellipsis)),
            GestureDetector(onTap: _load,
              child: Container(width: 28, height: 28,
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(7), border: Border.all(color: kBorder)),
                child: const Icon(Icons.refresh, size: 14, color: kMuted2))),
          ]),
        ),
        // ── Body ──
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : CustomScrollView(slivers: [
              // Description
              if (widget.room.description.isNotEmpty)
                SliverToBoxAdapter(child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: accent.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: accent.withOpacity(0.15))),
                  child: Row(children: [
                    Icon(widget.room.iconData, size: 14, color: accent.withOpacity(0.7)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.room.description, style: const TextStyle(color: kText2, fontSize: 12.5, height: 1.5))),
                  ]),
                )),
              // Contexte section
              if (_context != null) SliverToBoxAdapter(child: _Section(
                label: 'CONTEXTE', icon: Icons.info_outline, expanded: _ctxExpanded,
                onToggle: () => setState(() => _ctxExpanded = !_ctxExpanded),
                child: _MarkdownCard(_context!),
              )),
              // Regles section
              if (_rules != null) SliverToBoxAdapter(child: _Section(
                label: 'REGLES', icon: Icons.rule_outlined, expanded: _rulesExpanded,
                onToggle: () => setState(() => _rulesExpanded = !_rulesExpanded),
                child: _MarkdownCard(_rules!),
              )),
              // Timeline section label
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(children: [
                  const Text('HISTORIQUE', style: TextStyle(color: kMuted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(4)),
                    child: Text('${_timeline.length}', style: const TextStyle(color: kMuted2, fontSize: 10))),
                ]),
              )),
              // Timeline entries
              if (_timeline.isEmpty)
                const SliverToBoxAdapter(child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Aucune activite dans cet espace.', style: TextStyle(color: kMuted, fontSize: 13)),
                ))
              else
                SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final entry = _timeline[i];
                    if (entry is PromptEntry) return _PromptTile(prompt: entry.p, onCopy: _onCopy, accent: accent);
                    if (entry is AgentEntryItem) return _AgentTile(entry: entry.e);
                    return const SizedBox.shrink();
                  },
                  childCount: _timeline.length,
                )),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ])),
        // ── Composer ──
        _Composer(
          textCtrl: _textCtrl, focusNode: _focusNode, attachments: _attachments,
          sending: _sending, accent: accent,
          onSend: _send, onImage: _pickImage,
          onCamera: kIsWeb ? null : _pickCamera,
          onFile: _pickFile,
          onRemoveAtt: (i) => setState(() => _attachments.removeAt(i)),
          onChanged: () => setState(() {}),
        ),
      ]);
    }

    void _onCopy(String text) {
      Clipboard.setData(ClipboardData(text: text));
      _snack('Copie dans le presse-papier', kAccent);
    }
  }

  // ─── Section widget ───────────────────────────────────────────
  class _Section extends StatelessWidget {
    final String label;
    final IconData icon;
    final bool expanded;
    final VoidCallback onToggle;
    final Widget child;
    const _Section({required this.label, required this.icon, required this.expanded, required this.onToggle, required this.child});
    @override
    Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(children: [
              Icon(icon, size: 12, color: kMuted),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: kMuted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const Spacer(),
              Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 14, color: kMuted),
            ]),
          )),
        if (expanded) child,
      ],
    );
  }

  // ─── Markdown card ────────────────────────────────────────────
  class _MarkdownCard extends StatelessWidget {
    final String content;
    const _MarkdownCard(this.content);
    @override
    Widget build(BuildContext context) {
      final lines = content.split('\n');
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.where((l) => l.trim().isNotEmpty).map((line) {
            if (line.startsWith('## ')) return _mkLine(line.substring(3), 14, FontWeight.w700, kText);
            if (line.startsWith('# '))  return _mkLine(line.substring(2), 15, FontWeight.w700, kText);
            if (line.startsWith('### ')) return _mkLine(line.substring(4), 13, FontWeight.w600, kText2);
            if (line.startsWith('- ') || line.startsWith('* ')) return _mkBullet(line.substring(2));
            return Padding(padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: const TextStyle(color: kText2, fontSize: 13, height: 1.6)));
          }).toList(),
        ),
      );
    }
    Widget _mkLine(String t, double s, FontWeight w, Color c) => Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(t, style: TextStyle(color: c, fontSize: s, fontWeight: w, letterSpacing: -0.2)));
    Widget _mkBullet(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 4, color: kMuted2)),
        const SizedBox(width: 8),
        Expanded(child: Text(t, style: const TextStyle(color: kText2, fontSize: 13, height: 1.6))),
      ]));
  }

  // ─── Prompt tile ──────────────────────────────────────────────
  class _PromptTile extends StatefulWidget {
    final AgentPrompt prompt;
    final ValueChanged<String> onCopy;
    final Color accent;
    const _PromptTile({required this.prompt, required this.onCopy, required this.accent});
    @override
    State<_PromptTile> createState() => _PromptTileState();
  }
  class _PromptTileState extends State<_PromptTile> {
    bool _hover = false, _expanded = false;

    Color _statusColor(String s) {
      switch (s.toLowerCase()) {
        case 'done': case 'executed': return kGreen;
        case 'executing': case 'running': return kYellow;
        case 'read': return kBlue;
        default: return kMuted;
      }
    }
    IconData _statusIcon(String s) {
      switch (s.toLowerCase()) {
        case 'done': case 'executed': return Icons.check_circle_outline;
        case 'executing': case 'running': return Icons.sync;
        case 'read': return Icons.visibility_outlined;
        default: return Icons.radio_button_unchecked;
      }
    }
    String _statusLabel(String s) {
      switch (s.toLowerCase()) {
        case 'done': case 'executed': return 'Execute';
        case 'executing': case 'running': return 'En cours';
        case 'read': return 'Lu';
        default: return 'En attente';
      }
    }
    String _fmt(DateTime? d) {
      if (d == null) return '';
      return '${d.day.toString().padLeft(2,"0")}/${d.month.toString().padLeft(2,"0")} ${d.hour.toString().padLeft(2,"0")}:${d.minute.toString().padLeft(2,"0")}';
    }

    @override
    Widget build(BuildContext context) {
      final p = widget.prompt;
      final sc = _statusColor(p.status);
      final preview = p.text.isNotEmpty ? (p.text.length > 120 ? '${p.text.substring(0,120)}...' : p.text) : '';
      return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit:  (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            decoration: BoxDecoration(
              color: _hover ? kSurface2 : kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _hover ? kBorder2 : kBorder)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // Prompt number badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: widget.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                    child: Text('#${p.number}',
                      style: TextStyle(color: widget.accent, fontSize: 10.5, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_right_outlined, size: 13, color: kMuted),
                  if (_fmt(p.createdAt).isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(_fmt(p.createdAt), style: const TextStyle(color: kMuted, fontSize: 10.5)),
                  ],
                  const Spacer(),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_statusIcon(p.status), size: 10, color: sc),
                      const SizedBox(width: 4),
                      Text(_statusLabel(p.status), style: TextStyle(color: sc, fontSize: 10, fontWeight: FontWeight.w600)),
                    ])),
                  const SizedBox(width: 6),
                  // Copy button
                  if (p.text.isNotEmpty) GestureDetector(
                    onTap: () => widget.onCopy(p.text),
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(color: kSurface3, borderRadius: BorderRadius.circular(6), border: Border.all(color: kBorder)),
                      child: const Icon(Icons.copy_outlined, size: 12, color: kMuted2))),
                ]),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(preview, style: const TextStyle(color: kText2, fontSize: 13, height: 1.5)),
                ],
                // Expanded content
                if (_expanded && p.text.length > 120) ...[
                  const SizedBox(height: 4),
                  Text(p.text.substring(120), style: const TextStyle(color: kText2, fontSize: 13, height: 1.5)),
                ],
                // Attachments
                if (p.attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: p.attachments.map((a) {
                    final isImg = a.type == 'image' && a.base64Data != null && a.base64Data!.isNotEmpty;
                    if (isImg && _expanded) {
                      Uint8List? bytes;
                      try { bytes = base64Decode(a.base64Data!); } catch (_) {}
                      if (bytes != null) return ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.memory(bytes, height: 120, fit: BoxFit.cover));
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: kSurface3, borderRadius: BorderRadius.circular(5), border: Border.all(color: kBorder)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(a.type == 'image' ? Icons.image_outlined : a.type == 'audio' ? Icons.audiotrack_outlined : Icons.attach_file, size: 11, color: kMuted2),
                        const SizedBox(width: 5),
                        Text(a.name.length > 20 ? '${a.name.substring(0,20)}...' : a.name, style: const TextStyle(color: kMuted2, fontSize: 10.5)),
                      ]));
                  }).toList()),
                ],
              ]),
            ),
          ),
        ),
      );
    }
  }

  // ─── Agent tile ───────────────────────────────────────────────
  class _AgentTile extends StatefulWidget {
    final AgentEntry entry;
    const _AgentTile({required this.entry});
    @override
    State<_AgentTile> createState() => _AgentTileState();
  }
  class _AgentTileState extends State<_AgentTile> {
    bool _expanded = false;
    String _fmt(DateTime? d) {
      if (d == null) return '';
      return '${d.day.toString().padLeft(2,"0")}/${d.month.toString().padLeft(2,"0")} ${d.hour.toString().padLeft(2,"0")}:${d.minute.toString().padLeft(2,"0")}';
    }
    @override
    Widget build(BuildContext context) {
      final e = widget.entry;
      final lines = e.content.split('\n');
      final preview = lines.where((l) => l.trim().isNotEmpty && !l.startsWith('#')).take(3).join(' ');
      final truncPrev = preview.length > 160 ? '${preview.substring(0,160)}...' : preview;
      return GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Agent header
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(5)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.smart_toy_outlined, size: 11, color: kAccentL),
                    const SizedBox(width: 5),
                    Text(e.agentName, style: const TextStyle(color: kAccentL, fontSize: 10.5, fontWeight: FontWeight.w600)),
                  ])),
                const SizedBox(width: 8),
                if (_fmt(e.createdAt).isNotEmpty)
                  Text(_fmt(e.createdAt), style: const TextStyle(color: kMuted, fontSize: 10.5)),
                const Spacer(),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 14, color: kMuted),
              ]),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: _expanded
                ? _MarkdownCard(e.content)
                : Text(truncPrev, style: const TextStyle(color: kText2, fontSize: 13, height: 1.5)),
            ),
          ]),
        ),
      );
    }
  }

  // ─── Composer ─────────────────────────────────────────────────
  class _Composer extends StatelessWidget {
    final TextEditingController textCtrl;
    final FocusNode focusNode;
    final List<_Att> attachments;
    final bool sending;
    final Color accent;
    final VoidCallback onSend, onImage, onFile, onChanged;
    final VoidCallback? onCamera;
    final ValueChanged<int> onRemoveAtt;
    const _Composer({
      required this.textCtrl, required this.focusNode, required this.attachments,
      required this.sending, required this.accent, required this.onSend,
      required this.onImage, required this.onFile, required this.onChanged,
      required this.onRemoveAtt, this.onCamera,
    });

    @override
    Widget build(BuildContext context) {
      final focused = focusNode.hasFocus;
      final hasContent = textCtrl.text.trim().isNotEmpty || attachments.isNotEmpty;
      return Container(
        decoration: const BoxDecoration(color: kBg, border: Border(top: BorderSide(color: kBorder, width: 0.5))),
        padding: EdgeInsets.only(left: 16, right: 16, top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : (MediaQuery.of(context).padding.bottom + 10)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (attachments.isNotEmpty) _AttRow(attachments: attachments, onRemove: onRemoveAtt),
          Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: focused ? accent.withOpacity(0.5) : kBorder)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: textCtrl, focusNode: focusNode, onChanged: (_) => onChanged(),
                maxLines: null, minLines: 1,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(color: kText, fontSize: 13.5, height: 1.5),
                decoration: const InputDecoration(
                  hintText: "Ecris un prompt pour l'agent...",
                  hintStyle: TextStyle(color: kMuted, fontSize: 13.5),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(14, 12, 14, 4), isDense: true),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: Row(children: [
                  _ToolBtn(icon: Icons.image_outlined, onTap: onImage),
                  if (onCamera != null) _ToolBtn(icon: Icons.camera_alt_outlined, onTap: onCamera!),
                  _ToolBtn(icon: Icons.attach_file_outlined, onTap: onFile),
                  const Spacer(),
                  GestureDetector(
                    onTap: hasContent && !sending ? onSend : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: hasContent && !sending ? accent : kSurface3,
                        borderRadius: BorderRadius.circular(9)),
                      child: sending
                        ? const Center(child: SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5)))
                        : const Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.white)),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      );
    }
  }

  class _ToolBtn extends StatelessWidget {
    final IconData icon;
    final VoidCallback onTap;
    const _ToolBtn({required this.icon, required this.onTap});
    @override
    Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(width: 30, height: 30, margin: const EdgeInsets.only(right: 2),
        child: Icon(icon, size: 16, color: kMuted)));
  }

  class _AttRow extends StatelessWidget {
    final List<_Att> attachments;
    final ValueChanged<int> onRemove;
    const _AttRow({required this.attachments, required this.onRemove});
    @override
    Widget build(BuildContext context) => SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final a = attachments[i];
          return Stack(clipBehavior: Clip.none, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (a.type == 'image')
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: Image.memory(a.bytes, width: 26, height: 26, fit: BoxFit.cover))
                else Icon(a.type == 'audio' ? Icons.audiotrack_outlined : Icons.attach_file, size: 16, color: kMuted2),
                const SizedBox(width: 6),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(a.name, style: const TextStyle(color: kText2, fontSize: 10.5), overflow: TextOverflow.ellipsis)),
              ]),
            ),
            Positioned(top: -5, right: -5,
              child: GestureDetector(
                onTap: () => onRemove(i),
                child: Container(width: 16, height: 16,
                  decoration: BoxDecoration(color: kSurface3, shape: BoxShape.circle, border: Border.all(color: kBorder)),
                  child: const Icon(Icons.close, size: 9, color: kMuted2)))),
          ]);
        },
      ),
    );
  }

  class _Att {
    final String type, name, b64;
    final Uint8List bytes;
    _Att(this.type, this.name, this.b64, this.bytes);
  }