import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/saved_prompt.dart';
import '../services/github_service.dart';
import '../services/prefs_service.dart';
import '../theme.dart';
import '../widgets/app_components.dart';
import 'prompt_detail_screen.dart';

class PromptsScreen extends StatefulWidget {
  final GitHubService github;
  const PromptsScreen({super.key, required this.github});

  @override
  State<PromptsScreen> createState() => _PromptsScreenState();
}

enum _SortMode { newest, oldest }
enum _DateFilter { all, today, week, month }

class _PromptsScreenState extends State<PromptsScreen> {
  final _search = TextEditingController();
  _SortMode _sort = _SortMode.newest;
  _DateFilter _dateFilter = _DateFilter.all;
  bool _syncing = false;
  bool _loading = true;
  List<SavedPrompt> _local = [];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadFromPrefs();
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _loadFromPrefs() async {
    final list = await PrefsService.getPrompts();
    if (mounted) setState(() { _local = list; _loading = false; });
  }

  List<SavedPrompt> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final now = DateTime.now();
    return _local.where((p) {
      if (q.isNotEmpty && !p.name.toLowerCase().contains(q) && !p.id.contains(q)) return false;
      switch (_dateFilter) {
        case _DateFilter.today:
          return p.created.day == now.day && p.created.month == now.month && p.created.year == now.year;
        case _DateFilter.week:
          return now.difference(p.created).inDays < 7;
        case _DateFilter.month:
          return now.difference(p.created).inDays < 30;
        case _DateFilter.all:
          return true;
      }
    }).toList()
      ..sort((a, b) => _sort == _SortMode.newest
          ? b.created.compareTo(a.created)
          : a.created.compareTo(b.created));
  }

  Future<void> _sync() async {
    if (!widget.github.hasPat) {
      showAppSnack(context, 'Configure ton token dans Paramètres', isError: true);
      return;
    }
    setState(() => _syncing = true);
    try {
      final remote   = await widget.github.fetchRemotePrompts();
      final local    = await PrefsService.getPrompts();
      final localIds = local.map((p) => p.id).toSet();
      final newOnes  = remote.where((p) => !localIds.contains(p.id)).toList();
      for (final p in newOnes) await PrefsService.addPrompt(p);
      final updated = await PrefsService.getPrompts();
      if (!mounted) return;
      setState(() { _syncing = false; _local = updated; });
      showAppSnack(context, newOnes.isEmpty
        ? 'Déjà à jour (${updated.length} prompts)'
        : '+${newOnes.length} prompt${newOnes.length > 1 ? "s" : ""} synchronisé${newOnes.length > 1 ? "s" : ""}');
    } catch (e) {
      if (mounted) { setState(() => _syncing = false); showAppSnack(context, 'Erreur: $e', isError: true); }
    }
  }

  Future<void> _delete(SavedPrompt p) async {
    await PrefsService.deletePrompt(p.id);
    setState(() => _local.removeWhere((x) => x.id == p.id));
  }

  Future<void> _openDetail(SavedPrompt p) async {
    final result = await Navigator.push<PromptDetailResult>(
      context,
      MaterialPageRoute(builder: (_) => PromptDetailScreen(prompt: p, github: widget.github)),
    );
    if (result == null) return;
    if (result.deleted) {
      await _delete(p);
    } else if (result.newName != null && result.newName != p.name) {
      await PrefsService.updatePromptName(p.id, result.newName!);
      setState(() {
        final idx = _local.indexWhere((x) => x.id == p.id);
        if (idx != -1) _local[idx] = p.copyWith(name: result.newName);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          _Header(
            count: _local.length,
            syncing: _syncing,
            onSync: _sync,
            onBack: () => Navigator.pop(context),
          ),

          // Search + filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(children: [
              // Search
              Container(
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder, width: 0.5),
                ),
                child: TextField(
                  controller: _search,
                  style: GoogleFonts.inter(color: kText, fontSize: 14),
                  cursorColor: kAccent,
                  cursorWidth: 1.5,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un prompt…',
                    hintStyle: GoogleFonts.inter(color: kMuted2, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, size: 18, color: kMuted2),
                    suffixIcon: _search.text.isNotEmpty
                        ? GestureDetector(onTap: _search.clear, child: const Icon(Icons.close, size: 16, color: kMuted2))
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Sort + date filter
              Row(children: [
                // Sort toggle
                _FilterBtn(
                  label: _sort == _SortMode.newest ? '↓ Récent' : '↑ Ancien',
                  active: false,
                  onTap: () => setState(() => _sort = _sort == _SortMode.newest ? _SortMode.oldest : _SortMode.newest),
                ),
                const SizedBox(width: 6),
                // Date filters
                ..._DateFilter.values.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterBtn(
                    label: _filterLabel(f),
                    active: _dateFilter == f,
                    onTap: () => setState(() => _dateFilter = f),
                  ),
                )),
              ]),
            ]),
          ),
          const SizedBox(height: 10),

          // List
          Expanded(
            child: _loading
                ? const AppLoadingIndicator()
                : filtered.isEmpty
                ? _local.isEmpty
                    ? AppEmptyState(
                        icon: Icons.article_outlined,
                        title: 'Aucun prompt',
                        subtitle: widget.github.hasPat ? 'Appuie sur Sync pour récupérer' : 'Configure ton token dans Paramètres',
                      )
                    : const AppEmptyState(
                        icon: Icons.search_off,
                        title: 'Aucun résultat',
                        subtitle: 'Essaie d\'autres filtres',
                      )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _PromptCard(
                      prompt: filtered[i],
                      github: widget.github,
                      onTap: () => _openDetail(filtered[i]),
                      onDelete: () => _delete(filtered[i]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  String _filterLabel(_DateFilter f) {
    switch (f) {
      case _DateFilter.all:   return 'Tout';
      case _DateFilter.today: return 'Auj.';
      case _DateFilter.week:  return '7 jours';
      case _DateFilter.month: return '30 jours';
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int count;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onBack;

  const _Header({required this.count, required this.syncing, required this.onSync, required this.onBack});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
    child: Row(children: [
      GestureDetector(
        onTap: onBack,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
          child: const Icon(Icons.arrow_back_ios_new, size: 13, color: kMuted),
        ),
      ),
      const SizedBox(width: 12),
      Text('Prompts', style: GoogleFonts.inter(color: kText, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
      const SizedBox(width: 8),
      if (count > 0) AppBadge('$count'),
      const Spacer(),
      GestureDetector(
        onTap: syncing ? null : onSync,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
          child: syncing
              ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: kAccent)))
              : const Icon(Icons.sync_rounded, size: 17, color: kMuted),
        ),
      ),
    ]),
  );
}

