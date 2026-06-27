import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/room.dart';
import '../models/message.dart';
import '../services/github_service.dart';
import '../theme.dart';
import '../widgets/app_components.dart';

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
  String? _context;
  String _rules = '';
  List<String> _rulesList = [];
  List<ChatMessage> _messages = [];
  List<_LocalPrompt> _prompts = [];
  bool _ctxLoading = true, _rulesLoading = true, _chatLoading = true, _promptLoading = true;
  bool _rulesSaving = false, _rulesDirty = false;

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
    if (mounted) setState(() {
      _prompts = p.map((a) => _LocalPrompt(text: a.text, link: '')).toList();
      _promptLoading = false;
    });
  }

  List<String> _parseRules(String md) {
    final out = <String>[];
    for (final l in md.split('\n')) {
      final t = l.trim();
      if (t.startsWith('- ') || t.startsWith('* ')) out.add(t.substring(2).trim());
      else if (RegExp(r'^\d+\.\s').hasMatch(t)) out.add(t.replaceFirst(RegExp(r'^\d+\.\s'), '').trim());
      else if (t.isNotEmpty && !t.startsWith('#')) out.add(t);
    }
    return out.where((s) => s.isNotEmpty).toList();
  }

  String _rulesToMd() => _rulesList.map((r) => '- $r').join('\n');

  Future<void> _saveRules() async {
    if (!widget.github.hasPat) { showAppSnack(context, 'Token GitHub requis', color: kYellow); return; }
    setState(() => _rulesSaving = true);
    try {
      await widget.github.pushRules(widget.room.id, _rulesToMd());
      if (mounted) { setState(() { _rulesSaving = false; _rulesDirty = false; }); showAppSnack(context, 'Règles sauvegardées'); }
    } catch (e) {
      if (mounted) { setState(() => _rulesSaving = false); showAppSnack(context, 'Erreur: $e', isError: true); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.room.accentColor;
    return NestedScrollView(
      headerSliverBuilder: (ctx, _) => [
        SliverAppBar(
          backgroundColor: kBg,
          pinned: true,
          floating: false,
          surfaceTintColor: Colors.transparent,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
                child: const Icon(Icons.arrow_back_ios_new, size: 13, color: kMuted),
              ),
            ),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.room.iconData, size: 16, color: accent),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.room.name,
              style: GoogleFonts.inter(color: kText, fontSize: 14.5, fontWeight: FontWeight.w600, letterSpacing: -0.2),
              overflow: TextOverflow.ellipsis)),
          ]),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
              child: TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(color: accent, width: 2),
                  insets: const EdgeInsets.symmetric(horizontal: 12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: kText,
                unselectedLabelColor: kMuted2,
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Accueil'),
                  Tab(text: 'Contexte'),
                  Tab(text: 'Règles'),
                  Tab(text: 'Chat'),
                  Tab(text: 'Prompts'),
                ],
              ),
            ),
          ),
        ),
      ],
      body: TabBarView(controller: _tab, children: [
        _AccueilTab(room: widget.room, context2: _context, rules: _rulesList, github: widget.github),
        _ContexteTab(content: _context, loading: _ctxLoading),
        _ReglesTab(
          rules: _rulesList,
          loading: _rulesLoading,
          saving: _rulesSaving,
          dirty: _rulesDirty,
          onAdd: (r) => setState(() { _rulesList.add(r); _rulesDirty = true; }),
          onEdit: (i, r) => setState(() { _rulesList[i] = r; _rulesDirty = true; }),
          onDelete: (i) => setState(() { _rulesList.removeAt(i); _rulesDirty = true; }),
          onSave: _saveRules,
        ),
        _ChatTab(
          room: widget.room,
          messages: _messages,
          loading: _chatLoading,
          github: widget.github,
          onSent: (m) => setState(() => _messages.add(m)),
          onSnack: (msg, c) => showAppSnack(context, msg, color: c),
        ),
        _PromptTab(
          room: widget.room,
          prompts: _prompts,
          loading: _promptLoading,
          github: widget.github,
          onSent: (lp) => setState(() => _prompts.insert(0, lp)),
          onSnack: (msg, c) => showAppSnack(context, msg, color: c),
        ),
      ]),
    );
  }
}

