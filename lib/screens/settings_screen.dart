import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/github_service.dart';
import '../services/prefs_service.dart';
import '../theme.dart';
import '../widgets/app_components.dart';

class SettingsScreen extends StatefulWidget {
  final GitHubService github;
  const SettingsScreen({super.key, required this.github});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _patCtrl = TextEditingController();
  bool _visible = false, _validating = false;
  bool? _valid;

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
    final p = await PrefsService.getPat();
    if (p != null && mounted) { _patCtrl.text = p; setState(() {}); }
  }

  Future<void> _validate() async {
    final p = _patCtrl.text.trim();
    if (p.isEmpty) return;
    setState(() { _validating = true; _valid = null; });
    widget.github.setPat(p);
    await PrefsService.savePat(p);
    final ok = await widget.github.validatePat();
    if (mounted) setState(() { _validating = false; _valid = ok; });
  }

  Future<void> _clear() async {
    _patCtrl.clear();
    widget.github.setPat('');
    await PrefsService.clearPat();
    if (mounted) setState(() => _valid = null);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: SafeArea(
      bottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
          child: Text('Paramètres', style: GoogleFonts.inter(color: kText, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Token section
              const AppSectionHeader('GitHub Token (PAT)'),
              Text(
                'Requis pour lire et écrire les prompts dans ton dépôt GitHub.',
                style: GoogleFonts.inter(color: kMuted2, fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 12),
              _TokenCard(
                ctrl: _patCtrl,
                visible: _visible,
                valid: _valid,
                validating: _validating,
                onToggleVisible: () => setState(() => _visible = !_visible),
                onValidate: _validating ? null : _validate,
                onClear: _patCtrl.text.isNotEmpty ? _clear : null,
              ),

              // Dépôt section
              const AppSectionHeader('Dépôt'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _InfoRow('Owner', 'ferelking242', isFirst: true),
                  const AppDivider(),
                  _InfoRow('Repo', 'agentbase'),
                  const AppDivider(),
                  _InfoRow('Site', 'ferelking242.github.io/agentbase', isLast: true),
                ]),
              ),

              // App section
              const AppSectionHeader('Application'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _InfoRow('Version', '3.0.0', isFirst: true, isLast: true),
                ]),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ]),
    ),
  );
}

class _TokenCard extends StatelessWidget {
  final TextEditingController ctrl;
  final bool visible, validating;
  final bool? valid;
  final VoidCallback onToggleVisible;
  final VoidCallback? onValidate;
  final VoidCallback? onClear;

  const _TokenCard({
    required this.ctrl,
    required this.visible,
    required this.validating,
    required this.valid,
    required this.onToggleVisible,
    required this.onValidate,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = kBorder;
    if (valid == true) borderColor = kGreen;
    if (valid == false) borderColor = kRed;

    return AppCard(
      padding: const EdgeInsets.all(14),
      color: kCard,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: ctrl,
          obscureText: !visible,
          style: GoogleFonts.robotoMono(color: kText, fontSize: 13),
          cursorColor: kAccent,
          cursorWidth: 1.5,
          decoration: InputDecoration(
            hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
            hintStyle: GoogleFonts.robotoMono(color: kMuted2, fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor, width: 0.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor, width: 0.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kAccent, width: 1.5)),
            filled: true, fillColor: kBg,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: GestureDetector(
              onTap: onToggleVisible,
              child: Icon(
                visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 17, color: kMuted2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          if (valid != null) Row(children: [
            Icon(valid! ? Icons.check_circle_outline : Icons.error_outline, size: 14, color: valid! ? kGreen : kRed),
            const SizedBox(width: 5),
            Text(valid! ? 'Token valide' : 'Token invalide',
              style: GoogleFonts.inter(color: valid! ? kGreen : kRed, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
          const Spacer(),
          if (onClear != null) ...[
            GestureDetector(
              onTap: onClear,
              child: Text('Effacer', style: GoogleFonts.inter(color: kMuted, fontSize: 12.5)),
            ),
            const SizedBox(width: 10),
          ],
          AppButton(
            label: 'Valider',
            loading: validating,
            onTap: onValidate,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ]),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;

  const _InfoRow(this.label, this.value, {this.isFirst = false, this.isLast = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(14, isFirst ? 12 : 10, 14, isLast ? 12 : 10),
    child: Row(children: [
      Text(label, style: GoogleFonts.inter(color: kMuted, fontSize: 13)),
      const Spacer(),
      Text(value, style: GoogleFonts.robotoMono(color: kText2, fontSize: 12.5)),
    ]),
  );
}
