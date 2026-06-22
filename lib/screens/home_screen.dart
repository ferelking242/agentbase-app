import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/github_service.dart';
import '../services/prefs_service.dart';
import '../models/saved_prompt.dart';
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

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── File picker ──────────────────────────────────────────────────────────
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

  // ── Paste from clipboard ─────────────────────────────────────────────────
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

  // ── Open fullscreen composer ─────────────────────────────────────────────
  Future<void> _openFullscreen() async {
    final result = await Navigator.push<SavedPrompt?>(
      context,
      MaterialPageRoute(builder: (_) => FullscreenComposerScreen(
        initialText: _ctrl.text,
        initialFiles: List.from(_files),
        github: widget.github,
      )),
    );
    if (result != null) {
      // Prompt was saved from fullscreen
      _ctrl.clear();
      setState(() { _files = []; });
      _onPromptSaved(result);
    }
  }

  // ── Send from compact bar ────────────────────────────────────────────────
  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty && _files.isEmpty) return;

    final defaultName = _ctrl.text.trim().split(' ').take(5).join(' ');
    final name = await _showNameDialog(defaultName);
    if (name == null) return;

    final text = _ctrl.text;
    final filesCopy = List<AttachedFile>.from(_files);

    setState(() {
      _msgs.add(_Msg.user(text, filesCopy));
      _ctrl.clear();
      _files = [];
      _sending = true;
    });
    _scrollBottom();

    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final link = await widget.github.pushDirectPrompt(id, text, filesCopy);
      final prompt = SavedPrompt(
        id: id,
        name: name.isNotEmpty ? name : defaultName,
        link: link,
        created: DateTime.now(),
      );
      await PrefsService.addPrompt(prompt);
      if (!mounted) return;
      setState(() {
        _msgs.add(_Msg.promptSaved(prompt));
        _sending = false;
      });
      _onPromptSaved(prompt);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.add(_Msg.agentError(
          'Configure ton PAT dans Parametres pour sauvegarder. (${e.toString().replaceAll("Exception: ", "")})',
        ));
        _sending = false;
      });
    }
    _scrollBottom();
  }

  void _onPromptSaved(SavedPrompt p) => widget.onPromptSaved?.call(p);

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
      );
    });
  }

  Future<String?> _showNameDialog(String defaultName) {
    final ctrl = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nom du prompt',
          style: TextStyle(color: Color(0xFFECECEC), fontSize: 16, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFECECEC), fontSize: 15),
          cursorColor: const Color(0xFF6366F1),
          decoration: InputDecoration(
            hintText: 'Ex: Analyse donnees',
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
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Annuler', style: TextStyle(color: Color(0xFF666666)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : defaultName),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0,
            ),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  // ── Suggestions ──────────────────────────────────────────────────────────
  static const _suggestions = [
    (Icons.lightbulb_outline,   'Analyser un probleme'),
    (Icons.rule_outlined,        'Creer une regle agent'),
    (Icons.workspaces_outlined,  'Explorer les rooms'),
    (Icons.settings_outlined,    'Configurer un agent'),
  ];

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEmpty = _msgs.isEmpty && !_sending;
    return Container(
      color: Colors.black,
      child: Column(children: [
        Expanded(child: isEmpty ? _buildHome() : _buildMsgs()),
        _buildInput(),
      ]),
    );
  }

  Widget _buildHome() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Que puis-je faire pour toi\u00a0?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFECECEC), fontSize: 26,
            fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.3)),
        const SizedBox(height: 28),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, crossAxisSpacing: 10,
          mainAxisSpacing: 10, childAspectRatio: 2.8,
          physics: const NeverScrollableScrollPhysics(),
          children: _suggestions.map((s) => _SuggCard(
            icon: s.$1, label: s.$2,
            onTap: () { _ctrl.text = s.$2; _focus.requestFocus(); setState(() {}); },
          )).toList(),
        ),
      ]),
    ),
  );

  Widget _buildMsgs() => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    itemCount: _msgs.length + (_sending ? 1 : 0),
    itemBuilder: (_, i) {
      if (i == _msgs.length) return const _TypingDots();
      final m = _msgs[i];
      return m.isUser ? _UserBubble(msg: m) : _AgentBubble(msg: m);
    },
  );

  Widget _buildInput() {
    final hasContent = _ctrl.text.trim().isNotEmpty || _files.isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Attached images at top (horizontal scroll)
          if (_files.isNotEmpty)
            Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _files.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = _files[i];
                  return Stack(children: [
                    f.isImage
                      ? ClipRRect(borderRadius: BorderRadius.circular(10),
                          child: Image.memory(f.bytes, width: 72, height: 72, fit: BoxFit.cover))
                      : Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF2A2A2A))),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF6366F1), size: 22),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(f.name, style: const TextStyle(color: Color(0xFF888888), fontSize: 8),
                                maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                          ])),
                    Positioned(top: 2, right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _files.removeAt(i)),
                        child: Container(width: 16, height: 16,
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 10, color: Colors.white)),
                      )),
                  ]);
                },
              ),
            ),
          // Input box
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2F2F2F),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF3F3F3F), width: 0.8),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // + attach
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF8E8EA0), size: 22),
                onPressed: _pickFiles,
                tooltip: 'Joindre',
              ),
              // text field
              Expanded(
                child: TextField(
                  controller: _ctrl, focusNode: _focus,
                  maxLines: 5, minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Color(0xFFECECEC), fontSize: 15, height: 1.45),
                  cursorColor: const Color(0xFF8E8EA0),
                  decoration: const InputDecoration(
                    hintText: 'Envoie un message',
                    hintStyle: TextStyle(color: Color(0xFF8E8EA0), fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 11),
                    isDense: true,
                  ),
                ),
              ),
              // paste
              IconButton(
                icon: const Icon(Icons.content_paste_rounded, color: Color(0xFF8E8EA0), size: 18),
                onPressed: _paste,
                tooltip: 'Coller',
              ),
              // expand fullscreen
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Color(0xFF8E8EA0), size: 20),
                onPressed: _openFullscreen,
                tooltip: 'Plein ecran',
              ),
              // send
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
                    child: Icon(Icons.arrow_upward, size: 18,
                      color: hasContent ? Colors.black : const Color(0xFF888888)),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          const Text('AgentBase peut faire des erreurs. Verifiez les informations importantes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF4A4A5A), fontSize: 10.5)),
        ]),
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

  const _Msg._({required this.isUser, this.text = '', this.files = const [], this.prompt, this.errorText});
  factory _Msg.user(String t, List<AttachedFile> f) => _Msg._(isUser: true, text: t, files: f);
  factory _Msg.promptSaved(SavedPrompt p) => _Msg._(isUser: false, prompt: p);
  factory _Msg.agentError(String e) => _Msg._(isUser: false, errorText: e);
}

