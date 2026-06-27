import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/github_service.dart';
import '../services/prefs_service.dart';
import '../theme.dart';
import '../widgets/app_components.dart';

class SettingsScreen extends StatefulWidget {
  final GitHubService? github;
  final void Function(GitHubService) onSaved;

  const SettingsScreen({super.key, this.github, required this.onSaved});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _tokenCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _repoCtrl  = TextEditingController();
  final _branchCtrl = TextEditingController();
  bool _showToken = false;
  bool _saving = false;
  bool _testing = false;
  bool _testPassed = false;
  String? _testError;

  @override
  void initState() {
    super.initState();
    final g = widget.github;
    if (g != null) {
      _tokenCtrl.text  = g.token;
      _ownerCtrl.text  = g.owner;
      _repoCtrl.text   = g.repo;
      _branchCtrl.text = g.branch;
    } else {
      _branchCtrl.text = 'main';
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose(); _ownerCtrl.dispose(); _repoCtrl.dispose(); _branchCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final g = widget.github;
    if (g == null) return true;
    return _tokenCtrl.text != g.token || _ownerCtrl.text != g.owner ||
        _repoCtrl.text != g.repo || _branchCtrl.text != g.branch;
  }

  bool get _isConfigured =>
      _tokenCtrl.text.isNotEmpty && _ownerCtrl.text.isNotEmpty && _repoCtrl.text.isNotEmpty;

  Future<void> _testConnection() async {
    if (!_isConfigured) {
      showAppSnack(context, 'Remplis tous les champs d\'abord', isError: true);
      return;
    }
    setState(() { _testing = true; _testPassed = false; _testError = null; });
    try {
      final g = GitHubService(
        token: _tokenCtrl.text.trim(),
        owner: _ownerCtrl.text.trim(),
        repo: _repoCtrl.text.trim(),
        branch: _branchCtrl.text.trim().isEmpty ? 'main' : _branchCtrl.text.trim(),
      );
      await g.syncPrompts();
      setState(() { _testing = false; _testPassed = true; });
      showAppSnack(context, 'Connexion réussie !');
    } catch (e) {
      setState(() { _testing = false; _testError = e.toString().replaceAll('Exception: ', ''); });
      showAppSnack(context, _testError!, isError: true);
    }
  }

  Future<void> _save() async {
    if (!_isConfigured) {
      showAppSnack(context, 'Token, owner et repo sont requis', isError: true);
      return;
    }
    setState(() => _saving = true);
    final g = GitHubService(
      token: _tokenCtrl.text.trim(),
      owner: _ownerCtrl.text.trim(),
      repo: _repoCtrl.text.trim(),
      branch: _branchCtrl.text.trim().isEmpty ? 'main' : _branchCtrl.text.trim(),
    );
    await PrefsService.saveGitHub(token: g.token, owner: g.owner, repo: g.repo, branch: g.branch);
    setState(() => _saving = false);
    widget.onSaved(g);
    if (mounted) showAppSnack(context, 'Paramètres sauvegardés');
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = widget.github != null;
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 34, height: 34, decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
                  child: const Icon(Icons.arrow_back_ios_new, size: 13, color: kMuted)),
              ),
              const SizedBox(width: 12),
              Text('Paramètres', style: GoogleFonts.inter(color: kText, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
              const Spacer(),
              if (_hasChanges)
                AppButton(
                  label: 'Sauvegarder',
                  loading: _saving,
                  onTap: _saving ? null : _save,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
            ]),
          ),

          Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [

            // Status card
            AppCard(
              padding: const EdgeInsets.all(14),
              color: isConfigured ? kGreenSub.withOpacity(0.4) : kRedSub.withOpacity(0.3),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isConfigured ? kGreen.withOpacity(0.15) : kRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    isConfigured ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                    size: 18, color: isConfigured ? kGreen : kRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    isConfigured ? 'GitHub connecté' : 'Non configuré',
                    style: GoogleFonts.inter(color: kText, fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  if (isConfigured)
                    Text(
                      '${widget.github!.owner}/${widget.github!.repo} · ${widget.github!.branch}',
                      style: GoogleFonts.inter(color: kMuted2, fontSize: 12),
                    )
                  else
                    Text('Configure ton token GitHub pour commencer', style: GoogleFonts.inter(color: kMuted2, fontSize: 12)),
                ])),
                if (isConfigured) ...[
                  const SizedBox(width: 8),
                  if (_testPassed)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: kGreenSub, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.check, size: 14, color: kGreen)),
                ],
              ]),
            ),
            const SizedBox(height: 20),

            // GitHub token
            const AppSectionHeader('GitHub Token'),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 30, height: 30, decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.vpn_key_outlined, size: 15, color: kAccentMid)),
                  const SizedBox(width: 10),
                  Text('Personal Access Token', style: GoogleFonts.inter(color: kText, fontSize: 13.5, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showToken = !_showToken),
                    child: Text(_showToken ? 'Masquer' : 'Afficher', style: GoogleFonts.inter(color: kAccentMid, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 12),
                AppInput(
                  controller: _tokenCtrl,
                  hint: 'ghp_xxxxxxxxxxxx',
                  obscure: !_showToken,
                  onChanged: (_) => setState(() { _testPassed = false; _testError = null; }),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.info_outline, size: 13, color: kMuted2),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Nécessite les scopes: repo, contents:write', style: GoogleFonts.inter(color: kMuted2, fontSize: 11.5))),
                ]),
              ]),
            ),
            const SizedBox(height: 10),

            // Repo config
            const AppSectionHeader('Dépôt GitHub'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _FieldRow(
                  icon: Icons.person_outline,
                  label: 'Owner',
                  hint: 'ton-username',
                  controller: _ownerCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const AppDivider(),
                _FieldRow(
                  icon: Icons.folder_outlined,
                  label: 'Repository',
                  hint: 'agentbase',
                  controller: _repoCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const AppDivider(),
                _FieldRow(
                  icon: Icons.account_tree_outlined,
                  label: 'Branch',
                  hint: 'main',
                  controller: _branchCtrl,
                  onChanged: (_) => setState(() {}),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Test connection
            AppButton(
              label: _testing ? 'Test en cours…' : (_testPassed ? 'Connexion OK ✓' : 'Tester la connexion'),
              icon: _testPassed ? Icons.check_circle_outline : Icons.wifi_tethering,
              variant: _testPassed ? AppButtonVariant.secondary : AppButtonVariant.outline,
              loading: _testing,
              fullWidth: true,
              onTap: (_testing || !_isConfigured) ? null : _testConnection,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            if (_testError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: kRedSub.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: kRed.withOpacity(0.2), width: 0.5)),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 14, color: kRed),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_testError!, style: GoogleFonts.inter(color: kRed, fontSize: 12))),
                ]),
              ),
            ],
            const SizedBox(height: 20),

            // About section
            const AppSectionHeader('Application'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _InfoRow(icon: Icons.info_outline, label: 'Version', value: '3.0.0'),
                const AppDivider(),
                _InfoRow(icon: Icons.bolt, label: 'AgentBase', value: 'Interface prompts IA'),
                const AppDivider(),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Container(width: 30, height: 30, decoration: BoxDecoration(color: kAccentSub, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.content_copy, size: 14, color: kAccentMid)),
                  title: Text('Copier owner/repo', style: GoogleFonts.inter(color: kText, fontSize: 13.5)),
                  trailing: const Icon(Icons.chevron_right, size: 16, color: kMuted2),
                  onTap: () {
                    final text = '${_ownerCtrl.text}/${_repoCtrl.text}';
                    if (text != '/') {
                      Clipboard.setData(ClipboardData(text: text));
                      showAppSnack(context, 'Copié : $text');
                    }
                  },
                ),
              ]),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ])),
        ]),
      ),
    );
  }
}

// ── _FieldRow ─────────────────────────────────────────────────────────────────
class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label, hint;
  final TextEditingController controller;
  final void Function(String)? onChanged;
  const _FieldRow({required this.icon, required this.label, required this.hint, required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      Container(width: 30, height: 30, decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: kMuted)),
      const SizedBox(width: 10),
      SizedBox(width: 90, child: Text(label, style: GoogleFonts.inter(color: kMuted, fontSize: 13))),
      Expanded(child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(color: kText, fontSize: 13.5),
        cursorColor: kAccent, cursorWidth: 1.5,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: kMuted2, fontSize: 13),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        textAlign: TextAlign.end,
      )),
    ]),
  );
}

// ── _InfoRow ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      Container(width: 30, height: 30, decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: kMuted)),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.inter(color: kMuted, fontSize: 13)),
      const Spacer(),
      Text(value, style: GoogleFonts.inter(color: kText2, fontSize: 13, fontWeight: FontWeight.w500)),
    ]),
  );
}
