import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pat = await PrefsService.getPat();
    if (pat != null && mounted) {
      _patCtrl.text = pat;
    }
  }

  Future<void> _validate() async {
    final pat = _patCtrl.text.trim();
    if (pat.isEmpty) return;
    setState(() { _validating = true; _patValid = null; });
    widget.github.setPat(pat);
    await PrefsService.savePat(pat);
    final ok = await widget.github.validatePat();
    if (mounted) setState(() { _validating = false; _patValid = ok; });
  }

  Future<void> _clear() async {
    _patCtrl.clear();
    widget.github.setPat('');
    await PrefsService.clearPat();
    if (mounted) setState(() => _patValid = null);
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Paramètres'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('GitHub Token (PAT)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _patValid == true
                      ? kGreen.withOpacity(0.4)
                      : _patValid == false
                          ? kRed.withOpacity(0.4)
                          : kBorder,
                ),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _patCtrl,
                    obscureText: !_patVisible,
                    style: const TextStyle(
                      color: kText,
                      fontSize: 12.5,
                      fontFamily: 'Courier',
                    ),
                    decoration: InputDecoration(
                      hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _patVisible = !_patVisible),
                        child: Icon(
                          _patVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 16,
                          color: kMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_patValid != null) ...[
                        Icon(
                          _patValid! ? Icons.check_circle_outline : Icons.cancel_outlined,
                          size: 14,
                          color: _patValid! ? kGreen : kRed,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _patValid! ? 'Token valide' : 'Token invalide',
                          style: TextStyle(
                            color: _patValid! ? kGreen : kRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                      ] else
                        const Spacer(),
                      GestureDetector(
                        onTap: _clear,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: kSurface2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kBorder),
                          ),
                          child: const Text('Effacer',
                            style: TextStyle(color: kMuted2, fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _validating ? null : _validate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: kAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _validating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Valider',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  )),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Votre PAT est stocké localement sur l\'appareil. Il est nécessaire pour publier des prompts sur GitHub.',
              style: TextStyle(color: kMuted, fontSize: 11.5, height: 1.5),
            ),
            const SizedBox(height: 28),
            _sectionLabel('Dépôt cible'),
            const SizedBox(height: 8),
            _infoRow('Owner', 'ferelking242'),
            const SizedBox(height: 6),
            _infoRow('Repo', 'agentbase'),
            const SizedBox(height: 6),
            _infoRow('Branch', 'main'),
            const SizedBox(height: 28),
            _sectionLabel('À propos'),
            const SizedBox(height: 8),
            _infoRow('App', 'AgentBase Mobile'),
            const SizedBox(height: 6),
            _infoRow('Version', '1.0.0'),
            const SizedBox(height: 6),
            _infoRow('iOS', '15.0+'),
            const SizedBox(height: 6),
            _infoRow('Android', '6.0+'),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label.toUpperCase(),
      style: const TextStyle(
        color: kMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ));
  }

  Widget _infoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: kMuted2, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(
            color: kText, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Courier')),
        ],
      ),
    );
  }
}