// ── Suggestion card ────────────────────────────────────────────────────────
class _SuggCard extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _SuggCard({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF8E8EA0)),
        const SizedBox(width: 8),
        Expanded(child: Text(label,
          style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 12.5, fontWeight: FontWeight.w500),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}

// ── User bubble ────────────────────────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final _Msg msg;
  const _UserBubble({required this.msg});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(bottom: 16, left: 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (msg.files.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end,
              children: msg.files.map((f) => f.isImage
                ? ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: Image.memory(f.bytes, width: 120, height: 90, fit: BoxFit.cover))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.insert_drive_file_outlined, size: 14, color: Color(0xFF8E8EA0)),
                      const SizedBox(width: 6),
                      Text(f.name, style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 12)),
                    ]))
              ).toList()),
          ),
        if (msg.text.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(color: const Color(0xFF2F2F2F), borderRadius: BorderRadius.circular(18)),
            child: Text(msg.text, style: const TextStyle(color: Color(0xFFECECEC), fontSize: 15, height: 1.5)),
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
      Container(width: 28, height: 28,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
          borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.bolt, size: 15, color: Colors.white)),
      const SizedBox(width: 10),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: msg.prompt != null
          ? _PromptLinkCard(prompt: msg.prompt!)
          : Text(msg.errorText ?? '',
              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14, height: 1.55)),
      )),
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
      border: Border.all(color: const Color(0xFF1A3A1A))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.check_circle_outline, color: Color(0xFF22C55E), size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text('"${widget.prompt.name}"',
          style: const TextStyle(color: Color(0xFF22C55E), fontSize: 13, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 6),
      Text('ID: ${widget.prompt.id}', style: const TextStyle(color: Color(0xFF446644), fontSize: 11)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF050F05), borderRadius: BorderRadius.circular(8)),
        child: Text(widget.prompt.link,
          style: const TextStyle(color: Color(0xFF5A9A5A), fontSize: 11, fontFamily: 'monospace'),
          maxLines: 3, overflow: TextOverflow.ellipsis)),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.prompt.link));
            setState(() => _copied = true);
            Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copied = false); });
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
        )),
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
      Container(width: 28, height: 28,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
          borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.bolt, size: 15, color: Colors.white)),
      const SizedBox(width: 10),
      Padding(padding: const EdgeInsets.only(top: 10),
        child: AnimatedBuilder(animation: _ctrl, builder: (_, __) => Row(
          children: List.generate(3, (i) {
            final t = (_ctrl.value - i * 0.33).clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Padding(padding: const EdgeInsets.only(right: 4),
              child: Transform.scale(scale: scale, child: Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(color: Color(0xFF8E8EA0), shape: BoxShape.circle))));
          })))),
    ]),
  );
}