// ─── Tab 1: Accueil ───────────────────────────────────────────────────────────
class _AccueilTab extends StatelessWidget {
  final Room room;
  final String? context2;
  final List<String> rules;
  final GitHubService github;
  const _AccueilTab({required this.room, this.context2, required this.rules, required this.github});

  @override
  Widget build(BuildContext context) {
    final accent = room.accentColor;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Center(child: Column(children: [
        const SizedBox(height: 16),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Icon(room.iconData, size: 34, color: accent),
        ),
        const SizedBox(height: 14),
        Text(room.name, style: GoogleFonts.inter(color: kText, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
        if (room.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(room.description,
            style: GoogleFonts.inter(color: kMuted2, fontSize: 13.5, height: 1.5),
            textAlign: TextAlign.center),
        ],
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => launchUrl(
            Uri.parse('https://github.com/ferelking242/agentbase/tree/main/rooms/${room.id}'),
            mode: LaunchMode.externalApplication,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder, width: 0.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.code, size: 13, color: kMuted2),
              const SizedBox(width: 6),
              Text('Voir sur GitHub', style: GoogleFonts.inter(color: kText2, fontSize: 12.5, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              const Icon(Icons.open_in_new, size: 11, color: kMuted2),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        // Stats row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder, width: 0.5)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _StatCell('${room.transcriptCount}', 'Prompts'),
            _Separator(),
            _StatCell('${room.chatCount}', 'Messages'),
            _Separator(),
            _StatCell('${rules.length}', 'Règles'),
          ]),
        ),
      ])),
      const SizedBox(height: 20),
      const AppDivider(),
      const SizedBox(height: 16),
      if (context2 != null && context2!.isNotEmpty)
        _InfoCard(
          icon: Icons.info_outline,
          title: 'Contexte',
          subtitle: context2!.split('\n').where((l) => l.isNotEmpty && !l.startsWith('#')).take(2).join(' '),
        ),
      if (rules.isNotEmpty)
        _InfoCard(
          icon: Icons.rule_outlined,
          title: 'Règles actives',
          subtitle: '${rules.length} règle${rules.length > 1 ? "s" : ""} configurée${rules.length > 1 ? "s" : ""}',
        ),
    ]);
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: GoogleFonts.inter(color: kText, fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 2),
    Text(label, style: GoogleFonts.inter(color: kMuted2, fontSize: 11.5)),
  ]);
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 0.5, height: 32, color: kBorder,
    margin: const EdgeInsets.symmetric(horizontal: 20),
  );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: kAccentMid),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(color: kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(subtitle, style: GoogleFonts.inter(color: kText2, fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

// ─── Tab 2: Contexte ──────────────────────────────────────────────────────────
class _ContexteTab extends StatelessWidget {
  final String? content;
  final bool loading;
  const _ContexteTab({this.content, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const AppLoadingIndicator();
    if (content == null || content!.isEmpty) {
      return const AppEmptyState(
        icon: Icons.info_outline,
        title: 'Aucun contexte défini',
        subtitle: 'Ajoute un fichier context.md dans le dossier de la room sur GitHub.',
      );
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(
        padding: const EdgeInsets.all(16),
        child: _Markdown(content!),
      ),
    ]);
  }
}

// ─── Tab 3: Règles ────────────────────────────────────────────────────────────
class _ReglesTab extends StatefulWidget {
  final List<String> rules;
  final bool loading, saving, dirty;
  final ValueChanged<String> onAdd;
  final void Function(int, String) onEdit;
  final ValueChanged<int> onDelete;
  final VoidCallback onSave;

  const _ReglesTab({
    required this.rules, required this.loading, required this.saving, required this.dirty,
    required this.onAdd, required this.onEdit, required this.onDelete, required this.onSave,
  });

  @override State<_ReglesTab> createState() => _ReglesTabState();
}

class _ReglesTabState extends State<_ReglesTab> {
  int? _editing;
  final _ctrl = TextEditingController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  void _startEdit(int i) => setState(() { _editing = i; _ctrl.text = widget.rules[i]; });
  void _confirmEdit() {
    if (_editing == null) return;
    final t = _ctrl.text.trim();
    if (t.isNotEmpty) widget.onEdit(_editing!, t);
    setState(() => _editing = null);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const AppLoadingIndicator();
    return Column(children: [
      // Unsaved banner
      if (widget.dirty)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: kYellow.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kYellow.withValues(alpha: 0.25), width: 0.5),
          ),
          child: Row(children: [
            const Icon(Icons.edit_note, size: 14, color: kYellow),
            const SizedBox(width: 8),
            Expanded(child: Text('Modifications non sauvegardées', style: GoogleFonts.inter(color: kYellow, fontSize: 12.5))),
            AppButton(
              label: 'Sauvegarder',
              loading: widget.saving,
              onTap: widget.saving ? null : widget.onSave,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ]),
        ),
      Expanded(
        child: widget.rules.isEmpty
            ? const AppEmptyState(icon: Icons.rule_outlined, title: 'Aucune règle', subtitle: 'Ajoute ta première règle ci-dessous')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: widget.rules.length,
                itemBuilder: (_, i) {
                  if (_editing == i) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kAccent.withValues(alpha: 0.5), width: 1),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        TextField(
                          controller: _ctrl,
                          autofocus: true,
                          maxLines: null,
                          style: GoogleFonts.inter(color: kText, fontSize: 13.5),
                          cursorColor: kAccent,
                          cursorWidth: 1.5,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Contenu de la règle…',
                            hintStyle: GoogleFonts.inter(color: kMuted2),
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          AppButton(
                            label: 'Annuler',
                            variant: AppButtonVariant.ghost,
                            onTap: () => setState(() { _editing = null; _ctrl.clear(); }),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: 'Confirmer',
                            onTap: _confirmEdit,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ]),
                      ]),
                    );
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorder, width: 0.5),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(6)),
                        child: Center(child: Text('${i + 1}', style: GoogleFonts.inter(color: kAccentMid, fontSize: 11, fontWeight: FontWeight.w700))),
                      ),
                      title: Text(widget.rules[i],
                        style: GoogleFonts.inter(color: kText2, fontSize: 13.5, height: 1.5)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        GestureDetector(
                          onTap: () => _startEdit(i),
                          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: 15, color: kMuted2)),
                        ),
                        GestureDetector(
                          onTap: () => widget.onDelete(i),
                          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: 15, color: kRed)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _AddRuleBar(onAdd: widget.onAdd),
      ),
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

  void _submit() {
    final t = _c.text.trim();
    if (t.isNotEmpty) { widget.onAdd(t); _c.clear(); }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder, width: 0.5)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(children: [
      const Icon(Icons.add, size: 16, color: kMuted2),
      const SizedBox(width: 8),
      Expanded(child: TextField(
        controller: _c,
        maxLines: 1,
        onSubmitted: (_) => _submit(),
        style: GoogleFonts.inter(color: kText, fontSize: 13.5),
        cursorColor: kAccent,
        cursorWidth: 1.5,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Nouvelle règle…',
          hintStyle: GoogleFonts.inter(color: kMuted2),
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      )),
      AppButton(
        label: 'Ajouter',
        onTap: _submit,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      ),
    ]),
  );
}

