import 'dart:convert';
  import 'dart:typed_data';
  import 'package:flutter/foundation.dart' show kIsWeb;
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:file_picker/file_picker.dart';
  import 'package:url_launcher/url_launcher.dart';
  import '../models/room.dart';
  import '../models/prompt.dart';
  import '../models/message.dart';
  import '../services/github_service.dart';
  import '../theme.dart';

  class RoomDetailScreen extends StatelessWidget {
    final Room room;
    final GitHubService github;
    const RoomDetailScreen({super.key, required this.room, required this.github});
    @override
    Widget build(BuildContext context) => DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: kBg,
        body: _RoomBody(room: room, github: github),
      ),
    );
  }

  class _RoomBody extends StatefulWidget {
    final Room room;
    final GitHubService github;
    const _RoomBody({required this.room, required this.github});
    @override State<_RoomBody> createState() => _RoomBodyState();
  }

  class _RoomBodyState extends State<_RoomBody> with SingleTickerProviderStateMixin {
    late final TabController _tab;
    // Tab data
    String? _context;
    String _rules = '';
    List<String> _rulesList = [];
    List<ChatMessage> _messages = [];
    List<AgentPrompt> _prompts = [];
    bool _ctxLoading = true, _rulesLoading = true, _chatLoading = true, _promptLoading = true;
    bool _rulesSaving = false;
    bool _rulesDirty = false;

    @override
    void initState() {
      super.initState();
      _tab = TabController(length: 5, vsync: this);
      _tab.addListener(() { if (!_tab.indexIsChanging) _loadTab(_tab.index); });
      _loadTab(0);
    }
    @override void dispose() { _tab.dispose(); super.dispose(); }

    void _loadTab(int i) {
      if (i == 1 && _ctxLoading) _loadContext();
      if (i == 2 && _rulesLoading) _loadRules();
      if (i == 3 && _chatLoading) _loadChat();
      if (i == 4 && _promptLoading) _loadPrompts();
      if (i == 0) { _loadContext(); _loadRules(); }
    }

    Future<void> _loadContext() async {
      final c = await widget.github.fetchContext(widget.room.id);
      if (mounted) setState(() { _context = c; _ctxLoading = false; });
    }
    Future<void> _loadRules() async {
      final r = await widget.github.fetchRules(widget.room.id);
      if (mounted) setState(() { _rules = r ?? ''; _rulesList = _parseRules(r ?? ''); _rulesLoading = false; });
    }
    Future<void> _loadChat() async {
      final m = await widget.github.fetchMessages(widget.room.id);
      if (mounted) setState(() { _messages = m; _chatLoading = false; });
    }
    Future<void> _loadPrompts() async {
      final p = await widget.github.fetchPrompts(widget.room.id);
      if (mounted) setState(() { _prompts = p; _promptLoading = false; });
    }

    List<String> _parseRules(String md) {
      final out = <String>[];
      for (final l in md.split('\n')) {
        final t = l.trim();
        if (t.startsWith('- ') || t.startsWith('* ')) out.add(t.substring(2).trim());
        else if (RegExp(r'^\d+\.\s').hasMatch(t)) out.add(t.replaceFirst(RegExp(r'^\d+\.\s'),'').trim());
        else if (t.isNotEmpty && !t.startsWith('#')) out.add(t);
      }
      return out.where((s) => s.isNotEmpty).toList();
    }
    String _rulesToMd() => _rulesList.map((r) => '- $r').join('\n');

    Future<void> _saveRules() async {
      if (!widget.github.hasPat) { _snack('Token GitHub requis', kYellow); return; }
      setState(() => _rulesSaving = true);
      try {
        await widget.github.pushRules(widget.room.id, _rulesToMd());
        if (mounted) { setState(() { _rulesSaving = false; _rulesDirty = false; }); _snack('Regles sauvegardees', kGreen); }
      } catch (e) { if (mounted) { setState(() => _rulesSaving = false); _snack('Erreur: $e', kRed); } }
    }

    void _snack(String msg, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: c.withOpacity(0.9), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 2)));

    @override
    Widget build(BuildContext context) {
      final accent = widget.room.accentColor;
      return NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            backgroundColor: kBg, pinned: true, floating: false,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                child: const Icon(Icons.arrow_back_ios_new, size: 13, color: kMuted2))),
            title: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.room.iconData, size: 16, color: accent),
              const SizedBox(width: 8),
              Flexible(child: Text(widget.room.name, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.2), overflow: TextOverflow.ellipsis)),
            ]),
            centerTitle: true,
            bottom: TabBar(
              controller: _tab,
              isScrollable: true, tabAlignment: TabAlignment.start,
              indicatorColor: accent, indicatorSize: TabBarIndicatorSize.label,
              labelColor: kText, unselectedLabelColor: kMuted, labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Accueil'), Tab(text: 'Contexte'),
                Tab(text: 'Regles'), Tab(text: 'Chat'), Tab(text: 'Prompts'),
              ],
            ),
          ),
        ],
        body: TabBarView(controller: _tab, children: [
          _AccueilTab(room: widget.room, context2: _context, rules: _rulesList, github: widget.github),
          _ContexteTab(content: _context, loading: _ctxLoading),
          _ReglesTab(rules: _rulesList, loading: _rulesLoading, saving: _rulesSaving, dirty: _rulesDirty,
            onAdd: (r) => setState(() { _rulesList.add(r); _rulesDirty = true; }),
            onEdit: (i,r) => setState(() { _rulesList[i]=r; _rulesDirty=true; }),
            onDelete: (i) => setState(() { _rulesList.removeAt(i); _rulesDirty=true; }),
            onSave: _saveRules),
          _ChatTab(room: widget.room, messages: _messages, loading: _chatLoading, github: widget.github,
            onSent: (m) => setState(() => _messages.add(m)), onSnack: _snack),
          _PromptTab(room: widget.room, prompts: _prompts, loading: _promptLoading, github: widget.github,
            onSent: (p) => setState(() => _prompts.insert(0,p)), onSnack: _snack),
        ]),
      );
    }
  }

  // ─── Tab 1: Accueil ───────────────────────────────────────────
  class _AccueilTab extends StatelessWidget {
    final Room room; final String? context2; final List<String> rules; final GitHubService github;
    const _AccueilTab({required this.room, this.context2, required this.rules, required this.github});
    @override
    Widget build(BuildContext context) {
      final accent = room.accentColor;
      return ListView(padding: const EdgeInsets.all(16), children: [
        // Telegram-style room header
        Center(child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 80, height: 80,
            decoration: BoxDecoration(color: accent.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: accent.withOpacity(0.3), width: 2)),
            child: Icon(room.iconData, size: 36, color: accent)),
          const SizedBox(height: 12),
          Text(room.name, style: const TextStyle(color: kText, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          if (room.description.isNotEmpty)
            Text(room.description, style: const TextStyle(color: kText2, fontSize: 13.5, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          // GitHub link
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://github.com/ferelking242/agentbase/tree/main/rooms/${room.id}'), mode: LaunchMode.externalApplication),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder2)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.code, size: 14, color: kMuted2),
                SizedBox(width: 6),
                Text('Voir sur GitHub', style: TextStyle(color: kText2, fontSize: 12, fontWeight: FontWeight.w500)),
                SizedBox(width: 4),
                Icon(Icons.open_in_new, size: 11, color: kMuted),
              ])),
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _stat('${room.transcriptCount}', 'Prompts'),
            Container(width: 1, height: 28, color: kBorder, margin: const EdgeInsets.symmetric(horizontal: 16)),
            _stat('${room.chatCount}', 'Messages'),
            Container(width: 1, height: 28, color: kBorder, margin: const EdgeInsets.symmetric(horizontal: 16)),
            _stat('${rules.length}', 'Regles'),
          ]),
          const SizedBox(height: 8),
        ])),
        const Divider(color: kBorder, height: 28),
        // Quick info
        if (context2 != null) _infoCard('Contexte', Icons.info_outline, context2!.split('\n').where((l)=>l.isNotEmpty&&!l.startsWith('#')).take(2).join(' ')),
        if (rules.isNotEmpty) _infoCard('Regles actives', Icons.rule_outlined, '${rules.length} regle${rules.length>1?"s":""}'),
      ]);
    }
    Widget _stat(String v, String l) => Column(children: [
      Text(v, style: const TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w700)),
      Text(l, style: const TextStyle(color: kMuted, fontSize: 11)),
    ]);
    Widget _infoCard(String t, IconData i, String s) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
      child: Row(children: [
        Icon(i, size: 14, color: kMuted2), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(color: kMuted2, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(s, style: const TextStyle(color: kText2, fontSize: 12.5, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  // ─── Tab 2: Contexte ──────────────────────────────────────────
  class _ContexteTab extends StatelessWidget {
    final String? content; final bool loading;
    const _ContexteTab({this.content, required this.loading});
    @override
    Widget build(BuildContext context) {
      if (loading) return const Center(child: CircularProgressIndicator(color: kAccent));
      if (content == null || content!.isEmpty) return _empty('Aucun contexte defini', "Ajoute un fichier context.md dans le dossier de la room sur GitHub.");
      return ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
          child: _Markdown(content!)),
      ]);
    }
  }

  // ─── Tab 3: Regles ────────────────────────────────────────────
  class _ReglesTab extends StatefulWidget {
    final List<String> rules; final bool loading, saving, dirty;
    final ValueChanged<String> onAdd;
    final void Function(int, String) onEdit;
    final ValueChanged<int> onDelete;
    final VoidCallback onSave;
    const _ReglesTab({required this.rules, required this.loading, required this.saving, required this.dirty,
      required this.onAdd, required this.onEdit, required this.onDelete, required this.onSave});
    @override State<_ReglesTab> createState() => _ReglesTabState();
  }
  class _ReglesTabState extends State<_ReglesTab> {
    int? _editing;
    final _ctrl = TextEditingController();
    @override void dispose() { _ctrl.dispose(); super.dispose(); }

    void _startEdit(int i) { setState(() { _editing = i; _ctrl.text = widget.rules[i]; }); }
    void _confirmEdit() {
      if (_editing == null) return;
      final t = _ctrl.text.trim();
      if (t.isNotEmpty) widget.onEdit(_editing!, t);
      setState(() => _editing = null); _ctrl.clear();
    }

    @override
    Widget build(BuildContext context) {
      if (widget.loading) return const Center(child: CircularProgressIndicator(color: kAccent));
      return Column(children: [
        if (widget.dirty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              const Expanded(child: Text('Modifications non sauvegardees', style: TextStyle(color: kYellow, fontSize: 12))),
              GestureDetector(onTap: widget.saving ? null : widget.onSave,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(8)),
                  child: widget.saving
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                    : const Text('Sauvegarder', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
            ])),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: widget.rules.length,
          itemBuilder: (_, i) {
            if (_editing == i) return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: kAccent.withOpacity(0.4))),
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                TextField(controller: _ctrl, autofocus: true, style: const TextStyle(color: kText, fontSize: 13.5), maxLines: null,
                  decoration: const InputDecoration(border: InputBorder.none, hintText: 'Contenu de la regle...', hintStyle: TextStyle(color: kMuted), contentPadding: EdgeInsets.zero, isDense: true)),
                const SizedBox(height: 8),
                Row(children: [
                  const Spacer(),
                  GestureDetector(onTap: () => setState(() { _editing = null; _ctrl.clear(); }),
                    child: const Text('Annuler', style: TextStyle(color: kMuted, fontSize: 12))),
                  const SizedBox(width: 12),
                  GestureDetector(onTap: _confirmEdit,
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(7)),
                      child: const Text('OK', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
                ]),
              ]));
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(width: 24, height: 24, decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Center(child: Text('${i+1}', style: const TextStyle(color: kAccentL, fontSize: 11, fontWeight: FontWeight.w700)))),
                title: Text(widget.rules[i], style: const TextStyle(color: kText2, fontSize: 13.5, height: 1.5)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(onTap: () => _startEdit(i),
                    child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: 15, color: kMuted2))),
                  const SizedBox(width: 2),
                  GestureDetector(onTap: () => widget.onDelete(i),
                    child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: 15, color: kRed))),
                ]),
              ));
          })),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _AddRuleBar(onAdd: widget.onAdd)),
      ]);
    }
  }

  class _AddRuleBar extends StatefulWidget {
    final ValueChanged<String> onAdd;
    const _AddRuleBar({required this.onAdd});
    @override State<_AddRuleBar> createState() => _AddRuleBarState();
  }
  class _AddRuleBarState extends State<_AddRuleBar> {
    final _c = TextEditingController();
    @override void dispose() { _c.dispose(); super.dispose(); }
    @override
    Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        const Icon(Icons.add, size: 16, color: kMuted2),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _c, style: const TextStyle(color: kText, fontSize: 13), maxLines: 1,
          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Nouvelle regle...', hintStyle: TextStyle(color: kMuted), contentPadding: EdgeInsets.zero, isDense: true),
          onSubmitted: (v) { final t=v.trim(); if(t.isNotEmpty){widget.onAdd(t);_c.clear();} })),
        GestureDetector(onTap: () { final t=_c.text.trim(); if(t.isNotEmpty){widget.onAdd(t);_c.clear();} },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(7)),
            child: const Text('Ajouter', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
      ]),
    );
  }

  // ─── Tab 4: Chat ──────────────────────────────────────────────
  class _ChatTab extends StatefulWidget {
    final Room room; final List<ChatMessage> messages; final bool loading; final GitHubService github;
    final ValueChanged<ChatMessage> onSent; final void Function(String, Color) onSnack;
    const _ChatTab({required this.room, required this.messages, required this.loading, required this.github, required this.onSent, required this.onSnack});
    @override State<_ChatTab> createState() => _ChatTabState();
  }
  class _ChatTabState extends State<_ChatTab> {
    final _ctrl = TextEditingController();
    final _scroll = ScrollController();
    bool _sending = false;
    @override void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

    Future<void> _send() async {
      final t = _ctrl.text.trim();
      if (t.isEmpty) return;
      if (!widget.github.hasPat) { widget.onSnack('Token requis', kYellow); return; }
      setState(() => _sending = true);
      try {
        await widget.github.pushMessage(widget.room.id, t);
        final ts = DateTime.now().millisecondsSinceEpoch;
        final msg = ChatMessage(id:'chat-$ts.md', sender:'Moi', content:t, isUser:true, createdAt:DateTime.fromMillisecondsSinceEpoch(ts));
        _ctrl.clear(); widget.onSent(msg);
        if (mounted) {
          setState(() => _sending = false);
          await Future.delayed(const Duration(milliseconds: 100));
          if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      } catch (e) { if (mounted) { setState(() => _sending = false); widget.onSnack('Erreur: $e', kRed); } }
    }

    String _fmt(DateTime? d) { if(d==null)return''; return '${d.hour.toString().padLeft(2,"0")}:${d.minute.toString().padLeft(2,"0")}'; }

    @override
    Widget build(BuildContext context) {
      if (widget.loading) return const Center(child: CircularProgressIndicator(color: kAccent));
      final accent = widget.room.accentColor;
      return Column(children: [
        Expanded(child: widget.messages.isEmpty
          ? _empty('Aucun message', 'Les agents et toi pouvez discuter ici')
          : ListView.builder(
              controller: _scroll, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: widget.messages.length,
              itemBuilder: (_, i) {
                final m = widget.messages[i];
                final isMe = m.isUser;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                      if (!isMe) Padding(padding: const EdgeInsets.only(left: 4, bottom: 2),
                        child: Text(m.sender, style: TextStyle(color: accent, fontSize: 10.5, fontWeight: FontWeight.w600))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? accent : kSurface2,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14), topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isMe ? 14 : 3),
                            bottomRight: Radius.circular(isMe ? 3 : 14))),
                        child: Text(m.content, style: TextStyle(color: isMe ? Colors.white : kText2, fontSize: 13.5, height: 1.4))),
                      Padding(padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                        child: Text(_fmt(m.createdAt), style: const TextStyle(color: kMuted, fontSize: 9.5))),
                    ]),
                  ));
              })),
        Container(
          decoration: const BoxDecoration(color: kBg, border: Border(top: BorderSide(color: kBorder, width: 0.5))),
          padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
          child: Row(children: [
            Expanded(child: Container(
              decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(22), border: Border.all(color: kBorder)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: TextField(controller: _ctrl, style: const TextStyle(color: kText, fontSize: 13.5), maxLines: 4, minLines: 1,
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Envoyer un message...', hintStyle: TextStyle(color: kMuted), contentPadding: EdgeInsets.zero, isDense: true)))),
            const SizedBox(width: 8),
            GestureDetector(onTap: _sending ? null : _send,
              child: Container(width: 40, height: 40, decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: _sending ? const Center(child: SizedBox(width:14,height:14,child:CircularProgressIndicator(color:Colors.white,strokeWidth:1.5))) : const Icon(Icons.send_rounded, size: 18, color: Colors.white))),
          ]),
        ),
      ]);
    }
  }

  // ─── Tab 5: Prompts ───────────────────────────────────────────
  class _PromptTab extends StatefulWidget {
    final Room room; final List<AgentPrompt> prompts; final bool loading; final GitHubService github;
    final ValueChanged<AgentPrompt> onSent; final void Function(String, Color) onSnack;
    const _PromptTab({required this.room, required this.prompts, required this.loading, required this.github, required this.onSent, required this.onSnack});
    @override State<_PromptTab> createState() => _PromptTabState();
  }
  class _PromptTabState extends State<_PromptTab> {
    final _nameCtrl = TextEditingController();
    final _textCtrl = TextEditingController();
    final List<_Att> _attachments = [];
    bool _sending = false;
    @override void dispose() { _nameCtrl.dispose(); _textCtrl.dispose(); super.dispose(); }

    Future<void> _pickImage() async { try { final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:80); if(x==null)return; final b=await x.readAsBytes(); setState(()=>_attachments.add(_Att('image',x.name,base64Encode(b),b))); } catch(_){} }
    Future<void> _pickFile() async {
      try {
        final r=await FilePicker.platform.pickFiles(withData:true); if(r==null||r.files.isEmpty)return;
        final f=r.files.first; if(f.bytes==null)return;
        final ext=(f.extension??'').toLowerCase();
        String t='file'; if(['jpg','jpeg','png','gif','webp'].contains(ext))t='image'; else if(['mp3','m4a','wav'].contains(ext))t='audio';
        setState(()=>_attachments.add(_Att(t,f.name,base64Encode(f.bytes!),f.bytes!)));
      } catch(_){}
    }

    Future<void> _send() async {
      final txt = _textCtrl.text.trim();
      if (txt.isEmpty) return;
      if (!widget.github.hasPat) { widget.onSnack('Token requis', kYellow); return; }
      setState(() => _sending = true);
      try {
        final ts = '${DateTime.now().millisecondsSinceEpoch}';
        final maxN = widget.prompts.map((p)=>p.number).fold(0,(a,b)=>a>b?a:b);
        final prompt = AgentPrompt(
          id: ts, number: maxN+1, roomId: widget.room.id, text: txt, status: 'pending',
          name: _nameCtrl.text.trim(), createdAt: DateTime.now(),
          attachments: _attachments.map((a)=>PromptAttachment(type:a.type,name:a.name,path:'',base64Data:a.b64,sizeBytes:a.bytes.length)).toList());
        await widget.github.pushPrompt(widget.room.id, prompt);
        if (mounted) { setState(() { _sending = false; _textCtrl.clear(); _nameCtrl.clear(); _attachments.clear(); }); widget.onSent(prompt); widget.onSnack('Prompt envoye', kGreen); }
      } catch (e) { if (mounted) { setState(() => _sending = false); widget.onSnack('Erreur: $e', kRed); } }
    }

    String _fmt(DateTime? d) { if(d==null)return''; return '${d.day.toString().padLeft(2,"0")}/${d.month.toString().padLeft(2,"0")} ${d.hour.toString().padLeft(2,"0")}:${d.minute.toString().padLeft(2,"0")}'; }
    Color _sc(String s){ switch(s.toLowerCase()){ case 'done':case 'executed':return kGreen; case 'executing':case 'running':return kYellow; case 'read':return kBlue; default:return kMuted;} }

    @override
    Widget build(BuildContext context) {
      if (widget.loading) return const Center(child: CircularProgressIndicator(color: kAccent));
      final accent = widget.room.accentColor;
      return ListView(padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 16), children: [
        // Composer
        Container(
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('NOUVEAU PROMPT', style: TextStyle(color: kMuted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 10),
            // Name field
            Container(decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: TextField(controller: _nameCtrl, style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Nom du prompt (optionnel)', hintStyle: TextStyle(color: kMuted, fontSize: 12.5), contentPadding: EdgeInsets.zero, isDense: true))),
            const SizedBox(height: 8),
            // Text area
            Container(decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
              padding: const EdgeInsets.all(10),
              child: TextField(controller: _textCtrl, style: const TextStyle(color: kText, fontSize: 13.5, height: 1.5),
                maxLines: 5, minLines: 3,
                decoration: const InputDecoration(border: InputBorder.none, hintText: "Ecris les instructions pour l'agent...", hintStyle: TextStyle(color: kMuted), contentPadding: EdgeInsets.zero, isDense: true))),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: List.generate(_attachments.length, (i) {
                final a = _attachments[i];
                return Chip(backgroundColor: kSurface3, side: const BorderSide(color: kBorder), label: Text(a.name, style: const TextStyle(color: kText2, fontSize: 11)),
                  onDeleted: () => setState(() => _attachments.removeAt(i)), deleteIconColor: kMuted);
              })),
            ],
            const SizedBox(height: 10),
            Row(children: [
              GestureDetector(onTap: _pickImage, child: const Icon(Icons.image_outlined, size: 18, color: kMuted)),
              const SizedBox(width: 10),
              if (!kIsWeb) GestureDetector(onTap: () async { try { final x=await ImagePicker().pickImage(source:ImageSource.camera,imageQuality:80); if(x==null)return; final b=await x.readAsBytes(); setState(()=>_attachments.add(_Att('image','photo_${DateTime.now().millisecondsSinceEpoch}.jpg',base64Encode(b),b))); } catch(_){} },
                child: const Icon(Icons.camera_alt_outlined, size: 18, color: kMuted)),
              if (!kIsWeb) const SizedBox(width: 10),
              GestureDetector(onTap: _pickFile, child: const Icon(Icons.attach_file, size: 18, color: kMuted)),
              const Spacer(),
              GestureDetector(onTap: _sending ? null : _send,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(9)),
                  child: _sending
                    ? const SizedBox(width:13,height:13,child:CircularProgressIndicator(color:Colors.white,strokeWidth:1.5))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.send_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Envoyer', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]))),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        // Past prompts
        if (widget.prompts.isNotEmpty) ...[
          const Text('PROMPTS SAUVEGARDES', style: TextStyle(color: kMuted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          ...widget.prompts.map((p) => _PromptCard(prompt: p, accent: accent, fmt: _fmt, sc: _sc, onCopy: (t) { Clipboard.setData(ClipboardData(text: t)); widget.onSnack('Copie', kAccent); })),
        ],
      ]);
    }
  }

  class _PromptCard extends StatefulWidget {
    final AgentPrompt prompt; final Color accent;
    final String Function(DateTime?) fmt;
    final Color Function(String) sc;
    final ValueChanged<String> onCopy;
    const _PromptCard({required this.prompt, required this.accent, required this.fmt, required this.sc, required this.onCopy});
    @override State<_PromptCard> createState() => _PromptCardState();
  }
  class _PromptCardState extends State<_PromptCard> {
    bool _exp = false;
    @override
    Widget build(BuildContext context) {
      final p = widget.prompt;
      final displayName = p.name.isNotEmpty ? p.name : 'Prompt #${p.number}';
      final sc = widget.sc(p.status);
      return GestureDetector(
        onTap: () => setState(() => _exp = !_exp),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
          child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: widget.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(displayName, style: TextStyle(color: widget.accent, fontSize: 12, fontWeight: FontWeight.w700))),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(p.status, style: TextStyle(color: sc, fontSize: 10, fontWeight: FontWeight.w600))),
              const SizedBox(width: 6),
              GestureDetector(onTap: () => widget.onCopy(p.text),
                child: Container(width: 26, height: 26, decoration: BoxDecoration(color: kSurface3, borderRadius: BorderRadius.circular(6), border: Border.all(color: kBorder)),
                  child: const Icon(Icons.copy_outlined, size: 12, color: kMuted2))),
            ]),
            if (p.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_exp ? p.text : (p.text.length>120?'${p.text.substring(0,120)}...':p.text),
                style: const TextStyle(color: kText2, fontSize: 13, height: 1.5)),
            ],
            const SizedBox(height: 4),
            Text(widget.fmt(p.createdAt), style: const TextStyle(color: kMuted, fontSize: 10.5)),
          ])),
        ),
      );
    }
  }

  // ─── Shared helpers ───────────────────────────────────────────
  Widget _empty(String title, String sub) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.inbox_outlined, size: 36, color: kMuted),
    const SizedBox(height: 12),
    Text(title, style: const TextStyle(color: kText2, fontSize: 15, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    const SizedBox(height: 4),
    Text(sub, style: const TextStyle(color: kMuted, fontSize: 12.5, height: 1.5), textAlign: TextAlign.center),
  ])));

  class _Markdown extends StatelessWidget {
    final String content;
    const _Markdown(this.content);
    @override
    Widget build(BuildContext context) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: content.split('\n').where((l)=>l.trim().isNotEmpty).map((line) {
        if (line.startsWith('## ')) return _h(line.substring(3), 14, FontWeight.w700, kText);
        if (line.startsWith('# '))  return _h(line.substring(2), 15, FontWeight.w700, kText);
        if (line.startsWith('### ')) return _h(line.substring(4), 13, FontWeight.w600, kText2);
        if (line.startsWith('- ') || line.startsWith('* ')) return _bullet(line.substring(2));
        return Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(line, style: const TextStyle(color: kText2, fontSize: 13, height: 1.6)));
      }).toList());
    }
    Widget _h(String t, double s, FontWeight w, Color c) => Padding(padding: const EdgeInsets.only(bottom: 6, top: 4), child: Text(t, style: TextStyle(color: c, fontSize: s, fontWeight: w, letterSpacing: -0.2)));
    Widget _bullet(String t) => Padding(padding: const EdgeInsets.only(bottom: 4, left: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 4, color: kMuted2)),
      const SizedBox(width: 8),
      Expanded(child: Text(t, style: const TextStyle(color: kText2, fontSize: 13, height: 1.6))),
    ]));
  }

  class _Att {
    final String type, name, b64; final Uint8List bytes;
    _Att(this.type, this.name, this.b64, this.bytes);
  }