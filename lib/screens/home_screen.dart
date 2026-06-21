import 'package:flutter/material.dart';
import '../services/github_service.dart';
import '../services/prefs_service.dart';
import '../theme.dart';
import 'rooms_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _github = GitHubService();
  bool _patOk = false;
  int _roomCount = 5;
  final _patController = TextEditingController();
  bool _patVisible = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final pat = await PrefsService.getPat();
    if (pat != null && pat.isNotEmpty) {
      _github.setPat(pat);
      _patController.text = pat;
      final ok = await _github.validatePat();
      if (mounted) setState(() => _patOk = ok);
    }
  }

  Future<void> _savePat() async {
    final pat = _patController.text.trim();
    if (pat.isEmpty) return;
    _github.setPat(pat);
    await PrefsService.savePat(pat);
    final ok = await _github.validatePat();
    if (mounted) {
      setState(() => _patOk = ok);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '✅ PAT valide — connexion établie' : '❌ PAT invalide'),
          backgroundColor: ok ? kGreen.withOpacity(0.9) : kRed.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildPatBar()),
            SliverToBoxAdapter(child: _buildStats()),
            SliverToBoxAdapter(child: _buildQuickActions(context)),
            SliverToBoxAdapter(child: _buildInfo()),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kAccent, kPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kAccent.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('AB', style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  )),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AgentBase', style: TextStyle(
                    color: kText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  )),
                  Text('v2.0', style: TextStyle(
                    color: kMuted,
                    fontSize: 11,
                    fontFamily: 'Courier',
                  )),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SettingsScreen(github: _github))),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Icon(Icons.settings_outlined, size: 17, color: kMuted2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kAccent.withOpacity(0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: kAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Mémoire collective des agents IA',
                  style: TextStyle(color: kAccent2, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Agent\nWorkspace',
            style: TextStyle(
              color: kText,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Composez des prompts, gérez vos rooms, et pilotez vos agents IA directement depuis votre mobile.',
            style: TextStyle(color: kMuted2, fontSize: 13.5, height: 1.65),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildPatBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _patOk ? kGreen.withOpacity(0.3) : kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _patOk ? kGreen : kMuted,
                  shape: BoxShape.circle,
                  boxShadow: _patOk ? [BoxShadow(color: kGreen.withOpacity(0.5), blurRadius: 5)] : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _patOk ? 'GitHub connecté' : 'GitHub non connecté',
                style: TextStyle(
                  color: _patOk ? kGreen : kMuted2,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_patOk)
                const Icon(Icons.check_circle_outline, size: 16, color: kGreen),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _patController,
                  obscureText: !_patVisible,
                  style: const TextStyle(
                    color: kText,
                    fontSize: 12,
                    fontFamily: 'Courier',
                  ),
                  decoration: InputDecoration(
                    hintText: 'ghp_xxxxxxxxxxxx',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _savePat,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: kAccent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text('Valider',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vue d\'ensemble', style: TextStyle(
            color: kMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          )),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _statCard('$_roomCount', 'Rooms', kAccent, Icons.meeting_room_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('∞', 'Prompts', kGreen, Icons.auto_awesome_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('GitHub', 'Stockage', kPurple, Icons.cloud_outlined)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          )),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Actions rapides', style: TextStyle(
            color: kMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          )),
          const SizedBox(height: 10),
          _actionButton(
            context,
            icon: Icons.meeting_room_outlined,
            label: 'Voir les Rooms',
            sub: 'Accéder à vos espaces de travail',
            color: kAccent,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => RoomsScreen(github: _github))),
          ),
          const SizedBox(height: 10),
          _actionButton(
            context,
            icon: Icons.auto_awesome_outlined,
            label: 'Nouveau Prompt',
            sub: 'Composez un prompt pour vos agents',
            color: kGreen,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => RoomsScreen(github: _github))),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(
                    color: kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  )),
                  Text(sub, style: const TextStyle(color: kMuted2, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 13, color: kMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: kAccent2),
                const SizedBox(width: 7),
                const Text('Comment ça marche', style: TextStyle(
                  color: kText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
              ],
            ),
            const SizedBox(height: 12),
            _infoStep('1', 'Ouvrez une Room', 'Chaque room correspond à un projet ou espace agent'),
            _infoStep('2', 'Composez un Prompt', 'Ajoutez texte, images ou audio'),
            _infoStep('3', 'Publiez', 'Le fichier est poussé sur GitHub avec un numéro unique'),
            _infoStep('4', 'L\'agent lit & exécute', 'L\'agent récupère le prompt via l\'API GitHub'),
          ],
        ),
      ),
    );
  }

  Widget _infoStep(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(num, style: const TextStyle(
              color: kAccent2,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  color: kText2,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                )),
                Text(desc, style: const TextStyle(color: kMuted, fontSize: 11.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