// ─── Tab 4: Chat ──────────────────────────────────────────────────────────────
class _ChatTab extends StatefulWidget {
  final Room room;
  final List<ChatMessage> messages;
  final bool loading;
  final GitHubService github;
  final ValueChanged<ChatMessage> onSent;
  final void Function(String, Color) onSnack;

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
      final msg = ChatMessage(id: 'chat-$ts.md', sender: 'Moi', content: t, isUser: true, createdAt: DateTime.fromMillisecondsSinceEpoch(ts));
      _ctrl.clear();
      widget.onSent(msg);
      if (mounted) {
        setState(() => _sending = false);
        await Future.delayed(const Duration(milliseconds: 100));
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) { setState(() => _sending = false); widget.onSnack('Erreur: $e', kRed); }
    }
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const AppLoadingIndicator();
    final accent = widget.room.accentColor;
    return Column(children: [
      Expanded(child: widget.messages.isEmpty
          ? const AppEmptyState(icon: Icons.chat_bubble_outline, title: 'Aucun message', subtitle: 'Les agents et toi pouvez discuter ici')
          : ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: widget.messages.length,
              itemBuilder: (_, i) {
                final m = widget.messages[i];
                final isMe = m.isUser;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                      if (!isMe) Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 3),
                        child: Text(m.sender, style: GoogleFonts.inter(color: accent, fontSize: 10.5, fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: isMe ? accent : kCard,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isMe ? 14 : 3),
                            bottomRight: Radius.circular(isMe ? 3 : 14),
                          ),
                          border: isMe ? null : Border.all(color: kBorder, width: 0.5),
                        ),
                        child: Text(m.content, style: GoogleFonts.inter(color: isMe ? Colors.white : kText2, fontSize: 13.5, height: 1.4)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                        child: Text(_fmt(m.createdAt), style: GoogleFonts.inter(color: kMuted2, fontSize: 10)),
                      ),
                    ]),
                  ),
                );
              })),
      Container(
        decoration: const BoxDecoration(color: kBg, border: Border(top: BorderSide(color: kBorder, width: 0.5))),
        padding: EdgeInsets.only(left: 14, right: 14, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
        child: Row(children: [
          Expanded(child: Container(
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(22), border: Border.all(color: kBorder, width: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: TextField(
              controller: _ctrl,
              maxLines: 4, minLines: 1,
              onSubmitted: (_) => _send(),
              style: GoogleFonts.inter(color: kText, fontSize: 13.5),
              cursorColor: kAccent, cursorWidth: 1.5,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Envoyer un message…',
                hintStyle: GoogleFonts.inter(color: kMuted2),
                contentPadding: EdgeInsets.zero, isDense: true,
              ),
            ),
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: _sending
                  ? const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5)))
                  : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ─── Tab 5: Prompts ───────────────────────────────────────────────────────────
class _PromptTab extends StatefulWidget {
  final Room room;
  final List<_LocalPrompt> prompts;
  final bool loading;
  final GitHubService github;
  final ValueChanged<_LocalPrompt> onSent;
  final void Function(String, Color) onSnack;

  const _PromptTab({required this.room, required this.prompts, required this.loading, required this.github, required this.onSent, required this.onSnack});
  @override State<_PromptTab> createState() => _PromptTabState();
}

class _PromptTabState extends State<_PromptTab> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  List<AttachedFile> _files = [];

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AppDragHandle(),
          _AttachTileLocal(icon: Icons.folder_outlined, title: 'Fichiers', subtitle: 'Tout type de fichier', onTap: () { Navigator.pop(context); _pickFiles(); }),
          _AttachTileLocal(icon: Icons.photo_library_outlined, title: 'Galerie', subtitle: 'Photos et images', onTap: () { Navigator.pop(context); _pickFromGallery(); }),
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
            final n = f.name.toLowerCase();
            _files.insert(0, AttachedFile(name: f.name, bytes: f.bytes!,
              isImage: n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.gif') || n.endsWith('.webp')));
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _pickFromGallery() async {
    try {
      final imgs = await ImagePicker().pickMultiImage(imageQuality: 90);
      for (int i = 0; i < imgs.length; i++) {
        final bytes = await imgs[i].readAsBytes();
        if (mounted) setState(() => _files.insert(0, AttachedFile(name: imgs[i].name, bytes: bytes, isImage: true)));
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty && _files.isEmpty) return;
    if (!widget.github.hasPat) { widget.onSnack('Token requis', kYellow); return; }
    setState(() => _sending = true);
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final roomCtx = await widget.github.fetchContext(widget.room.id);
      final link = await widget.github.pushDirectPrompt(id, _ctrl.text, _files, room: widget.room, roomContext: roomCtx);
      final prompt = _LocalPrompt(text: _ctrl.text, link: link);
      _ctrl.clear();
      setState(() { _files = []; _sending = false; });
      widget.onSent(prompt);
      widget.onSnack('Prompt envoyé !', kGreen);
    } catch (e) {
      if (mounted) { setState(() => _sending = false); widget.onSnack('Erreur: $e', kRed); }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const AppLoadingIndicator();
    return Column(children: [
      Expanded(child: widget.prompts.isEmpty
          ? const AppEmptyState(icon: Icons.article_outlined, title: 'Aucun prompt', subtitle: 'Envoie le premier prompt ci-dessous')
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: widget.prompts.length,
              itemBuilder: (_, i) {
                final p = widget.prompts[i];
                return AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.article_outlined, size: 15, color: kAccentMid),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.text, style: GoogleFonts.inter(color: kText2, fontSize: 13, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
                      if (p.link.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: p.link));
                            widget.onSnack('Lien copié !', kGreen);
                          },
                          child: Text(p.link, style: GoogleFonts.robotoMono(color: kBlue, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ])),
                  ]),
                );
              })),
      // Input bar
      Container(
        decoration: const BoxDecoration(color: kBg, border: Border(top: BorderSide(color: kBorder, width: 0.5))),
        padding: EdgeInsets.only(left: 14, right: 14, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_files.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _files.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final f = _files[i];
                  return Stack(children: [
                    f.isImage
                        ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(f.bytes, width: 56, height: 56, fit: BoxFit.cover))
                        : Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(6), border: Border.all(color: kBorder, width: 0.5)),
                            child: const Icon(Icons.insert_drive_file_outlined, color: kAccentMid, size: 20)),
                    Positioned(
                      top: 2, right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _files.removeAt(i)),
                        child: Container(
                          width: 14, height: 14,
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 9, color: Colors.white),
                        ),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          Row(children: [
            GestureDetector(
              onTap: _showAttachMenu,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
                child: const Icon(Icons.add, size: 18, color: kMuted2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(
              decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(22), border: Border.all(color: kBorder, width: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: TextField(
                controller: _ctrl,
                maxLines: 4, minLines: 1,
                style: GoogleFonts.inter(color: kText, fontSize: 13.5),
                cursorColor: kAccent, cursorWidth: 1.5,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Nouveau prompt…',
                  hintStyle: GoogleFonts.inter(color: kMuted2),
                  contentPadding: EdgeInsets.zero, isDense: true,
                ),
              ),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: widget.room.accentColor, shape: BoxShape.circle),
                child: _sending
                    ? const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5)))
                    : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }
}

class _AttachTileLocal extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AttachTileLocal({required this.icon, required this.title, required this.subtitle, required this.onTap});

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

// ─── _Markdown (simple renderer) ─────────────────────────────────────────────
class _Markdown extends StatelessWidget {
  final String content;
  const _Markdown(this.content);

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((l) {
        if (l.startsWith('# ')) return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.substring(2), style: GoogleFonts.inter(color: kText, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4)));
        if (l.startsWith('## ')) return Padding(padding: const EdgeInsets.only(bottom: 6, top: 4), child: Text(l.substring(3), style: GoogleFonts.inter(color: kText, fontSize: 15, fontWeight: FontWeight.w600)));
        if (l.startsWith('### ')) return Padding(padding: const EdgeInsets.only(bottom: 4, top: 2), child: Text(l.substring(4), style: GoogleFonts.inter(color: kText2, fontSize: 13.5, fontWeight: FontWeight.w600)));
        if (l.startsWith('- ') || l.startsWith('* ')) return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 6, right: 8), decoration: BoxDecoration(color: kAccentMid, shape: BoxShape.circle)),
            Expanded(child: Text(l.substring(2), style: GoogleFonts.inter(color: kText2, fontSize: 13, height: 1.5))),
          ]),
        );
        if (l.startsWith('`') && l.endsWith('`') && l.length > 2) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: kBorder, width: 0.5)),
            child: Text(l.substring(1, l.length - 1), style: GoogleFonts.robotoMono(color: kAccentMid, fontSize: 12)),
          );
        }
        if (l.trim().isEmpty) return const SizedBox(height: 6);
        return Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l, style: GoogleFonts.inter(color: kText2, fontSize: 13.5, height: 1.55)));
      }).toList(),
    );
  }
}

// ─── _LocalPrompt ─────────────────────────────────────────────────────────────
class _LocalPrompt {
  final String text;
  final String link;
  const _LocalPrompt({required this.text, required this.link});
}