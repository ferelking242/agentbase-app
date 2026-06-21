import 'package:flutter/material.dart';
import '../models/room.dart';
import '../models/prompt.dart';
import '../services/github_service.dart';
import '../theme.dart';
import '../widgets/prompt_tile.dart';
import 'prompt_composer_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  final Room room;
  final GitHubService github;
  const RoomDetailScreen({super.key, required this.room, required this.github});
  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<AgentPrompt> _prompts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadPrompts();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Color get _accent {
    try {
      final h = widget.room.color.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return kAccent;
    }
  }

  Future<void> _loadPrompts() async {
    setState(() => _loading = true);
    try {
      final prompts = await widget.github.fetchRoomPrompts(widget.room.id);
      if (mounted) setState(() { _prompts = prompts; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Scaffold(
      backgroundColor: kBg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
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
            title: Row(
              children: [
                Text(widget.room.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(widget.room.name),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.room.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Text(widget.room.description,
                        style: const TextStyle(color: kMuted2, fontSize: 12.5)),
                    ),
                  TabBar(
                    controller: _tabs,
                    labelColor: kText,
                    unselectedLabelColor: kMuted2,
                    indicatorColor: accent,
                    indicatorWeight: 2,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_outlined, size: 14),
                            const SizedBox(width: 6),
                            const Text('Prompts'),
                            if (_prompts.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: kSurface2,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${_prompts.length}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, size: 14),
                            SizedBox(width: 6),
                            Text('Info'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(height: 1, color: kBorder),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _buildPromptsTab(),
            _buildInfoTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<AgentPrompt>(context,
            MaterialPageRoute(builder: (_) => PromptComposerScreen(
              room: widget.room,
              github: widget.github,
              nextNumber: _prompts.length + 1,
            )),
          );
          if (result != null) {
            setState(() => _prompts.insert(0, result));
          }
        },
        backgroundColor: accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Nouveau Prompt', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
    );
  }

  Widget _buildPromptsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }
    if (_prompts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_outlined, size: 28, color: kAccent2),
              ),
              const SizedBox(height: 16),
              const Text('Aucun prompt', style: TextStyle(
                color: kText, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Appuyez sur "Nouveau Prompt" pour composer votre premier prompt agent.',
                style: TextStyle(color: kMuted2, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: kAccent,
      backgroundColor: kSurface,
      onRefresh: _loadPrompts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...List.generate(_prompts.length, (i) => PromptTile(prompt: _prompts[i])),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    final accent = _accent;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoSection('Room ID', widget.room.id, Icons.tag),
          _infoSection('Créée le', widget.room.created, Icons.calendar_today_outlined),
          _infoSection('Fichiers', '${widget.room.transcriptCount}', Icons.description_outlined),
          _infoSection('Couleur', widget.room.color, Icons.palette_outlined),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chemin GitHub', style: TextStyle(
                  color: kMuted, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.08)),
                const SizedBox(height: 6),
                Text(
                  'rooms/${widget.room.id}/',
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ferelking242/agentbase',
                  style: TextStyle(color: kMuted2, fontSize: 11.5, fontFamily: 'Courier'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: kMuted2),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: kMuted2, fontSize: 12.5)),
            const Spacer(),
            Text(value, style: const TextStyle(
              color: kText, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
