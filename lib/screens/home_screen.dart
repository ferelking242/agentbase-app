import 'package:flutter/material.dart';
  import '../models/room.dart';
  import '../services/github_service.dart';
  import '../theme.dart';
  import 'room_detail_screen.dart';

  class HomeScreen extends StatefulWidget {
    final GitHubService github;
    final ValueChanged<int> onSection;
    const HomeScreen({super.key, required this.github, required this.onSection});
    @override State<HomeScreen> createState() => _HomeScreenState();
  }
  class _HomeScreenState extends State<HomeScreen> {
    List<Room> _rooms = []; bool _loading = true;
    @override void initState() { super.initState(); _load(); }
    Future<void> _load() async {
      await widget.github.init(); setState(() => _loading = true);
      final r = await widget.github.fetchRooms();
      if (mounted) setState(() { _rooms = r; _loading = false; });
    }
    @override
    Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
      const SizedBox(height: 4),
      const Text('Bonjour', style: TextStyle(color: kMuted2, fontSize: 13)),
      const SizedBox(height: 2),
      const Text('Tableau de bord', style: TextStyle(color: kText, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
      const SizedBox(height: 20),
      // Section cards
      _SectionCard(icon: Icons.lightbulb_outlined, color: kYellow, title: "Problemes & Solutions",
        desc: "Consulter et ajouter des problemes resolus",
        onTap: () => widget.onSection(1)),
      const SizedBox(height: 10),
      _SectionCard(icon: Icons.storage_outlined, color: kBlue, title: 'Databases',
        desc: "Bases de donnees et sources de donnees",
        onTap: () {}),
      const SizedBox(height: 10),
      _SectionCard(icon: Icons.workspaces_outlined, color: kAccent, title: 'Rooms',
        desc: "Espaces de travail agents",
        badge: _loading ? null : '${_rooms.length}',
        onTap: () => widget.onSection(2)),
      const SizedBox(height: 24),
      // Recent rooms
      if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: kAccent))),
      if (!_loading && _rooms.isNotEmpty) ...[
        const Text('ROOMS RECENTES', style: TextStyle(color: kMuted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        ..._rooms.take(4).map((r) => _RoomRow(room: r, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoomDetailScreen(room: r, github: widget.github))))),
      ],
    ]);
  }

  class _SectionCard extends StatelessWidget {
    final IconData icon; final Color color; final String title, desc; final String? badge; final VoidCallback onTap;
    const _SectionCard({required this.icon, required this.color, required this.title, required this.desc, this.badge, required this.onTap});
    @override
    Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600)),
              if (badge != null) ...[const SizedBox(width: 8), Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(badge!, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)))],
            ]),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(color: kMuted2, fontSize: 12)),
          ])),
          Icon(Icons.arrow_forward_ios, size: 13, color: kMuted),
        ]),
      ),
    );
  }

  class _RoomRow extends StatelessWidget {
    final Room room; final VoidCallback onTap;
    const _RoomRow({required this.room, required this.onTap});
    @override
    Widget build(BuildContext context) {
      final accent = room.accentColor;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
          child: Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
              child: Icon(room.iconData, size: 16, color: accent)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(room.name, style: const TextStyle(color: kText, fontSize: 13.5, fontWeight: FontWeight.w600)),
              if (room.description.isNotEmpty) Text(room.description, style: const TextStyle(color: kMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Icon(Icons.chevron_right, size: 16, color: kMuted),
          ]),
        ),
      );
    }
  }