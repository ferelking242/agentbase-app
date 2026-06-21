import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import '../services/github_service.dart';
  import '../services/prefs_service.dart';
  import '../theme.dart';

  class SettingsScreen extends StatefulWidget {
    final GitHubService github;
    const SettingsScreen({super.key, required this.github});
    @override
    State<SettingsScreen> createState() => _SettingsScreenState();
  }

  class _SettingsScreenState extends State<SettingsScreen> {
    final _patCtrl = TextEditingController();
    bool _patVisible = false;
    bool _validating = false;
    bool? _patValid;
    bool _saved = false;

    @override
    void initState() {
      super.initState();
      _load();
    }

    @override
    void dispose() {
      _patCtrl.dispose();
      super.dispose();
    }

    Future<void> _load() async {
      final pat = await PrefsService.getPat();
      if (pat != null && mounted) { _patCtrl.text = pat; setState(() {}); }
    }

    Future<void> _validate() async {
      final pat = _patCtrl.text.trim();
      if (pat.isEmpty) return;
      setState(() { _validating = true; _patValid = null; _saved = false; });
      widget.github.setPat(pat);
      await PrefsService.savePat(pat);
      final ok = await widget.github.validatePat();
      if (mounted) setState(() { _validating = false; _patValid = ok; _saved = true; });
    }

    Future<void> _clear() async {
      _patCtrl.clear();
      widget.github.setPat('');
      await PrefsService.clearPat();
      if (mounted) setState(() { _patValid = null; _saved = false; });
    }

    @override
    Widget build(BuildContext context) {
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
                border: Border.all(color: kBorder)),
              child: const Icon(Icons.arrow_back_ios_new, size: 14, color: kText2),
            ),
          ),
          title: const Text('Paramètres', style: TextStyle(
            color: kText, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: kBorder)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _label('GitHub Token (PAT)'),
            const SizedBox(height: 4),
            const Text('Nécessaire pour créer et lire les prompts dans le dépôt.',
              style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
            const SizedBox(height: 12),
            _patField(),
            const SizedBox(height: 28),
            _label('Dépôt AgentBase'),
            const SizedBox(height: 12),
            _infoRow('Owner', 'ferelking242'),
            _infoRow('Repo', 'agentbase'),
            _infoRow('API', 'https://ferelking242.github.io/agentbase/api/v1'),
            const SizedBox(height: 28),
            _label('App'),
            const SizedBox(height: 12),
            _infoRow('Version', '2.0.0'),
            _infoRow('Plateforme', 'iOS & Android'),
          ],
        ),
      );
    }

    Widget _label(String text) {
      return Text(text, style: const TextStyle(
        color: kMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.08));
    }

    Widget _patField() {
      Color borderColor = kBorder;
      if (_patValid == true) borderColor = kGreen;
      if (_patValid == false) borderColor = kRed;

      return Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _patCtrl,
                    obscureText: !_patVisible,
                    style: const TextStyle(color: kText, fontSize: 13, fontFamily: 'Courier'),
                    decoration: InputDecoration(
                      hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
                      hintStyle: const TextStyle(color: kMuted, fontFamily: 'Courier'),
                      border: InputBorder.none, isDense: true,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _patVisible = !_patVisible),
                        child: Icon(_patVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 16, color: kMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_patValid != null)
                  Row(
                    children: [
                      Icon(_patValid! ? Icons.check_circle_outline : Icons.error_outline,
                        size: 14, color: _patValid! ? kGreen : kRed),
                      const SizedBox(width: 5),
                      Text(_patValid! ? 'Token valide' : 'Token invalide',
                        style: TextStyle(color: _patValid! ? kGreen : kRed, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                const Spacer(),
                if (_patCtrl.text.isNotEmpty)
                  GestureDetector(
                    onTap: _clear,
                    child: const Text('Effacer', style: TextStyle(color: kMuted, fontSize: 12)),
                  ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _validating ? null : _validate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: kAccent, borderRadius: BorderRadius.circular(8)),
                    child: _validating
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                      : const Text('Valider', style: TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget _infoRow(String label, String value) {
      return Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: kMuted2, fontSize: 13)),
            const Spacer(),
            Flexible(child: Text(value, style: const TextStyle(
              color: kText2, fontSize: 12, fontFamily: 'Courier'),
              textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
    }
  }