// ── FilterBtn ─────────────────────────────────────────────────────────────────
class _FilterBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: active ? kAccentSub : kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? kAccentMid.withValues(alpha: 0.4) : kBorder, width: active ? 1 : 0.5),
      ),
      child: Text(label, style: GoogleFonts.inter(
        color: active ? kAccentMid : kMuted,
        fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
      )),
    ),
  );
}

// ── Prompt Card ───────────────────────────────────────────────────────────────
class _PromptCard extends StatefulWidget {
  final SavedPrompt prompt;
  final GitHubService github;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _PromptCard({required this.prompt, required this.github, required this.onTap, required this.onDelete});
  @override State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  bool _copiedLink = false;
  bool _copiedMd   = false;
  bool _loadingMd  = false;

  Future<void> _copyMd() async {
    if (_loadingMd) return;
    setState(() => _loadingMd = true);
    try {
      final content = await widget.github.fetchPromptContent(widget.prompt.id);
      if (!mounted) return;
      if (content == null) { showAppSnack(context, 'Introuvable sur GitHub', isError: true); setState(() => _loadingMd = false); return; }
      await Clipboard.setData(ClipboardData(text: content));
      setState(() { _loadingMd = false; _copiedMd = true; });
      Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copiedMd = false); });
    } catch (_) { if (mounted) setState(() => _loadingMd = false); }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prompt;
    final num = p.number > 0 ? p.number : null;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder, width: 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (num != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(6)),
                  child: Text('#$num', style: GoogleFonts.inter(color: kAccentMid, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
              ] else ...[
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
                  child: const Icon(Icons.article_outlined, size: 15, color: kMuted2),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(p.name,
                style: GoogleFonts.inter(color: kText, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onDelete,
                child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.close, size: 14, color: kMuted2)),
              ),
            ]),
          ),

          // Meta row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(children: [
              _MetaChip(icon: Icons.fingerprint, label: p.id.length > 16 ? p.id.substring(0, 16) : p.id),
              const SizedBox(width: 8),
              _MetaChip(icon: Icons.calendar_today_outlined, label: _fmtDate(p.created)),
              const SizedBox(width: 8),
              _MetaChip(icon: Icons.access_time_outlined, label: _fmtTime(p.created)),
            ]),
          ),

          // Link
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: kBorder, width: 0.5)),
              child: Row(children: [
                const Icon(Icons.link, size: 12, color: kMuted2),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  p.link.replaceFirst('https://raw.githubusercontent.com/', ''),
                  style: GoogleFonts.robotoMono(color: kBlue, fontSize: 10.5),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                )),
              ]),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(children: [
              _ActionBtn(
                label: _copiedLink ? 'Copié !' : 'Lien',
                icon: _copiedLink ? Icons.check : Icons.link_outlined,
                active: _copiedLink,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: p.link));
                  setState(() => _copiedLink = true);
                  Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copiedLink = false); });
                },
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                label: _copiedMd ? 'Copié !' : 'Contenu MD',
                icon: _copiedMd ? Icons.check : Icons.content_copy_outlined,
                active: _copiedMd,
                loading: _loadingMd,
                onTap: _loadingMd ? null : _copyMd,
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                label: 'Voir',
                icon: Icons.open_in_new_rounded,
                active: false,
                onTap: widget.onTap,
                expand: false,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 11, color: kMuted2),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.robotoMono(color: kMuted2, fontSize: 10.5)),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool loading;
  final VoidCallback? onTap;
  final bool expand;

  const _ActionBtn({required this.label, required this.icon, required this.active, this.loading = false, this.onTap, this.expand = true});

  @override
  Widget build(BuildContext context) {
    final w = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? kGreenSub.withValues(alpha: 0.5) : kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? kGreen.withValues(alpha: 0.3) : kBorder, width: active ? 1 : 0.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: kAccent))
          else ...[
            Icon(icon, size: 13, color: active ? kGreen : kMuted),
            const SizedBox(width: 5),
            Text(label, style: GoogleFonts.inter(color: active ? kGreen : kMuted, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ]),
      ),
    );
    if (!expand) return w;
    return Expanded(child: w);
  }
}

