import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/github_service.dart';
import '../services/prefs_service.dart';
import '../models/saved_prompt.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class ShellScreen extends StatefulWidget {
  final GitHubService github;
  const ShellScreen({super.key, required this.github});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  List<SavedPrompt> _prompts = [];

  @override
  void initState() {
    super.initState();
    _loadPrompts();
  }

  Future<void> _loadPrompts() async {
    final list = await PrefsService.getPrompts();
    if (mounted) setState(() => _prompts = list);
  }

  void _onPromptSaved(SavedPrompt p) {
    setState(() => _prompts.insert(0, p));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, size: 22, color: Color(0xFFAAAAAA)),
          onPressed: () => Scaffold.of(ctx).openDrawer())),
        title: const Text('AgentBase',
          style: TextStyle(color: Color(0xFFECECEC), fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.code, color: Color(0xFFAAAAAA), size: 20),
            tooltip: 'GitHub',
            onPressed: () => launchUrl(
              Uri.parse('https://github.com/ferelking242/agentbase'),
              mode: LaunchMode.externalApplication),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: Color(0xFF1A1A1A))),
      ),
      drawer: _Drawer(
        prompts: _prompts,
        onSettings: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SettingsScreen(github: widget.github)));
        },
        onShowPrompts: () {
          Navigator.pop(context);
          _showPromptsSheet();
        },
        onDeletePrompt: (id) async {
          await PrefsService.deletePrompt(id);
          if (mounted) setState(() => _prompts.removeWhere((p) => p.id == id));
        },
      ),
      body: HomeScreen(
        github: widget.github,
        onSection: (_) {},
        onPromptSaved: _onPromptSaved,
      ),
    );
  }

  void _showPromptsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => StatefulBuilder(builder: (ctx, setInner) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.4,
          expand: false,
          builder: (_, ctrl) => Column(children: [
            Container(margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                const Text('Prompts sauvegardes',
                  style: TextStyle(color: Color(0xFFECECEC), fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${_prompts.length}', style: const TextStyle(color: Color(0xFF666666), fontSize: 13)),
              ])),
            const Divider(color: Color(0xFF1A1A1A), height: 0.5),
            Expanded(
              child: _prompts.isEmpty
                ? const Center(child: Text('Aucun prompt sauvegarde',
                    style: TextStyle(color: Color(0xFF444444), fontSize: 14)))
                : ListView.builder(
                    controller: ctrl,
                    itemCount: _prompts.length,
                    itemBuilder: (_, i) => _PromptListItem(
                      prompt: _prompts[i],
                      onDelete: () async {
                        await PrefsService.deletePrompt(_prompts[i].id);
                        setState(() => _prompts.removeAt(i));
                        setInner(() {});
                      }),
                  )),
          ]),
        );
      }),
    );
  }
}

// ── Drawer ──────────────────────────────────────────────────────────────────
class _Drawer extends StatelessWidget {
  final List<SavedPrompt> prompts;
  final VoidCallback onSettings, onShowPrompts;
  final void Function(String id) onDeletePrompt;
  const _Drawer({required this.prompts, required this.onSettings, required this.onShowPrompts, required this.onDeletePrompt});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A), width: 0.5))),
          child: Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.bolt, size: 18, color: Colors.white)),
            const SizedBox(width: 10),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AgentBase', style: TextStyle(color: Color(0xFFECECEC), fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              Text('ferelking242', style: TextStyle(color: Color(0xFF555555), fontSize: 11)),
            ]),
          ])),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
          child: Row(children: [
            const Text('PROMPTS', style: TextStyle(color: Color(0xFF555555), fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const Spacer(),
            if (prompts.isNotEmpty) Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(10)),
              child: Text('${prompts.length}', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w700))),
          ])),
        _NavItem(
          icon: Icons.list_alt_outlined,
          label: 'Voir tous les prompts',
          sel: false,
          badge: prompts.isNotEmpty ? '${prompts.length}' : null,
          onTap: onShowPrompts,
        ),
        if (prompts.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...prompts.take(3).map((p) => _PromptSidebarItem(
            prompt: p,
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: p.link));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Lien copie !'),
                duration: Duration(seconds: 1),
                backgroundColor: Color(0xFF14532D)));
            })),
        ],
        const Spacer(),
        const Divider(color: Color(0xFF1A1A1A), height: 0.5),
        _NavItem(icon: Icons.settings_outlined, label: 'Parametres', sel: false, onTap: onSettings),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool sel;
  final String? badge;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.sel, required this.onTap, this.badge});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: sel ? const Color(0xFF1A1A2A) : Colors.transparent,
        borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, size: 16, color: sel ? const Color(0xFF818CF8) : const Color(0xFF666666)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(
          color: sel ? const Color(0xFFECECEC) : const Color(0xFF999999),
          fontSize: 13.5, fontWeight: sel ? FontWeight.w600 : FontWeight.w400))),
        if (badge != null) Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(10)),
          child: Text(badge!, style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
    ),
  );
}

class _PromptSidebarItem extends StatelessWidget {
  final SavedPrompt prompt;
  final VoidCallback onCopy;
  const _PromptSidebarItem({required this.prompt, required this.onCopy});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    child: Row(children: [
      const SizedBox(width: 10),
      const Icon(Icons.article_outlined, size: 14, color: Color(0xFF444466)),
      const SizedBox(width: 8),
      Expanded(child: Text(prompt.name,
        style: const TextStyle(color: Color(0xFF777799), fontSize: 12.5),
        maxLines: 1, overflow: TextOverflow.ellipsis)),
      IconButton(
        icon: const Icon(Icons.copy, size: 13, color: Color(0xFF444466)),
        onPressed: onCopy,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      ),
    ]),
  );
}

// ── Prompt list item ─────────────────────────────────────────────────────────
class _PromptListItem extends StatefulWidget {
  final SavedPrompt prompt;
  final VoidCallback onDelete;
  const _PromptListItem({required this.prompt, required this.onDelete});
  @override State<_PromptListItem> createState() => _PromptListItemState();
}
class _PromptListItemState extends State<_PromptListItem> {
  bool _copied = false;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF141414),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF222222))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.article_outlined, size: 16, color: Color(0xFF6366F1)),
        const SizedBox(width: 8),
        Expanded(child: Text(widget.prompt.name,
          style: const TextStyle(color: Color(0xFFECECEC), fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF444444)),
          onPressed: widget.onDelete,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
      ]),
      const SizedBox(height: 4),
      Text('ID: ${widget.prompt.id}', style: const TextStyle(color: Color(0xFF444466), fontSize: 10)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(8)),
        child: Text(widget.prompt.link,
          style: const TextStyle(color: Color(0xFF5A7A9A), fontSize: 11, fontFamily: 'monospace'),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
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
            backgroundColor: _copied ? const Color(0xFF14532D) : const Color(0xFF1A2A3A),
            foregroundColor: _copied ? const Color(0xFF22C55E) : const Color(0xFF93C5FD),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0),
        )),
    ]),
  );
}
