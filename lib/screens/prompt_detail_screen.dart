import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/saved_prompt.dart';
import '../services/github_service.dart';
import '../theme.dart';
import '../widgets/app_components.dart';

class PromptDetailResult {
  final bool deleted;
  final String? newName;
  const PromptDetailResult({this.deleted = false, this.newName});
}

class PromptDetailScreen extends StatefulWidget {
  final SavedPrompt prompt;
  final GitHubService github;

  const PromptDetailScreen({super.key, required this.prompt, required this.github});

  @override
  State<PromptDetailScreen> createState() => _PromptDetailScreenState();
}

class _PromptDetailScreenState extends State<PromptDetailScreen> {
  String? _content;
  bool _loadingContent = true;
  bool _editingName = false;
  late String _name;
  late final TextEditingController _nameCtrl;
  bool _copiedLink = false;
  bool _copiedMd = false;
  bool _loadingMd = false;

  @override
  void initState() {
    super.initState();
    _name = widget.prompt.name;
    _nameCtrl = TextEditingController(text: _name);
    _loadContent();
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _loadContent() async {
    try {
      final c = await widget.github.fetchPromptContent(widget.prompt.id);
      if (mounted) setState(() { _content = c; _loadingContent = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingContent = false);
    }
  }

  Future<void> _copyMd() async {
    if (_loadingMd || _content == null) {
      if (_content == null) { showAppSnack(context, 'Contenu non chargé', isError: true); return; }
      return;
    }
    setState(() => _loadingMd = true);
    await Clipboard.setData(ClipboardData(text: _content!));
    setState(() { _loadingMd = false; _copiedMd = true; });
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copiedMd = false); });
  }

  void _startEditName() => setState(() { _editingName = true; _nameCtrl.text = _name; });

  void _confirmName() {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty || newName == widget.prompt.name) {
      setState(() => _editingName = false);
      return;
    }
    setState(() { _name = newName; _editingName = false; });
    Navigator.pop(context, PromptDetailResult(newName: newName));
  }

  void _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kBorder, width: 0.5)),
        title: Text('Supprimer ce prompt ?', style: GoogleFonts.inter(color: kText, fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text('Cette action ne supprime que la copie locale. Le fichier GitHub reste intact.',
          style: GoogleFonts.inter(color: kMuted2, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: Text('Annuler', style: GoogleFonts.inter(color: kMuted))),
          TextButton(onPressed: () => Navigator.pop(_, true), child: Text('Supprimer', style: GoogleFonts.inter(color: kRed, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, const PromptDetailResult(deleted: true));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prompt;
    final num = p.number > 0 ? '#${p.number}' : null;
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // AppBar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
                  child: const Icon(Icons.arrow_back_ios_new, size: 13, color: kMuted),
                ),
              ),
              const SizedBox(width: 12),
              if (num != null) ...[
                AppBadge(num),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text('Détails du prompt',
                style: GoogleFonts.inter(color: kText, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.3))),
              GestureDetector(
                onTap: _delete,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: kRedSub.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: kRed.withValues(alpha: 0.2), width: 0.5)),
                  child: const Icon(Icons.delete_outline, size: 17, color: kRed),
                ),
              ),
            ]),
          ),

          Expanded(child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Name section
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const AppLabel('Nom du prompt'),
                    const Spacer(),
                    if (!_editingName)
                      GestureDetector(
                        onTap: _startEditName,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.edit_outlined, size: 13, color: kMuted2),
                          const SizedBox(width: 4),
                          Text('Modifier', style: GoogleFonts.inter(color: kMuted2, fontSize: 11.5)),
                        ]),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  if (_editingName) ...[
                    AppInput(
                      controller: _nameCtrl,
                      autofocus: true,
                      hint: 'Nom du prompt',
                      onSubmitted: (_) => _confirmName(),
                    ),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      AppButton(label: 'Annuler', variant: AppButtonVariant.ghost,
                        onTap: () => setState(() => _editingName = false),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7)),
                      const SizedBox(width: 8),
                      AppButton(label: 'Confirmer', onTap: _confirmName,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7)),
                    ]),
                  ] else
                    Text(_name, style: GoogleFonts.inter(color: kText, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                ]),
              ),
              const SizedBox(height: 10),

              // Metadata
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  if (num != null) ...[
                    _MetaRow('Numéro', num, icon: Icons.tag),
                    const AppDivider(),
                  ],
                  _MetaRow('ID', p.id, icon: Icons.fingerprint, mono: true),
                  const AppDivider(),
                  _MetaRow('Date', _fmtDate(p.created), icon: Icons.calendar_today_outlined),
                  const AppDivider(),
                  _MetaRow('Heure', _fmtTime(p.created), icon: Icons.access_time_outlined),
                ]),
              ),
              const SizedBox(height: 10),

              // Link
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const AppLabel('Lien GitHub'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
                    child: Text(p.link, style: GoogleFonts.robotoMono(color: kBlue, fontSize: 11.5), maxLines: 3),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: AppButton(
                      label: _copiedLink ? 'Copié !' : 'Copier le lien',
                      icon: _copiedLink ? Icons.check : Icons.link,
                      variant: _copiedLink ? AppButtonVariant.secondary : AppButtonVariant.outline,
                      fullWidth: true,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: p.link));
                        setState(() => _copiedLink = true);
                        Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copiedLink = false); });
                      },
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: AppButton(
                      label: _copiedMd ? 'Copié !' : 'Copier MD',
                      icon: _copiedMd ? Icons.check : Icons.content_copy,
                      variant: _copiedMd ? AppButtonVariant.secondary : AppButtonVariant.ghost,
                      loading: _loadingMd || _loadingContent,
                      fullWidth: true,
                      onTap: (_loadingMd || _loadingContent) ? null : _copyMd,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    )),
                  ]),
                ]),
              ),
              const SizedBox(height: 10),

              // Content
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const AppLabel('Contenu Markdown'),
                    const Spacer(),
                    if (_loadingContent)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: kAccent)),
                  ]),
                  const SizedBox(height: 12),
                  if (_loadingContent)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: AppLoadingIndicator()))
                  else if (_content == null)
                    const AppEmptyState(icon: Icons.cloud_off, title: 'Non disponible', subtitle: 'Vérifie ta connexion ou ton token')
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder, width: 0.5)),
                      child: SelectableText(
                        _content!,
                        style: GoogleFonts.robotoMono(color: kText2, fontSize: 12, height: 1.7),
                      ),
                    ),
                ]),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          )),
        ]),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_month(d.month)} ${d.year}';

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  String _month(int m) => const ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'][m - 1];
}

class _MetaRow extends StatelessWidget {
  final String label, value;
  final IconData? icon;
  final bool mono;
  const _MetaRow(this.label, this.value, {this.icon, this.mono = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 14, color: kMuted2),
        const SizedBox(width: 8),
      ],
      Text(label, style: GoogleFonts.inter(color: kMuted, fontSize: 13)),
      const Spacer(),
      Text(value, style: mono
          ? GoogleFonts.robotoMono(color: kText2, fontSize: 12)
          : GoogleFonts.inter(color: kText2, fontSize: 13, fontWeight: FontWeight.w500),
        textAlign: TextAlign.end),
    ]),
  );
}
